import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '../services/chat_service.dart';
import '../models/chat_models.dart';

/// Экран приветствия и подключения к серверу
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _serverUrlController = TextEditingController();

  bool _isConnecting = false;
  String? _connectionError;
  TransportType _selectedTransport = TransportType.http2;

  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;

  @override
  void initState() {
    super.initState();

    // Настраиваем анимацию логотипа
    _logoAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _logoScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoAnimationController, curve: Curves.elasticOut));

    _logoRotation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeInOut));

    // Запускаем анимацию
    _logoAnimationController.forward();

    // Загружаем сохраненные данные
    _loadSavedData();

    // Генерируем случайное имя пользователя
    _generateRandomUsername();
  }

  @override
  void dispose() {
    // Останавливаем анимацию
    _logoAnimationController.stop();
    _logoAnimationController.dispose();

    // Закрываем контроллеры
    _usernameController.dispose();
    _serverUrlController.dispose();

    super.dispose();
  }

  /// Загружает сохраненные данные
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final savedServerUrl = prefs.getString('serverUrl') ?? 'http://localhost:11112';
    final savedTransport = prefs.getString('transport') ?? TransportType.http2.name;

    if (savedUsername != null) {
      _usernameController.text = savedUsername;
    }
    _serverUrlController.text = savedServerUrl;

    // Восстанавливаем выбранный транспорт
    _selectedTransport = TransportType.values.firstWhere(
      (t) => t.name == savedTransport,
      orElse: () => TransportType.http2,
    );
  }

  /// Генерирует случайное имя пользователя
  void _generateRandomUsername() {
    if (_usernameController.text.isEmpty) {
      final random = DateTime.now().millisecondsSinceEpoch % 1000;
      _usernameController.text = 'Пользователь_$random';
    }
  }

  /// Сохраняет данные пользователя
  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text);
    await prefs.setString('serverUrl', _serverUrlController.text);
    await prefs.setString('transport', _selectedTransport.name);
  }

  /// Подключается к серверу
  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      final chatService = context.read<ChatService>();

      // Сохраняем данные
      await _saveUserData();

      // Подключаемся с выбранным транспортом
      await chatService.connect(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        transportType: _selectedTransport,
        logger: RpcLogger('ChatApp'),
      );
    } catch (e) {
      // Проверяем mounted перед setState после асинхронной операции
      if (!mounted) return;
      setState(() {
        _connectionError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      // Проверяем mounted перед setState в finally блоке
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  /// Обновляет URL для выбранного транспорта
  void _updateUrlForTransport(TransportType transport) {
    final currentUrl = _serverUrlController.text;

    // Получаем базовый хост и порт
    String host = 'localhost';
    int port = 11112; // HTTP/2 порт по умолчанию

    if (currentUrl.isNotEmpty) {
      final uri = Uri.tryParse(currentUrl);
      if (uri != null) {
        host = uri.host;
        // Извлекаем порт с учетом того, что он может быть указан в path или port
        port =
            uri.port != 0
                ? uri.port
                : (uri.pathSegments.isNotEmpty
                    ? int.tryParse(uri.pathSegments.first) ?? 11112
                    : 11112);
      }
    }

    String newUrl;
    switch (transport) {
      case TransportType.websocket:
        // WebSocket обычно на порту -1
        newUrl = 'ws://$host:${port == 11112 ? 11111 : port}';
        break;
      case TransportType.http2:
        newUrl = 'http://$host:$port';
        break;
      case TransportType.inMemory:
        newUrl = 'memory://local';
        break;
    }

    _serverUrlController.text = newUrl;
  }

  /// Виджет выбора транспорта
  Widget _buildTransportSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип транспорта', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Column(
              children:
                  TransportType.values.map((transport) {
                    String title;
                    String subtitle;
                    IconData icon;
                    bool enabled = true;

                    switch (transport) {
                      case TransportType.websocket:
                        title = 'WebSocket';
                        subtitle = 'Традиционный, надежный';
                        icon = Icons.wifi;
                        break;
                      case TransportType.http2:
                        title = 'HTTP/2';
                        subtitle = 'Высокая производительность';
                        icon = Icons.speed;
                        break;
                      case TransportType.inMemory:
                        title = 'In-Memory';
                        subtitle = 'Только для тестирования';
                        icon = Icons.memory;
                        enabled = false; // Пока не поддерживается
                        break;
                    }

                    return RadioListTile<TransportType>(
                      value: transport,
                      groupValue: _selectedTransport,
                      onChanged:
                          enabled
                              ? (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedTransport = value;
                                    _updateUrlForTransport(value);
                                  });
                                }
                              }
                              : null,
                      title: Row(
                        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title)],
                      ),
                      subtitle: Text(subtitle),
                      dense: true,
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.1),
              colorScheme.secondaryContainer.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Анимированный логотип
                      AnimatedBuilder(
                        animation: _logoAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Transform.rotate(
                              angle: _logoRotation.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline,
                                  size: 60,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Заголовок
                      Text(
                        'RPC Dart Chat 2.0',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Транспорт-агностичный чат',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Форма подключения
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Поле имени пользователя
                              TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Имя пользователя',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите имя пользователя';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Слишком короткое имя';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                              ),

                              const SizedBox(height: 20),

                              // Поле URL сервера
                              TextFormField(
                                controller: _serverUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'URL сервера',
                                  prefixIcon: Icon(Icons.dns),
                                  helperText: 'ws://host:port или http://host:port',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите URL сервера';
                                  }
                                  final uri = Uri.tryParse(value.trim());
                                  if (uri == null) {
                                    return 'Некорректный URL';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _connect(),
                              ),

                              const SizedBox(height: 24),

                              // Кнопка подключения
                              FilledButton.icon(
                                onPressed: _isConnecting ? null : _connect,
                                icon:
                                    _isConnecting
                                        ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                        : const Icon(Icons.login),
                                label: Text(_isConnecting ? 'Подключение...' : 'Подключиться'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),

                              // Ошибка подключения
                              if (_connectionError != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: colorScheme.onErrorContainer,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _connectionError!,
                                          style: TextStyle(
                                            color: colorScheme.onErrorContainer,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Селектор транспорта
                      _buildTransportSelector(),

                      const SizedBox(height: 24),

                      // Информация
                      Card(
                        color: colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(Icons.info_outline, color: colorScheme.primary, size: 24),
                              const SizedBox(height: 8),
                              Text('Примеры серверов:', style: theme.textTheme.titleSmall),
                              const SizedBox(height: 8),
                              Text(
                                '• HTTP/2: http://localhost:11112\n'
                                '• WebSocket: ws://localhost:11111\n'
                                '• Удаленный: http://example.com:443',
                                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
