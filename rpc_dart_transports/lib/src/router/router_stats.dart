// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Статистика роутера
class RouterStats {
  final int activeClients;
  final List<String> clientIds;
  final Map<String, int>? messageStats;
  final DateTime? startTime;

  const RouterStats({
    required this.activeClients,
    required this.clientIds,
    this.messageStats,
    this.startTime,
  });

  @override
  String toString() {
    return 'RouterStats('
        'activeClients: $activeClients, '
        'clientIds: $clientIds'
        '${messageStats != null ? ', messageStats: $messageStats' : ''}'
        '${startTime != null ? ', startTime: $startTime' : ''}'
        ')';
  }
}
