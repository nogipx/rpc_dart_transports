import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '../models/chat_models.dart';

/// Сервис для управления чатом с поддержкой различных транспортов
class ChatService extends ChangeNotifier {
  static const String _defaultRoom = 'general';

  RpcRouterClient? _routerClient;
  RpcCallerEndpoint? _endpoint;
  String? _clientId;
  String? _currentUsername;
  String? _serverUrl;

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
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;
  String? _connectionError;

  // Таймер для переподключения
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Таймер для периодического обновления
  Timer? _updateTimer;

  // Выбранный транспорт
  TransportType _transportType = TransportType.http2;

  // Геттеры для состояния
  List<ChatMessage> get currentMessages => _messagesByRoom[_currentRoom] ?? [];
  List<ChatMessage> get privateMessages => _privateMessages;
  Set<UserProfile> get onlineUsers => _onlineUsers;
  Set<ChatRoom> get availableRooms => _availableRooms;
  String get currentRoom => _currentRoom;
  String? get currentUsername => _currentUsername;
  String? get clientId => _clientId;
  bool get isConnected =>
      _routerClient != null &&
      _clientId != null &&
      _connectionState == ChatConnectionState.connected;
  Set<String> get currentlyTyping => _currentlyTyping;
  ChatConnectionState get connectionState => _connectionState;
  String? get connectionError => _connectionError;
  TransportType get transportType => _transportType;

  /// Подключается к роутеру с выбранным транспортом
  Future<void> connect({
    required String serverUrl,
    required String username,
    TransportType transportType = TransportType.http2,
    RpcLogger? logger,
  }) async {
    try {
      _currentUsername = username;
      _serverUrl = serverUrl;
      _transportType = transportType;
      _connectionError = null;

      // Устанавливаем состояние подключения
      _connectionState = ChatConnectionState.connecting;
      notifyListeners();

      // Создаем транспорт в зависимости от типа
      IRpcTransport transport;
      switch (transportType) {
        case TransportType.websocket:
          transport = RpcWebSocketCallerTransport.connect(Uri.parse(serverUrl));
          break;
        case TransportType.http2:
          final uri = Uri.parse(serverUrl);
          transport = await RpcHttp2CallerTransport.connect(host: uri.host, port: uri.port);
          break;
        case TransportType.inMemory:
          throw UnsupportedError(
            'In-Memory транспорт не поддерживается для клиентского подключения',
          );
      }

      // Создаем endpoint с выбранным транспортом
      _endpoint = RpcCallerEndpoint(
        transport: transport,
        debugLabel: 'ChatClient_${transportType.name}',
      );

      // Создаем роутер клиент (теперь транспорт-агностичный!)
      _routerClient = RpcRouterClient(
        callerEndpoint: _endpoint!,
        logger: logger?.child('ChatClient'),
      );

      // Регистрируемся в роутере
      _clientId = await _routerClient!.register(
        clientName: username,
        groups: [_currentRoom],
        metadata: {
          'platform': 'flutter',
          'transport': transportType.name,
          'version': '2.0.0',
          'joinedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      // Инициализируем P2P соединение
      await _routerClient!.initializeP2P(
        onP2PMessage: _handleP2PMessage,
        filterRouterHeartbeats: true,
        enableAutoHeartbeat: true,
      );

      // Подписываемся на события роутера
      await _routerClient!.subscribeToEvents();
      _routerClient!.events.listen(_handleRouterEvent);

      // Устанавливаем состояние как подключенное
      _connectionState = ChatConnectionState.connected;
      _reconnectAttempts = 0;

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
        ChatMessage.system(
          message:
              '✅ Добро пожаловать в чат, $username! Транспорт: ${transportType.name.toUpperCase()}',
          room: _currentRoom,
        ),
      );

      // Запускаем периодическое обновление
      _startPeriodicUpdates();

      // Обновляем список пользователей
      await _updateOnlineUsers();

      notifyListeners();
    } catch (e) {
      _connectionState = ChatConnectionState.disconnected;
      _connectionError = e.toString();
      notifyListeners();

      // Пробуем переподключиться автоматически
      _scheduleReconnect();

      throw Exception('Ошибка подключения: $e');
    }
  }

  /// Автоматическое переподключение
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _connectionError = 'Превышено максимальное количество попыток переподключения';
      notifyListeners();
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: min(30, 2 * _reconnectAttempts)); // Exponential backoff

    _connectionState = ChatConnectionState.reconnecting;
    notifyListeners();

    _reconnectTimer = Timer(delay, () async {
      if (_currentUsername != null && _serverUrl != null) {
        try {
          await connect(
            serverUrl: _serverUrl!,
            username: _currentUsername!,
            transportType: _transportType,
          );
        } catch (e) {
          // Ошибка переподключения, пробуем снова
          _scheduleReconnect();
        }
      }
    });
  }

  /// Принудительное переподключение
  Future<void> reconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    if (_currentUsername != null && _serverUrl != null) {
      await disconnect();
      await connect(
        serverUrl: _serverUrl!,
        username: _currentUsername!,
        transportType: _transportType,
      );
    }
  }

  /// Смена транспорта на лету
  Future<void> switchTransport(TransportType newTransport) async {
    if (!isConnected || newTransport == _transportType) return;

    final username = _currentUsername!;
    final serverUrl = _serverUrl!;

    await disconnect();
    await connect(serverUrl: serverUrl, username: username, transportType: newTransport);

    _addMessage(
      ChatMessage.system(
        message: '🔄 Переключено на транспорт: ${newTransport.name.toUpperCase()}',
        room: _currentRoom,
      ),
    );
  }

  /// Отключается от чата
  Future<void> disconnect() async {
    // Останавливаем переподключение
    _reconnectTimer?.cancel();

    // Останавливаем периодические обновления
    _stopPeriodicUpdates();

    // Очищаем таймеры печатания
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _currentlyTyping.clear();

    // Закрываем соединения
    await _routerClient?.dispose();
    await _endpoint?.close();

    _routerClient = null;
    _endpoint = null;
    _clientId = null;

    // Очищаем состояние
    _messagesByRoom.clear();
    _privateMessages.clear();
    _onlineUsers.clear();
    _availableRooms.clear();
    _currentRoom = _defaultRoom;
    _connectionState = ChatConnectionState.disconnected;
    _connectionError = null;

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
      // Автоматически убираем через 5 секунд если нет stop
      Timer(const Duration(seconds: 5), () {
        _currentlyTyping.remove(username);
        notifyListeners();
      });
    } else if (action == 'stop') {
      _currentlyTyping.remove(username);
    }

    notifyListeners();
  }

  /// Обрабатывает реакции на сообщения
  void _handleReaction(Map<String, dynamic> data) {
    final messageId = data['messageId'] as String?;
    final emoji = data['emoji'] as String?;
    final action = data['action'] as String?;
    final username = data['username'] as String?;

    if (messageId == null || emoji == null || username == null) return;

    // Находим сообщение и добавляем/убираем реакцию
    for (final messages in _messagesByRoom.values) {
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        final message = messages[messageIndex];
        final reactions = Map<String, int>.from(message.reactions);

        if (action == 'add') {
          reactions[emoji] = (reactions[emoji] ?? 0) + 1;
        } else if (action == 'remove') {
          final count = (reactions[emoji] ?? 0) - 1;
          if (count <= 0) {
            reactions.remove(emoji);
          } else {
            reactions[emoji] = count;
          }
        }

        messages[messageIndex] = message.copyWith(reactions: reactions);
        notifyListeners();
        break;
      }
    }
  }

  /// Обновляет список онлайн пользователей
  Future<void> _updateOnlineUsers() async {
    if (!isConnected) return;

    try {
      final clients = await _routerClient!.getOnlineClients();
      _onlineUsers.clear();

      for (final client in clients) {
        _onlineUsers.add(
          UserProfile(
            userId: client.clientId,
            username: client.clientName ?? 'Неизвестный',
            status: UserStatus.online,
            lastSeen: client.lastActivity,
            metadata: client.metadata,
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      // При ошибке попробуем переподключиться через некоторое время
      if (_connectionState == ChatConnectionState.connected) {
        Timer(const Duration(seconds: 5), () {
          if (isConnected) {
            _updateOnlineUsers();
          }
        });
      }
    }
  }

  /// Добавляет сообщение в локальную историю
  void _addMessage(ChatMessage message) {
    final roomMessages = _messagesByRoom[message.room] ?? [];
    roomMessages.add(message);
    _messagesByRoom[message.room] = roomMessages;

    // Ограничиваем количество сообщений в комнате (например, последние 1000)
    if (roomMessages.length > 1000) {
      _messagesByRoom[message.room] = roomMessages.sublist(roomMessages.length - 1000);
    }

    notifyListeners();
  }

  /// Генерирует ID комнаты на основе имени
  String _generateRoomId(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
