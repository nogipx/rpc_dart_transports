import 'package:flutter/material.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Экран приветствия с настройками подключения
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _usernameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isConnecting = false;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  /// Загружает сохраненные данные
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final savedServerUrl = prefs.getString('serverUrl') ?? 'http://localhost:11112';

    if (savedUsername != null) {
      _usernameController.text = savedUsername;
    }
    _serverUrlController.text = savedServerUrl;
  }

  /// Сохраняет данные подключения
  Future<void> _saveConnectionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text);
    await prefs.setString('serverUrl', _serverUrlController.text);
  }

  /// Выполняет подключение к чату
  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      // Сохраняем данные для следующего раза
      await _saveConnectionData();

      // Создаем сервис чата
      final chatService = ChatService();

      // Создаем логгер для отладки (в релизе можно отключить)
      final logger = RpcLogger('ChatApp');

      // Подключаемся через HTTP/2
      await chatService.connect(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        logger: logger,
      );

      if (mounted) {
        // Переходим к экрану чата через Provider
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    ChangeNotifierProvider.value(value: chatService, child: const ChatScreen()),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _connectionError = e.toString();
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor.withValues(alpha: 0.1),
              theme.primaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Заголовок
                        Icon(Icons.chat_bubble_outline, size: 64, color: theme.primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          'RPC Dart Chat',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Высокопроизводительный чат на HTTP/2',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Поле ввода имени пользователя
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Имя пользователя',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите имя пользователя';
                            }
                            if (value.trim().length < 2) {
                              return 'Имя должно содержать минимум 2 символа';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                          autofocus: _usernameController.text.isEmpty,
                        ),
                        const SizedBox(height: 16),

                        // Поле ввода URL сервера
                        TextFormField(
                          controller: _serverUrlController,
                          decoration: InputDecoration(
                            labelText: 'Адрес сервера',
                            prefixIcon: const Icon(Icons.dns),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            helperText: 'HTTP/2 endpoint роутера',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите адрес сервера';
                            }
                            try {
                              final uri = Uri.parse(value.trim());
                              if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
                                return 'URL должен начинаться с http:// или https://';
                              }
                            } catch (e) {
                              return 'Некорректный URL';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.url,
                          onFieldSubmitted: (_) => _connect(),
                          autofocus: _usernameController.text.isNotEmpty,
                        ),
                        const SizedBox(height: 24),

                        // Информация о транспорте
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.rocket_launch, color: theme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'HTTP/2 Транспорт',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Высокая производительность\n'
                                '• Мультиплексирование\n'
                                '• Автоматическое переподключение\n'
                                '• Современный gRPC-стиль протокол',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Примеры серверов
                        ExpansionTile(
                          leading: const Icon(Icons.info_outline, size: 20),
                          title: Text(
                            'Примеры серверов',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '• Локальный: http://localhost:11112\n'
                                '• Продакшн: https://example.com:443\n'
                                '• Разработка: http://192.168.1.100:8080',
                                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Кнопка подключения
                        ElevatedButton(
                          onPressed: _isConnecting ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child:
                              _isConnecting
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.login),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Подключиться к чату',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                        ),

                        // Ошибка подключения
                        if (_connectionError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.onErrorContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _connectionError!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
