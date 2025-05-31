import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '../services/chat_service.dart';

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
    final savedServerUrl = prefs.getString('serverUrl') ?? 'ws://45.89.55.213:80';

    if (savedUsername != null) {
      _usernameController.text = savedUsername;
    }
    _serverUrlController.text = savedServerUrl;
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

      // Подключаемся
      await chatService.connect(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
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
                      'RPC Dart Chat',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Современный чат на Flutter и RPC',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Форма подключения
                    Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Подключение к серверу',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 24),

                              // Поле имени пользователя
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Ваше имя',
                                  hintText: 'Введите ваше имя',
                                  prefixIcon: const Icon(Icons.person),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.shuffle),
                                    onPressed: () {
                                      final random = DateTime.now().millisecondsSinceEpoch % 1000;
                                      _usernameController.text = 'Пользователь_$random';
                                    },
                                    tooltip: 'Случайное имя',
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите ваше имя';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Имя должно содержать минимум 2 символа';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                              ),

                              const SizedBox(height: 16),

                              // Поле URL сервера
                              TextFormField(
                                controller: _serverUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'Адрес сервера',
                                  hintText: 'ws://localhost:11111',
                                  prefixIcon: Icon(Icons.dns),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите адрес сервера';
                                  }
                                  if (!value.startsWith('ws://') && !value.startsWith('wss://')) {
                                    return 'URL должен начинаться с ws:// или wss://';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _connect(),
                              ),

                              const SizedBox(height: 24),

                              // Ошибка подключения
                              if (_connectionError != null)
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
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (_connectionError != null) const SizedBox(height: 16),

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
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
