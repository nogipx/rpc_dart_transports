// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Статистика роутера
class RouterStats {
  final int activeClients;
  final List<String> clientIds;
  final Map<String, int>? messageStats;
  final DateTime? startTime;

  /// Общее количество обработанных сообщений
  final int totalMessages;

  /// Количество ошибок роутера
  final int errorCount;

  const RouterStats({
    required this.activeClients,
    required this.clientIds,
    this.messageStats,
    this.startTime,
    this.totalMessages = 0,
    this.errorCount = 0,
  });

  @override
  String toString() {
    return 'RouterStats('
        'activeClients: $activeClients, '
        'clientIds: $clientIds'
        '${messageStats != null ? ', messageStats: $messageStats' : ''}'
        '${startTime != null ? ', startTime: $startTime' : ''}'
        ', totalMessages: $totalMessages'
        ', errorCount: $errorCount'
        ')';
  }
}
