import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models/chat_models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPC Dart Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final List<ChatMessage> _messages = [];

  RouterClient? _routerClient;
  String? _clientId;
  bool _isConnected = false;
  String _connectionStatus = 'Отключен';

  @override
  void initState() {
    super.initState();
    _usernameController.text = 'Пользователь_${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  Future<void> _connect() async {
    try {
      setState(() {
        _connectionStatus = 'Подключение...';
      });

      // Подключаемся к роутеру через WebSocket
      const String serverUrl = 'ws://45.89.55.213:80';
      final channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      final transport = RpcWebSocketCallerTransport(channel);
      final endpoint = RpcCallerEndpoint(transport: transport);

      // Создаем клиент роутера с логированием
      _routerClient = RouterClient(callerEndpoint: endpoint, logger: RpcLogger('ChatClient'));

      // Регистрируемся в роутере
      _clientId = await _routerClient!.register(
        clientName: _usernameController.text,
        groups: ['general'], // Присоединяемся к общей группе
        metadata: {'platform': 'flutter'},
      );

      // Инициализируем P2P соединение
      await _routerClient!.initializeP2P(
        onP2PMessage: _handleP2PMessage,
        filterRouterHeartbeats: true,
      );

      // Подписываемся на события роутера
      await _routerClient!.subscribeToEvents();
      _routerClient!.events.listen(_handleRouterEvent);

      setState(() {
        _isConnected = true;
        _connectionStatus = 'Подключен как ${_usernameController.text}';
      });

      _addSystemMessage('✅ Подключен к чату!');
    } catch (e) {
      setState(() {
        _connectionStatus = 'Ошибка: $e';
      });
      _addSystemMessage('❌ Ошибка подключения: $e');
    }
  }

  Future<void> _disconnect() async {
    await _routerClient?.dispose();
    _routerClient = null;
    _clientId = null;

    setState(() {
      _isConnected = false;
      _connectionStatus = 'Отключен';
      _messages.clear();
    });
  }

  Future<void> _checkOnlineClients() async {
    if (_routerClient == null) {
      _addSystemMessage('❌ Роутер клиент не инициализирован');
      return;
    }

    _addSystemMessage('🔍 Проверяем список онлайн клиентов...');

    try {
      final onlineClients = await _routerClient!.getOnlineClients();

      _addSystemMessage('✅ Найдено клиентов: ${onlineClients.length}');

      if (onlineClients.isEmpty) {
        _addSystemMessage('😴 Других клиентов нет');
      } else {
        for (final client in onlineClients) {
          if (client.clientId != _clientId) {
            _addSystemMessage('  🧑‍💻 ${client.clientName} (группы: ${client.groups.join(', ')})');
          }
        }
      }
    } catch (e) {
      _addSystemMessage('❌ Ошибка: ${e.toString()}');
    }
  }

  void _handleP2PMessage(RouterMessage message) {
    // Обрабатываем разные типы сообщений
    switch (message.type) {
      case RouterMessageType.multicast:
      case RouterMessageType.broadcast:
        _handleChatMessage(message);
        break;
      case RouterMessageType.unicast:
        _handleDirectMessage(message);
        break;
      case RouterMessageType.heartbeat:
        // Игнорируем heartbeat сообщения
        break;
      default:
        debugPrint('Неизвестный тип сообщения: ${message.type}');
    }
  }

  void _handleChatMessage(RouterMessage message) {
    final payload = message.payload;
    if (payload != null && payload.containsKey('chatMessage')) {
      try {
        final chatMessage = ChatMessage.fromJson(payload['chatMessage']);
        setState(() {
          _messages.add(chatMessage);
        });
      } catch (e) {
        debugPrint('Ошибка парсинга сообщения чата: $e');
      }
    }
  }

  void _handleDirectMessage(RouterMessage message) {
    final payload = message.payload;
    if (payload != null) {
      final text = payload['message'] ?? 'Прямое сообщение';
      final sender = message.senderId ?? 'Неизвестный';
      _addSystemMessage('💬 Личное от $sender: $text');
    }
  }

  void _handleRouterEvent(RouterEvent event) {
    switch (event.type) {
      case RouterEventType.clientConnected:
        final clientName = event.data['clientName'] ?? 'Неизвестный';
        _addSystemMessage('👋 $clientName присоединился к чату');
        break;
      case RouterEventType.clientDisconnected:
        final clientId = event.data['clientId'] ?? 'Неизвестный';
        _addSystemMessage('👋 Клиент $clientId покинул чат');
        break;
      default:
        debugPrint('Событие роутера: ${event.type}');
    }
  }

  void _addSystemMessage(String text) {
    final systemMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: 'Система',
      message: text,
      room: 'general',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(systemMessage);
    });
  }

  Future<void> _sendMessage() async {
    if (!_isConnected || _routerClient == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Создаем сообщение чата
      final chatMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: _usernameController.text,
        message: text,
        room: 'general',
        timestamp: DateTime.now(),
      );

      // Отправляем как multicast в группу 'general'
      await _routerClient!.sendBroadcast({'chatMessage': chatMessage.toJson()});

      // Добавляем свое сообщение в список (поскольку multicast не возвращается отправителю)
      setState(() {
        _messages.add(chatMessage);
      });

      _messageController.clear();
    } catch (e) {
      _addSystemMessage('❌ Ошибка отправки: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RPC Dart Chat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _connectionStatus,
              style: TextStyle(
                color: _isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Панель подключения
          if (!_isConnected) ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Ваше имя',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _connect, child: const Text('Подключиться')),
                ],
              ),
            ),
          ] else ...[
            // Панель управления для подключенного клиента
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue[50],
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _checkOnlineClients,
                    icon: const Icon(Icons.people, size: 16),
                    label: const Text('Проверить клиентов'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Отключиться'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[800],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Список сообщений
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSystem = message.username == 'Система';
                final isOwnMessage = message.username == _usernameController.text;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isSystem
                                ? Colors.grey[300]
                                : isOwnMessage
                                ? Colors.blue[100]
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isSystem && !isOwnMessage)
                            Text(
                              message.username,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          Text(message.message),
                          Text(
                            '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Поле ввода сообщения
          if (_isConnected) ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Введите сообщение...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _sendMessage, child: const Text('Отправить')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _routerClient?.dispose();
    _messageController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
