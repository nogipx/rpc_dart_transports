import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '../models/chat_models.dart';

/// Сервис для работы с чатом через роутер
///
/// Использует HTTP/2 транспорт для высокой производительности
class ChatService extends ChangeNotifier {
  // === СОСТОЯНИЕ ПОДКЛЮЧЕНИЯ ===
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;
  String? _connectionError;
  String? _currentUsername;
  String? _currentUserId;

  // === RPC КОМПОНЕНТЫ ===
  RpcRouterClient? _routerClient;
  RpcCallerEndpoint? _callerEndpoint;

  // === ЛОГГЕР ===
  RpcLogger? _logger;

  // === ЧАТОВЫЕ ДАННЫЕ ===
  final List<ChatMessage> _messages = [];
  final List<ChatUser> _users = [];
  final Set<String> _typingUsers = {};

  // === ПЕРЕПОДКЛЮЧЕНИЕ ===
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const List<int> _reconnectDelays = [2, 4, 8, 16, 30]; // Exponential backoff

  // === HEARTBEAT ===
  Timer? _heartbeatTimer;

  // === GETTERS ===
  ChatConnectionState get connectionState => _connectionState;
  String? get connectionError => _connectionError;
  String? get currentUsername => _currentUsername;
  String? get currentUserId => _currentUserId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatUser> get users => List.unmodifiable(_users);
  Set<String> get typingUsers => Set.unmodifiable(_typingUsers);
  bool get isConnected => _connectionState == ChatConnectionState.connected;

  // === ДОПОЛНИТЕЛЬНЫЕ ГЕТТЕРЫ ДЛЯ СОВМЕСТИМОСТИ ===
  List<ChatMessage> get currentMessages => messages;
  List<ChatUser> get onlineUsers => users;
  Set<String> get currentlyTyping =>
      typingUsers.map((userId) {
        final user = users.firstWhere(
          (u) => u.id == userId,
          orElse: () => ChatUser(id: userId, name: 'Unknown'),
        );
        return user.name;
      }).toSet();
  String? get clientId => _currentUserId;
  String get currentRoom => 'general'; // Простая реализация
  List<ChatRoom> get availableRooms => [
    ChatRoom(
      id: 'general',
      name: 'Общий чат',
      description: 'Основная комната для общения',
      createdAt: DateTime.now(),
      members: users.map((u) => u.id).toSet(),
    ),
  ]; // Простая реализация

  // === ПОДКЛЮЧЕНИЕ ===

  /// Подключается к серверу роутера через HTTP/2
  Future<void> connect({
    required String serverUrl,
    required String username,
    RpcLogger? logger,
  }) async {
    if (_connectionState == ChatConnectionState.connecting) {
      _logger?.warning('Подключение уже выполняется');
      return;
    }

    _logger = logger?.child('ChatService');
    _setConnectionState(ChatConnectionState.connecting);

    try {
      _logger?.info('Подключение к серверу: $serverUrl через HTTP/2');

      // Создаем HTTP/2 транспорт
      final uri = Uri.parse(serverUrl);
      final transport = await RpcHttp2CallerTransport.connect(host: uri.host, port: uri.port);

      // Создаем endpoint и клиента
      _callerEndpoint = RpcCallerEndpoint(transport: transport);
      _routerClient = RpcRouterClient(callerEndpoint: _callerEndpoint!, logger: _logger);

      // Регистрируемся в роутере
      _logger?.info('Регистрация пользователя: $username');
      _currentUserId = await _routerClient!.register(
        clientName: username,
        groups: ['chat'],
        metadata: {'type': 'chat_client', 'version': '2.0.0'},
      );

      _currentUsername = username;

      // Инициализируем P2P соединение для реального времени
      await _routerClient!.initializeP2P(
        onP2PMessage: _handleP2PMessage,
        enableAutoHeartbeat: true,
        filterRouterHeartbeats: true,
      );

      // Подписываемся на события роутера
      await _routerClient!.subscribeToEvents();
      _routerClient!.events.listen(_handleRouterEvent);

      // Запускаем heartbeat
      _startHeartbeat();

      // Загружаем список пользователей
      await _refreshUsersList();

      _setConnectionState(ChatConnectionState.connected);
      _reconnectAttempts = 0;

      _logger?.info('✅ Успешно подключены как $_currentUsername (ID: $_currentUserId)');
    } catch (e, stackTrace) {
      _logger?.error('Ошибка подключения: $e', error: e, stackTrace: stackTrace);
      _setConnectionError('Ошибка подключения: $e');

      // Автоматическое переподключение
      _scheduleReconnect(serverUrl, username, logger);
    }
  }

  /// Отключается от сервера
  Future<void> disconnect() async {
    _logger?.info('Отключение от сервера');

    _setConnectionState(ChatConnectionState.disconnected);
    _stopReconnectTimer();
    _stopHeartbeat();

    try {
      // Закрываем роутер клиента
      await _routerClient?.dispose();

      // Очищаем данные
      _clearChatData();
    } catch (e) {
      _logger?.warning('Ошибка при отключении: $e');
    } finally {
      _routerClient = null;
      _callerEndpoint = null;
      _currentUsername = null;
      _currentUserId = null;
      _logger?.info('Отключение завершено');
    }
  }

  // === ОТПРАВКА СООБЩЕНИЙ ===

  /// Отправляет публичное сообщение в чат
  Future<void> sendMessage(String content) async {
    _ensureConnected();
    if (content.trim().isEmpty) return;

    try {
      final message = ChatMessage(
        id: _generateMessageId(),
        content: content.trim(),
        senderId: _currentUserId!,
        senderName: _currentUsername!,
        timestamp: DateTime.now(),
        type: ChatMessageType.public,
      );

      await _routerClient!.sendMulticast('chat', {'type': 'message', 'message': message.toJson()});

      // Добавляем собственное сообщение в локальный список
      _addMessage(message);

      _logger?.debug('Сообщение отправлено: ${content.substring(0, min(50, content.length))}...');
    } catch (e) {
      _logger?.error('Ошибка отправки сообщения: $e');
      rethrow;
    }
  }

  /// Отправляет приватное сообщение пользователю
  Future<void> sendPrivateMessage(String targetUserId, String content) async {
    _ensureConnected();
    if (content.trim().isEmpty) return;

    try {
      final message = ChatMessage(
        id: _generateMessageId(),
        content: content.trim(),
        senderId: _currentUserId!,
        senderName: _currentUsername!,
        timestamp: DateTime.now(),
        type: ChatMessageType.private,
        targetUserId: targetUserId,
      );

      await _routerClient!.sendUnicast(targetUserId, {
        'type': 'private_message',
        'message': message.toJson(),
      });

      // Добавляем сообщение в локальный список для отправителя
      _addMessage(message);

      _logger?.debug('Приватное сообщение отправлено к $targetUserId');
    } catch (e) {
      _logger?.error('Ошибка отправки приватного сообщения: $e');
      rethrow;
    }
  }

  /// Отправляет индикатор печатания
  Future<void> sendTypingIndicator(bool isTyping) async {
    if (!isConnected) return;

    try {
      final typingEvent = TypingEvent(
        userId: _currentUserId!,
        userName: _currentUsername!,
        isTyping: isTyping,
        timestamp: DateTime.now(),
      );

      await _routerClient!.sendMulticast('chat', {
        'type': 'typing',
        'typing': typingEvent.toJson(),
      });

      _logger?.debug('Индикатор печатания отправлен: $isTyping');
    } catch (e) {
      _logger?.warning('Ошибка отправки индикатора печатания: $e');
    }
  }

  /// Добавляет реакцию к сообщению
  Future<void> addReaction(String messageId, String emoji) async {
    _ensureConnected();

    try {
      await _routerClient!.sendMulticast('chat', {
        'type': 'reaction',
        'messageId': messageId,
        'emoji': emoji,
        'userId': _currentUserId!,
        'action': 'add',
      });

      _logger?.debug('Реакция добавлена: $emoji к сообщению $messageId');
    } catch (e) {
      _logger?.error('Ошибка добавления реакции: $e');
      rethrow;
    }
  }

  /// Отправляет индикатор начала печатания
  Future<void> startTyping() async {
    await sendTypingIndicator(true);
  }

  /// Переподключается к серверу
  Future<void> reconnect() async {
    if (_connectionState == ChatConnectionState.connecting) {
      _logger?.warning('Переподключение уже выполняется');
      return;
    }

    _logger?.info('Попытка переподключения...');

    // Сохраняем параметры подключения
    final username = _currentUsername;
    if (username == null) {
      _logger?.error('Нет сохраненного имени пользователя для переподключения');
      return;
    }

    // Отключаемся и подключаемся заново
    await disconnect();

    // Здесь нужно было бы сохранить serverUrl, но для простоты используем дефолтный
    await connect(serverUrl: 'http://localhost:11112', username: username, logger: _logger);
  }

  /// Создает новую комнату (заглушка)
  Future<void> createRoom(String name, String? description) async {
    _logger?.info('Создание комнаты "$name" (пока не реализовано)');
    // Заглушка - в полной реализации здесь был бы RPC вызов
    throw UnimplementedError('Создание комнат пока не реализовано');
  }

  /// Присоединяется к комнате (заглушка)
  Future<void> joinRoom(String roomId) async {
    _logger?.info('Присоединение к комнате "$roomId" (пока не реализовано)');
    // Заглушка - в полной реализации здесь был бы RPC вызов
    throw UnimplementedError('Присоединение к комнатам пока не реализовано');
  }

  // === ОБРАБОТЧИКИ P2P СООБЩЕНИЙ ===

  void _handleP2PMessage(RouterMessage routerMessage) {
    try {
      final payload = routerMessage.payload;
      if (payload == null) return;

      final messageType = payload['type'] as String?;
      _logger?.debug('Получено P2P сообщение: $messageType от ${routerMessage.senderId}');

      switch (messageType) {
        case 'message':
          _handleChatMessage(payload['message']);
          break;
        case 'private_message':
          _handlePrivateMessage(payload['message']);
          break;
        case 'typing':
          _handleTypingEvent(payload['typing']);
          break;
        case 'reaction':
          _handleReactionUpdate(payload);
          break;
        case 'user_joined':
          _handleUserJoined(payload['user']);
          break;
        case 'user_left':
          _handleUserLeft(payload['userId']);
          break;
        default:
          _logger?.debug('Неизвестный тип P2P сообщения: $messageType');
      }
    } catch (e, stackTrace) {
      _logger?.error('Ошибка обработки P2P сообщения: $e', error: e, stackTrace: stackTrace);
    }
  }

  void _handleChatMessage(dynamic messageData) {
    try {
      final message = ChatMessage.fromJson(messageData as Map<String, dynamic>);

      // Игнорируем собственные сообщения - они уже добавлены локально
      if (message.senderId == _currentUserId) {
        _logger?.debug('Игнорируем собственное сообщение: ${message.id}');
        return;
      }

      _addMessage(message);
      _logger?.debug('Получено сообщение от ${message.senderName}');
    } catch (e) {
      _logger?.error('Ошибка обработки сообщения чата: $e');
    }
  }

  void _handlePrivateMessage(dynamic messageData) {
    try {
      final message = ChatMessage.fromJson(messageData as Map<String, dynamic>);
      _addMessage(message);
      _logger?.debug('Получено приватное сообщение от ${message.senderName}');
    } catch (e) {
      _logger?.error('Ошибка обработки приватного сообщения: $e');
    }
  }

  void _handleTypingEvent(dynamic typingData) {
    try {
      final typingEvent = TypingEvent.fromJson(typingData as Map<String, dynamic>);

      // Игнорируем свои индикаторы печатания
      if (typingEvent.userId == _currentUserId) return;

      _updateTypingIndicator(typingEvent);
      _logger?.debug('Обновлен индикатор печатания для ${typingEvent.userName}');
    } catch (e) {
      _logger?.error('Ошибка обработки индикатора печатания: $e');
    }
  }

  void _handleReactionUpdate(Map<String, dynamic> payload) {
    try {
      final messageId = payload['messageId'] as String;
      final emoji = payload['emoji'] as String;
      final userId = payload['userId'] as String;
      final action = payload['action'] as String;

      _updateMessageReaction(messageId, emoji, userId, action == 'add');
      _logger?.debug('Обновлена реакция $emoji для сообщения $messageId');
    } catch (e) {
      _logger?.error('Ошибка обработки реакции: $e');
    }
  }

  void _handleUserJoined(dynamic userData) {
    try {
      final user = ChatUser.fromJson(userData as Map<String, dynamic>);
      _addOrUpdateUser(user);
      _logger?.debug('Пользователь присоединился: ${user.name}');
    } catch (e) {
      _logger?.error('Ошибка обработки присоединения пользователя: $e');
    }
  }

  void _handleUserLeft(dynamic userIdData) {
    try {
      final userId = userIdData as String;
      _removeUser(userId);
      _logger?.debug('Пользователь покинул чат: $userId');
    } catch (e) {
      _logger?.error('Ошибка обработки ухода пользователя: $e');
    }
  }

  void _handleRouterEvent(RouterEvent event) {
    _logger?.debug('Событие роутера: ${event.type}');

    switch (event.type) {
      case RouterEventType.clientConnected:
        _refreshUsersList().catchError((e) {
          _logger?.warning('Ошибка обновления списка пользователей: $e');
        });
        break;
      case RouterEventType.clientDisconnected:
        final clientId = event.data['clientId'] as String?;
        if (clientId != null) {
          _removeUser(clientId);
        }
        break;
      default:
        // Другие события роутера нас не интересуют
        break;
    }
  }

  // === ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ===

  void _ensureConnected() {
    if (!isConnected) {
      throw StateError('Не подключен к серверу');
    }
  }

  void _setConnectionState(ChatConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionError = null;
      notifyListeners();
      _logger?.debug('Состояние подключения изменено: $state');
    }
  }

  void _setConnectionError(String error) {
    _connectionError = error;
    _setConnectionState(ChatConnectionState.error);
    _logger?.error('Ошибка подключения: $error');
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
    // Ограничиваем количество сообщений в памяти
    if (_messages.length > 1000) {
      _messages.removeRange(0, _messages.length - 1000);
    }
    notifyListeners();
  }

  void _addOrUpdateUser(ChatUser user) {
    final existingIndex = _users.indexWhere((u) => u.id == user.id);
    if (existingIndex >= 0) {
      _users[existingIndex] = user;
    } else {
      _users.add(user);
    }
    notifyListeners();
  }

  void _removeUser(String userId) {
    _users.removeWhere((user) => user.id == userId);
    _typingUsers.remove(userId);
    notifyListeners();
  }

  void _updateTypingIndicator(TypingEvent event) {
    if (event.isTyping) {
      _typingUsers.add(event.userId);
      // Автоматически убираем индикатор через 5 секунд
      Timer(Duration(seconds: 5), () {
        _typingUsers.remove(event.userId);
        notifyListeners();
      });
    } else {
      _typingUsers.remove(event.userId);
    }
    notifyListeners();
  }

  void _updateMessageReaction(String messageId, String emoji, String userId, bool add) {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex >= 0) {
      final message = _messages[messageIndex];
      final newReactions = Map<String, Set<String>>.from(message.reactions);

      if (add) {
        newReactions.putIfAbsent(emoji, () => <String>{}).add(userId);
      } else {
        newReactions[emoji]?.remove(userId);
        if (newReactions[emoji]?.isEmpty == true) {
          newReactions.remove(emoji);
        }
      }

      _messages[messageIndex] = message.copyWith(reactions: newReactions);
      notifyListeners();
    }
  }

  void _clearChatData() {
    _messages.clear();
    _users.clear();
    _typingUsers.clear();
    notifyListeners();
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Обновляет список пользователей
  Future<void> _refreshUsersList() async {
    try {
      final clients = await _routerClient!.getOnlineClients(groups: ['chat']);

      final users =
          clients
              .map(
                (client) => ChatUser(
                  id: client.clientId,
                  name: client.clientName ?? 'Пользователь',
                  isOnline: true,
                  lastSeen: client.lastActivity,
                  metadata: client.metadata,
                ),
              )
              .toList();

      _users.clear();
      _users.addAll(users);
      notifyListeners();

      _logger?.debug('Обновлен список пользователей: ${users.length} онлайн');
    } catch (e) {
      _logger?.error('Ошибка обновления списка пользователей: $e');
    }
  }

  /// Запускает heartbeat таймер
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (isConnected) {
        _routerClient?.heartbeat().catchError((e) {
          _logger?.warning('Ошибка heartbeat: $e');
        });
      }
    });
  }

  /// Останавливает heartbeat таймер
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Планирует переподключение с exponential backoff
  void _scheduleReconnect(String serverUrl, String username, RpcLogger? logger) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger?.error('Превышено максимальное количество попыток переподключения');
      _setConnectionError('Не удалось переподключиться после $_maxReconnectAttempts попыток');
      return;
    }

    _setConnectionState(ChatConnectionState.reconnecting);

    final delayIndex = min(_reconnectAttempts, _reconnectDelays.length - 1);
    final delay = Duration(seconds: _reconnectDelays[delayIndex]);

    _logger?.info(
      'Переподключение через ${delay.inSeconds} секунд (попытка ${_reconnectAttempts + 1})',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect(serverUrl: serverUrl, username: username, logger: logger);
    });
  }

  /// Останавливает таймер переподключения
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  @override
  void dispose() {
    _stopReconnectTimer();
    _stopHeartbeat();
    disconnect();
    super.dispose();
  }
}
