import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';
import '../models/chat_models.dart';

/// Основной экран чата
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isComposing = false;

  @override
  void initState() {
    super.initState();

    // Прокручиваем вниз при изменении сообщений
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = context.read<ChatService>();
      chatService.addListener(_onChatServiceChanged);
    });
  }

  @override
  void dispose() {
    final chatService = context.read<ChatService>();
    chatService.removeListener(_onChatServiceChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Обрабатывает изменения в ChatService
  void _onChatServiceChanged() {
    // Прокручиваем вниз при добавлении новых сообщений
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;

        // Прокручиваем только если мы близко к низу (в пределах 100px)
        if (maxScroll - currentScroll < 100) {
          _scrollToBottom();
        }
      }
    });
  }

  /// Отправляет сообщение
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatService = context.read<ChatService>();
    await chatService.sendMessage(text);

    _messageController.clear();
    setState(() {
      _isComposing = false;
    });

    // Прокручиваем к последнему сообщению
    _scrollToBottom();
  }

  /// Прокручивает к последнему сообщению
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Обрабатывает изменение текста
  void _onTextChanged(String text) {
    final bool isComposing = text.trim().isNotEmpty;

    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });

      final chatService = context.read<ChatService>();
      if (isComposing) {
        chatService.startTyping();
      }
    }
  }

  /// Отключается от чата
  Future<void> _disconnect() async {
    final chatService = context.read<ChatService>();
    await chatService.disconnect();
  }

  /// Показывает bottom sheet управления комнатами
  void _showRoomsBottomSheet(BuildContext context, ChatService chatService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RoomsBottomSheet(chatService: chatService),
    );
  }

  /// Показывает детали подключения в bottom sheet
  void _showConnectionDetails(BuildContext context, ChatService chatService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ConnectionDetailsBottomSheet(chatService: chatService),
    );
  }

  /// Получает текст для подзаголовка AppBar
  String _getSubtitleText(ChatService chatService) {
    // Если есть активное подключение
    if (chatService.isConnected) {
      return 'Комната: ${chatService.currentRoom}';
    }

    // Иначе показываем состояние подключения
    switch (chatService.connectionState) {
      case ChatConnectionState.connected:
        return 'Комната: ${chatService.currentRoom}';
      case ChatConnectionState.reconnecting:
        return 'Переподключение к серверу...';
      case ChatConnectionState.disconnected:
        return 'Нет подключения';
      case ChatConnectionState.connecting:
        return 'Подключение к серверу...';
      case ChatConnectionState.error:
        return 'Ошибка подключения';
    }
  }

  /// Получает цвет для подзаголовка AppBar
  Color _getSubtitleColor(BuildContext context, ChatService chatService) {
    switch (chatService.connectionState) {
      case ChatConnectionState.connected:
        return Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
      case ChatConnectionState.reconnecting:
      case ChatConnectionState.disconnected:
        return Colors.red;
      case ChatConnectionState.connecting:
        return Colors.blue;
      case ChatConnectionState.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: _buildAppBar(context, chatService),
          body: Column(
            children: [
              // Информация о подключении
              _buildConnectionInfo(chatService),

              // Список сообщений
              Expanded(child: SafeArea(bottom: false, child: _buildMessagesList(chatService))),

              // Индикатор печатания
              _buildTypingIndicator(chatService),

              // Поле ввода сообщения
              SafeArea(top: false, child: _buildMessageInput(chatService)),
            ],
          ),
          drawer: _buildSidebar(chatService),
        );
      },
    );
  }

  /// Строит AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context, ChatService chatService) {
    return AppBar(
      leading: _buildConnectionStatus(context, chatService),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RPC Dart Chat'),
          Text(
            _getSubtitleText(chatService),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _getSubtitleColor(context, chatService)),
          ),
        ],
      ),
      actions: [
        // Количество пользователей онлайн (кликабельно)
        GestureDetector(
          onTap: () => _showRoomsBottomSheet(context, chatService),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  '${chatService.onlineUsers.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Строит индикатор статуса подключения
  Widget _buildConnectionStatus(BuildContext context, ChatService chatService) {
    Color statusColor;
    IconData statusIcon;

    switch (chatService.connectionState) {
      case ChatConnectionState.connected:
        statusColor = Colors.green;
        statusIcon = Icons.wifi;
        break;
      case ChatConnectionState.reconnecting:
      case ChatConnectionState.disconnected:
        statusColor = Colors.orange;
        statusIcon = Icons.wifi_off;
        break;
      case ChatConnectionState.connecting:
        statusColor = Colors.blue;
        statusIcon = Icons.wifi;
        break;
      case ChatConnectionState.error:
        statusColor = Colors.red;
        statusIcon = Icons.wifi_off;
        break;
    }

    return GestureDetector(
      onTap: () => _showConnectionDetails(context, chatService),
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        child: Icon(statusIcon, color: Colors.white, size: 20),
      ),
    );
  }

  /// Строит информацию о подключении
  Widget _buildConnectionInfo(ChatService chatService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Text(
        'Подключен как ${chatService.currentUsername}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Строит список сообщений
  Widget _buildMessagesList(ChatService chatService) {
    final messages = chatService.currentMessages;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Пока сообщений нет',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Начните общение!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(
          message: message,
          isOwnMessage: message.username == chatService.currentUsername,
          onReaction: (emoji) => chatService.addReaction(message.id, emoji),
        );
      },
    );
  }

  /// Строит индикатор печатания
  Widget _buildTypingIndicator(ChatService chatService) {
    final typingUsers = chatService.currentlyTyping;

    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const _TypingAnimation(),
          const SizedBox(width: 8),
          Text(
            typingUsers.length == 1
                ? '${typingUsers.first} печатает...'
                : '${typingUsers.length} пользователей печатают...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// Строит поле ввода сообщения
  Widget _buildMessageInput(ChatService chatService) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 120, // Ограничиваем высоту поля ввода
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onChanged: _onTextChanged,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _isComposing ? _sendMessage : null,
            child: Icon(_isComposing ? Icons.send : Icons.send_outlined),
          ),
        ],
      ),
    );
  }

  /// Строит боковую панель
  Widget _buildSidebar(ChatService chatService) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Кастомный header вместо DrawerHeader для лучшего контроля
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RPC Dart Chat',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chatService.currentUsername ?? 'Неизвестный',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Список онлайн пользователей
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Онлайн пользователи (${chatService.onlineUsers.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...chatService.onlineUsers.map(
                    (user) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        child: Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
                        ),
                      ),
                      title: Text(user.username),
                      subtitle:
                          user.lastSeen != null ? Text(_formatLastSeen(user.lastSeen!)) : null,
                      trailing: Icon(Icons.circle, color: _getStatusColor(user.status), size: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Кнопка отключения
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.logout),
                label: const Text('Отключиться'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Форматирует время последней активности
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Сейчас онлайн';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else {
      return DateFormat('dd.MM.yyyy').format(lastSeen);
    }
  }

  /// Получает цвет статуса пользователя
  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.idle:
        return Colors.orange;
      case UserStatus.busy:
        return Colors.red;
      case UserStatus.offline:
        return Colors.grey;
    }
  }
}

/// Виджет сообщения в чате
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwnMessage;
  final void Function(String emoji) onReaction;

  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
    required this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSystem = message.type == ChatMessageType.system;

    if (isSystem) {
      return _buildSystemMessage(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOwnMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: Text(
                message.username.isNotEmpty ? message.username[0].toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.onSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showReactionPicker(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isOwnMessage
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                    bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isOwnMessage)
                      Text(
                        message.username,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      message.message,
                      style: TextStyle(
                        color:
                            isOwnMessage
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(message.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                isOwnMessage
                                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (message.isEdited) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 12,
                            color:
                                isOwnMessage
                                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ],
                      ],
                    ),
                    if (message.reactions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children:
                            message.reactions.entries
                                .map(
                                  (reaction) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${reaction.key} ${reaction.value}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Строит системное сообщение
  Widget _buildSystemMessage(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Показывает селектор реакций
  void _showReactionPicker(BuildContext context) {
    const reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Выберите реакцию', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      reactions
                          .map(
                            (emoji) => GestureDetector(
                              onTap: () {
                                onReaction(emoji);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 24)),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
    );
  }
}

/// Анимация печатания
class _TypingAnimation extends StatefulWidget {
  const _TypingAnimation();

  @override
  State<_TypingAnimation> createState() => _TypingAnimationState();
}

class _TypingAnimationState extends State<_TypingAnimation> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (1.0 - (value * 2 - 1).abs()).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Bottom sheet с деталями подключения
class _ConnectionDetailsBottomSheet extends StatelessWidget {
  final ChatService chatService;

  const _ConnectionDetailsBottomSheet({required this.chatService});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (chatService.connectionState) {
      case ChatConnectionState.connected:
        statusColor = Colors.green;
        statusIcon = Icons.wifi;
        break;
      case ChatConnectionState.reconnecting:
      case ChatConnectionState.disconnected:
        statusColor = Colors.red;
        statusIcon = Icons.wifi_off;
        break;
      case ChatConnectionState.connecting:
        statusColor = Colors.blue;
        statusIcon = Icons.wifi;
        break;
      case ChatConnectionState.error:
        statusColor = Colors.red;
        statusIcon = Icons.wifi_off;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Заголовок
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                child: Icon(statusIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Состояние подключения', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),

          const SizedBox(height: 24),

          // Детали подключения
          _buildConnectionDetailRow(
            context,
            'Статус:',
            _getConnectionStateText(chatService.connectionState),
          ),

          if (chatService.isConnected) ...[
            const SizedBox(height: 12),
            _buildConnectionDetailRow(context, 'Клиент ID:', chatService.clientId ?? 'Неизвестно'),
            const SizedBox(height: 12),
            _buildConnectionDetailRow(
              context,
              'Имя пользователя:',
              chatService.currentUsername ?? 'Неизвестно',
            ),
            const SizedBox(height: 12),
            _buildConnectionDetailRow(context, 'Комната:', chatService.currentRoom),
          ],

          const SizedBox(height: 24),

          // Кнопки действий
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (chatService.connectionState != ChatConnectionState.connected)
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await chatService.reconnect();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Переподключиться'),
                ),
              if (chatService.connectionState != ChatConnectionState.connected)
                const SizedBox(width: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
            ],
          ),
        ],
      ),
    );
  }

  /// Строит строку с деталью подключения
  Widget _buildConnectionDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }

  /// Получает текстовое описание состояния подключения
  String _getConnectionStateText(ChatConnectionState state) {
    switch (state) {
      case ChatConnectionState.connected:
        return 'Подключено';
      case ChatConnectionState.reconnecting:
        return 'Переподключение...';
      case ChatConnectionState.connecting:
        return 'Подключение...';
      case ChatConnectionState.disconnected:
        return 'Отключено';
      case ChatConnectionState.error:
        return 'Ошибка';
    }
  }
}

/// Bottom sheet управления комнатами
class _RoomsBottomSheet extends StatefulWidget {
  final ChatService chatService;

  const _RoomsBottomSheet({required this.chatService});

  @override
  State<_RoomsBottomSheet> createState() => _RoomsBottomSheetState();
}

class _RoomsBottomSheetState extends State<_RoomsBottomSheet> {
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomDescriptionController = TextEditingController();

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Заголовок
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.meeting_room, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Управление комнатами',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Содержимое
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(icon: Icon(Icons.list), text: 'Комнаты'),
                          Tab(icon: Icon(Icons.add), text: 'Создать'),
                        ],
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildRoomsList(scrollController),
                            _buildCreateRoom(scrollController),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Строит список доступных комнат
  Widget _buildRoomsList(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Текущая комната
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: Icon(
              Icons.radio_button_checked,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            title: Text(
              widget.chatService.currentRoom,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Текущая комната',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
            trailing: Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Доступные комнаты
        Text('Доступные комнаты', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        ...widget.chatService.availableRooms
            .where((room) => room.id != widget.chatService.currentRoom)
            .map(
              (room) => Card(
                child: ListTile(
                  leading: Icon(
                    room.isPrivate ? Icons.lock : Icons.public,
                    color: room.isPrivate ? Colors.orange : Colors.green,
                  ),
                  title: Text(room.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (room.description != null) Text(room.description!),
                      Text(
                        '${room.members.length} участников',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => _joinRoom(room.id),
                    child: const Text('Войти'),
                  ),
                  isThreeLine: room.description != null,
                ),
              ),
            ),

        // Если нет других комнат
        if (widget.chatService.availableRooms.length <= 1)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Других комнат пока нет',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Создайте новую комнату для общения!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Строит форму создания комнаты
  Widget _buildCreateRoom(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Создание новой комнаты', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            TextField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                labelText: 'Название комнаты',
                hintText: 'Введите название комнаты',
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _roomDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание (необязательно)',
                hintText: 'Описание комнаты',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _createRoom,
              icon: const Icon(Icons.add),
              label: const Text('Создать комнату'),
            ),

            const SizedBox(height: 16),

            // Подсказки
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Подсказки:',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Используйте понятные названия\n'
                      '• Все комнаты по умолчанию публичные\n'
                      '• После создания вы автоматически присоединитесь',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Создает новую комнату
  Future<void> _createRoom() async {
    final name = _roomNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название комнаты')));
      return;
    }

    try {
      await widget.chatService.createRoom(
        name,
        _roomDescriptionController.text.trim().isNotEmpty
            ? _roomDescriptionController.text.trim()
            : null,
      );

      _roomNameController.clear();
      _roomDescriptionController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Комната "$name" создана!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка создания комнаты: $e')));
      }
    }
  }

  /// Присоединяется к комнате
  Future<void> _joinRoom(String roomId) async {
    try {
      await widget.chatService.joinRoom(roomId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Вы присоединились к комнате "$roomId"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка присоединения: $e')));
      }
    }
  }
}
