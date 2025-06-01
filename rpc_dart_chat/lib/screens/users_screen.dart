import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';
import '../models/chat_models.dart';

/// Экран списка активных пользователей
class UsersScreen extends StatefulWidget {
  final ChatService chatService;

  const UsersScreen({super.key, required this.chatService});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Активные пользователи'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${widget.chatService.onlineUsers.length}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _buildUsersList(),
    );
  }

  /// Строит список активных пользователей
  Widget _buildUsersList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Статистика
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Статистика чата',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      Icons.circle,
                      'Онлайн',
                      widget.chatService.onlineUsers
                          .where((u) => u.status == UserStatus.online)
                          .length
                          .toString(),
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      Icons.schedule,
                      'Неактивные',
                      widget.chatService.onlineUsers
                          .where((u) => u.status == UserStatus.idle)
                          .length
                          .toString(),
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      Icons.do_not_disturb,
                      'Занято',
                      widget.chatService.onlineUsers
                          .where((u) => u.status == UserStatus.busy)
                          .length
                          .toString(),
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Список пользователей
        if (widget.chatService.onlineUsers.isEmpty)
          _buildEmptyUsersState()
        else
          ...widget.chatService.onlineUsers.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final isCurrentUser = user.username == widget.chatService.currentUsername;

            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + (index * 50)),
              margin: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: isCurrentUser ? 4 : 1,
                color: isCurrentUser ? Theme.of(context).colorScheme.primaryContainer : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      isCurrentUser
                          ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                          : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            isCurrentUser
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                        child: Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                          style: TextStyle(
                            color:
                                isCurrentUser
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _getStatusColor(user.status),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.username,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isCurrentUser
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : null,
                          ),
                        ),
                      ),
                      if (isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Вы',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(user.status),
                            size: 14,
                            color: _getStatusColor(user.status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusText(user.status),
                            style: TextStyle(
                              color:
                                  isCurrentUser
                                      ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      if (user.lastSeen != null)
                        Text(
                          _formatLastSeen(user.lastSeen!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                isCurrentUser
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  trailing:
                      !isCurrentUser
                          ? PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'message',
                                    child: Row(
                                      children: [
                                        Icon(Icons.message, size: 18),
                                        const SizedBox(width: 8),
                                        Text('Написать'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'info',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info, size: 18),
                                        const SizedBox(width: 8),
                                        Text('Информация'),
                                      ],
                                    ),
                                  ),
                                ],
                            onSelected: (value) {
                              switch (value) {
                                case 'message':
                                  // Здесь можно добавить логику для отправки личного сообщения
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Личные сообщения пока не реализованы')),
                                  );
                                  break;
                                case 'info':
                                  _showUserInfo(context, user);
                                  break;
                              }
                            },
                          )
                          : null,
                  onTap:
                      isCurrentUser
                          ? null
                          : () {
                            _showUserInfo(context, user);
                          },
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Строит карточку статистики
  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Строит состояние пустого списка пользователей
  Widget _buildEmptyUsersState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет активных пользователей',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Пригласите друзей в чат!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Показывает информацию о пользователе
  void _showUserInfo(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(user.username, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  context,
                  Icons.circle,
                  'Статус',
                  _getStatusText(user.status),
                  _getStatusColor(user.status),
                ),
                if (user.lastSeen != null)
                  _buildInfoRow(
                    context,
                    Icons.schedule,
                    'Последняя активность',
                    _formatLastSeen(user.lastSeen!),
                    null,
                  ),
                _buildInfoRow(
                  context,
                  Icons.person,
                  'ID пользователя',
                  '${user.username}#${user.username.hashCode.abs() % 10000}',
                  null,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
            ],
          ),
    );
  }

  /// Строит строку информации
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color? color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Получает иконку статуса
  IconData _getStatusIcon(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Icons.circle;
      case UserStatus.idle:
        return Icons.schedule;
      case UserStatus.busy:
        return Icons.do_not_disturb;
      case UserStatus.offline:
        return Icons.circle_outlined;
    }
  }

  /// Получает текст статуса
  String _getStatusText(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'В сети';
      case UserStatus.idle:
        return 'Неактивен';
      case UserStatus.busy:
        return 'Не беспокоить';
      case UserStatus.offline:
        return 'Не в сети';
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
}
