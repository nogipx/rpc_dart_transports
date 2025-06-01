import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Современный экран приветствия с чистым дизайном
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _usernameFocus = FocusNode();
  final _serverUrlFocus = FocusNode();

  bool _isConnecting = false;
  String? _connectionError;
  bool _isExpanded = false;

  // Только основная анимация появления
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSavedData();
    _startAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
  }

  void _startAnimations() {
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _serverUrlController.dispose();
    _usernameFocus.dispose();
    _serverUrlFocus.dispose();
    super.dispose();
  }

  /// Загружает сохраненные данные
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final savedServerUrl = prefs.getString('serverUrl') ?? 'http://localhost:11112';

    if (mounted) {
      if (savedUsername != null) {
        _usernameController.text = savedUsername;
      }
      _serverUrlController.text = savedServerUrl;
    }
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

    HapticFeedback.lightImpact();

    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      await _saveConnectionData();

      final chatService = ChatService();
      final logger = RpcLogger('ChatApp');

      await chatService.connect(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        logger: logger,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    ChangeNotifierProvider.value(value: chatService, child: const ChatScreen()),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
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
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(opacity: _fadeAnimation.value, child: _buildContent(theme));
          },
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 48),
              _buildForm(theme),
              const SizedBox(height: 24),
              _buildInfoSection(theme),
              const SizedBox(height: 32),
              _buildConnectButton(theme),
              if (_connectionError != null) ...[const SizedBox(height: 20), _buildErrorCard(theme)],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        // Простая иконка без излишних эффектов
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 40,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // Заголовок
        Text(
          'RPC Dart Chat',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        // Подзаголовок
        Text(
          'Современный чат на HTTP/2',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Поле имени пользователя
          _buildTextField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            label: 'Имя пользователя',
            icon: Icons.person_outline,
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
            onFieldSubmitted: (_) => _serverUrlFocus.requestFocus(),
          ),
          const SizedBox(height: 16),

          // Поле адреса сервера
          _buildTextField(
            controller: _serverUrlController,
            focusNode: _serverUrlFocus,
            label: 'Адрес сервера',
            icon: Icons.dns_outlined,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required TextInputAction textInputAction,
    TextInputType? keyboardType,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onFieldSubmitted: onFieldSubmitted,
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
        title: Text(
          'Информация о подключении',
          style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
        ),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
          HapticFeedback.lightImpact();
        },
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [_buildInfoContent(theme)],
      ),
    );
  }

  Widget _buildInfoContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Возможности
        Text(
          'Возможности',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...[
          'Высокая производительность HTTP/2',
          'Автоматическое переподключение',
          'Современный gRPC протокол',
          'Мгновенная доставка сообщений',
        ].map(
          (feature) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(feature, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Примеры серверов
        Text(
          'Примеры серверов',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...[
          {'label': 'Локальный', 'url': 'http://localhost:11112'},
          {'label': 'Разработка', 'url': 'http://192.168.1.100:8080'},
        ].map(
          (example) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    example['label']!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    example['url']!,
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: example['url']!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('URL скопирован'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    HapticFeedback.lightImpact();
                  },
                  icon: Icon(Icons.copy, size: 16),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isConnecting ? null : _connect,
        icon:
            _isConnecting
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                  ),
                )
                : Icon(Icons.login),
        label: Text(
          _isConnecting ? 'Подключение...' : 'Подключиться к чату',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ошибка подключения',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _connectionError!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _connectionError = null);
                HapticFeedback.lightImpact();
              },
              icon: Icon(Icons.close, color: theme.colorScheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}
