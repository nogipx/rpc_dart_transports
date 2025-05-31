import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '../models/chat_models.dart';

/// Сервис для управления чатом
class ChatService extends ChangeNotifier {
  static const String _defaultRoom = 'general';

  RouterClientWithReconnect? _routerClient;
  String? _clientId;
  String? _currentUsername;

  // Состояние чата
  final Map<String, List<ChatMessage>> _messagesByRoom = {_defaultRoom: []};
  final List<ChatMessage> _privateMessages = [];
  final Set<UserProfile> _onlineUsers = {};
  final Set<ChatRoom> _availableRooms = {};
  String _currentRoom = _defaultRoom;

  // Статус печатания
  final Map<String, Timer> _typingTimers = {};
  final Set<String> _currentlyTyping = {};

  // Состояние подключения
  ReconnectState _connectionState = ReconnectState.disconnected;

  // Таймер для периодического обновления
  Timer? _updateTimer;

  // Геттеры для состояния
  List<ChatMessage> get currentMessages => _messagesByRoom[_currentRoom] ?? [];
  List<ChatMessage> get privateMessages => _privateMessages;
  Set<UserProfile> get onlineUsers => _onlineUsers;
  Set<ChatRoom> get availableRooms => _availableRooms;
  String get currentRoom => _currentRoom;
  String? get currentUsername => _currentUsername;
  String? get clientId => _clientId;
  bool get isConnected =>
      _routerClient != null && _clientId != null && _connectionState == ReconnectState.connected;
  Set<String> get currentlyTyping => _currentlyTyping;
  ReconnectState get connectionState => _connectionState;

  /// Подключается к роутеру
  Future<void> connect({
    required String serverUrl,
    required String username,
    RpcLogger? logger,
  }) async {
    try {
      _currentUsername = username;

      // Устанавливаем состояние подключения
      _connectionState = ReconnectState.reconnecting;
      notifyListeners();

      // Создаем клиент с переподключением
      _routerClient = RouterClientWithReconnect(
        serverUri: Uri.parse(serverUrl),
        reconnectConfig: ReconnectConfig(
          strategy: ReconnectStrategy.exponentialBackoff,
          enableJitter: true,
        ),
        logger: logger,
      );

      // Подключаемся
      await _routerClient!.connect();

      // Регистрируемся
      _clientId = await _routerClient!.register(
        clientName: username,
        groups: [_currentRoom],
        metadata: {
          'platform': 'flutter',
          'version': '1.0.0',
          'joinedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      // Инициализируем P2P
      await _routerClient!.initializeP2P(
        onP2PMessage: _handleP2PMessage,
        filterRouterHeartbeats: true,
      );

      // Подписываемся на события
      await _routerClient!.subscribeToEvents();
      _routerClient!.events.listen(_handleRouterEvent);

      // Слушаем состояние подключения
      _routerClient!.connectionState.listen((state) {
        _connectionState = state;

        // Запускаем периодическое обновление при подключении
        if (state == ReconnectState.connected) {
          _startPeriodicUpdates();
        } else {
          _stopPeriodicUpdates();
        }

        notifyListeners();
      });

      // Устанавливаем начальное состояние как подключенное
      _connectionState = ReconnectState.connected;

      // Добавляем дефолтную комнату
      _availableRooms.add(
        ChatRoom(
          id: _defaultRoom,
          name: 'Общая',
          description: 'Основная комната для общения',
          createdAt: DateTime.now(),
        ),
      );

      // Отправляем приветственное сообщение
      _addMessage(
        ChatMessage.system(message: '✅ Добро пожаловать в чат, $username!', room: _currentRoom),
      );

      // Обновляем список пользователей
      await _updateOnlineUsers();

      notifyListeners();
    } catch (e) {
      // При ошибке подключения устанавливаем состояние disconnected
      _connectionState = ReconnectState.disconnected;
      notifyListeners();
      throw Exception('Ошибка подключения: $e');
    }
  }

  /// Отключается от чата
  Future<void> disconnect() async {
    // Останавливаем периодические обновления
    _stopPeriodicUpdates();

    // Очищаем таймеры печатания
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _currentlyTyping.clear();

    // Закрываем соединение
    await _routerClient?.dispose();
    _routerClient = null;
    _clientId = null;

    // Очищаем состояние
    _messagesByRoom.clear();
    _privateMessages.clear();
    _onlineUsers.clear();
    _availableRooms.clear();
    _currentRoom = _defaultRoom;
    _connectionState = ReconnectState.disconnected;

    notifyListeners();
  }

  /// Отправляет сообщение в текущую комнату
  Future<void> sendMessage(String text) async {
    if (!isConnected || text.trim().isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: _currentUsername!,
      message: text.trim(),
      room: _currentRoom,
      timestamp: DateTime.now(),
    );

    // Отправляем через роутер
    await _routerClient!.sendMulticast(_currentRoom, {'chatMessage': message.toJson()});

    // Добавляем в локальную историю
    _addMessage(message);

    // Останавливаем индикатор печатания
    await _stopTyping();
  }

  /// Отправляет приватное сообщение
  Future<void> sendPrivateMessage(String targetUserId, String text) async {
    if (!isConnected || text.trim().isEmpty) return;

    final message = ChatMessage.private(
      username: _currentUsername!,
      message: text.trim(),
      targetUserId: targetUserId,
    );

    // Отправляем через роутер
    await _routerClient!.sendUnicast(targetUserId, {'privateMessage': message.toJson()});

    // Добавляем в локальную историю приватных сообщений
    _privateMessages.add(message);
    notifyListeners();
  }

  /// Присоединяется к комнате
  Future<void> joinRoom(String roomId) async {
    if (!isConnected || roomId == _currentRoom) return;

    final oldRoom = _currentRoom;
    _currentRoom = roomId;

    // Обновляем группы в роутере
    await _routerClient!.updateMetadata({'currentRoom': roomId, 'previousRoom': oldRoom});

    // Создаем список сообщений для новой комнаты если его нет
    if (!_messagesByRoom.containsKey(roomId)) {
      _messagesByRoom[roomId] = [];
    }

    // Приветственное сообщение
    _addMessage(
      ChatMessage.system(message: '🚪 Добро пожаловать в комнату "$roomId"', room: roomId),
    );

    // Очищаем индикаторы печатания при смене комнаты
    _currentlyTyping.clear();

    // Обновляем список участников для новой комнаты
    _updateOnlineUsers();

    notifyListeners();
  }

  /// Создает новую комнату
  Future<void> createRoom(String name, String? description) async {
    if (!isConnected) return;

    final room = ChatRoom(
      id: _generateRoomId(name),
      name: name,
      description: description,
      createdAt: DateTime.now(),
      createdBy: _clientId!,
      members: {_clientId!},
    );

    _availableRooms.add(room);

    // Уведомляем других пользователей
    await _routerClient!.sendBroadcast({'roomCreated': room.toJson()});

    // Автоматически присоединяемся к новой комнате
    await joinRoom(room.id);

    notifyListeners();
  }

  /// Начинает печатание
  Future<void> startTyping() async {
    if (!isConnected) return;

    // Отправляем уведомление о печатании
    await _routerClient!.sendMulticast(_currentRoom, {
      'typing': {'username': _currentUsername!, 'room': _currentRoom, 'action': 'start'},
    });

    // Автоматически останавливаем через 3 секунды
    _typingTimers[_currentUsername!]?.cancel();
    _typingTimers[_currentUsername!] = Timer(Duration(seconds: 3), () {
      _stopTyping();
    });
  }

  /// Останавливает печатание
  Future<void> _stopTyping() async {
    if (!isConnected) return;

    _typingTimers[_currentUsername!]?.cancel();
    _typingTimers.remove(_currentUsername!);

    await _routerClient!.sendMulticast(_currentRoom, {
      'typing': {'username': _currentUsername!, 'room': _currentRoom, 'action': 'stop'},
    });
  }

  /// Добавляет реакцию к сообщению
  Future<void> addReaction(String messageId, String emoji) async {
    if (!isConnected) return;

    await _routerClient!.sendMulticast(_currentRoom, {
      'reaction': {
        'messageId': messageId,
        'emoji': emoji,
        'action': 'add',
        'username': _currentUsername!,
      },
    });
  }

  /// Принудительно переподключается
  Future<void> reconnect() async {
    if (_routerClient != null) {
      await _routerClient!.reconnect();
    }
  }

  /// Обрабатывает P2P сообщения
  void _handleP2PMessage(RouterMessage message) {
    final payload = message.payload;
    if (payload == null) return;

    // Обычные сообщения чата
    if (payload.containsKey('chatMessage')) {
      final chatMessage = ChatMessage.fromJson(payload['chatMessage']);
      _addMessage(chatMessage);
    }
    // Приватные сообщения
    else if (payload.containsKey('privateMessage')) {
      final privateMessage = ChatMessage.fromJson(payload['privateMessage']);
      _privateMessages.add(privateMessage);
      notifyListeners();
    }
    // Уведомления о печатании
    else if (payload.containsKey('typing')) {
      _handleTypingNotification(payload['typing']);
    }
    // Реакции на сообщения
    else if (payload.containsKey('reaction')) {
      _handleReaction(payload['reaction']);
    }
    // Создание комнат
    else if (payload.containsKey('roomCreated')) {
      final room = ChatRoom.fromJson(payload['roomCreated']);
      _availableRooms.add(room);
      notifyListeners();
    }
  }

  /// Обрабатывает события роутера
  void _handleRouterEvent(RouterEvent event) {
    switch (event.type) {
      case RouterEventType.clientConnected:
        final username = event.data['clientName'] ?? 'Неизвестный';
        _addMessage(
          ChatMessage.system(message: '👋 $username присоединился к чату', room: _currentRoom),
        );
        _updateOnlineUsers();
        break;

      case RouterEventType.clientDisconnected:
        final clientId = event.data['clientId'] ?? 'Неизвестный';
        _onlineUsers.removeWhere((user) => user.userId == clientId);
        _addMessage(ChatMessage.system(message: '👋 Пользователь покинул чат', room: _currentRoom));
        notifyListeners();
        break;

      case RouterEventType.topologyChanged:
        // При изменении топологии обновляем список пользователей
        _updateOnlineUsers();
        break;

      case RouterEventType.routerStats:
        // Можно добавить обработку статистики роутера если нужно
        break;

      default:
        break;
    }
  }

  /// Запускает периодическое обновление списка пользователей
  void _startPeriodicUpdates() {
    _stopPeriodicUpdates(); // Останавливаем предыдущий таймер если есть

    // Обновляем каждые 30 секунд
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateOnlineUsers();
    });

    // Сразу обновляем после подключения
    _updateOnlineUsers();
  }

  /// Останавливает периодическое обновление
  void _stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Обрабатывает уведомления о печатании
  void _handleTypingNotification(Map<String, dynamic> data) {
    final username = data['username'] as String?;
    final room = data['room'] as String?;
    final action = data['action'] as String?;

    if (username == null || room != _currentRoom || username == _currentUsername) {
      return;
    }

    if (action == 'start') {
      _currentlyTyping.add(username);

      // Автоматически убираем через 5 секунд
      Timer(Duration(seconds: 5), () {
        _currentlyTyping.remove(username);
        notifyListeners();
      });
    } else if (action == 'stop') {
      _currentlyTyping.remove(username);
    }

    notifyListeners();
  }

  /// Обрабатывает реакции
  void _handleReaction(Map<String, dynamic> data) {
    final messageId = data['messageId'] as String?;
    final emoji = data['emoji'] as String?;
    final action = data['action'] as String?;

    if (messageId == null || emoji == null || action == null) return;

    final messages = _messagesByRoom[_currentRoom] ?? [];
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].id == messageId) {
        if (action == 'add') {
          messages[i] = messages[i].addReaction(emoji);
        } else if (action == 'remove') {
          messages[i] = messages[i].removeReaction(emoji);
        }
        notifyListeners();
        break;
      }
    }
  }

  /// Добавляет сообщение в текущую комнату
  void _addMessage(ChatMessage message) {
    final roomMessages = _messagesByRoom[message.room] ?? [];
    roomMessages.add(message);
    _messagesByRoom[message.room] = roomMessages;

    // Сообщение добавлено

    notifyListeners();
  }

  /// Обновляет список онлайн пользователей
  Future<void> _updateOnlineUsers() async {
    if (!isConnected) return;

    try {
      final clients = await _routerClient!.getOnlineClients();
      final previousCount = _onlineUsers.length;

      _onlineUsers.clear();

      for (final client in clients) {
        _onlineUsers.add(
          UserProfile(
            userId: client.clientId,
            username: client.clientName ?? 'Пользователь',
            lastSeen: client.lastActivity,
            rooms: Set.from(client.groups),
            metadata: client.metadata,
          ),
        );
      }

      // Если количество пользователей изменилось, показываем уведомление
      if (_onlineUsers.length != previousCount) {
        debugPrint('👥 Список участников обновлен: ${_onlineUsers.length} пользователей онлайн');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка обновления списка пользователей: $e');

      // При ошибке попробуем переподключиться через некоторое время
      if (_connectionState == ReconnectState.connected) {
        Timer(const Duration(seconds: 5), () {
          if (isConnected) {
            _updateOnlineUsers();
          }
        });
      }
    }
  }

  /// Генерирует ID комнаты
  String _generateRoomId(String name) {
    final clean = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final random = Random().nextInt(1000);
    return '${clean}_$random';
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
