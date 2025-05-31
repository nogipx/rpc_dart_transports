// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Боевой пример роутера с исправлениями:
///
/// ✅ Автоматический мониторинг клиентов (каждые 30с)
/// ✅ Heartbeat проверки (таймаут 2 минуты)
/// ✅ Поддержка множественных подключений
/// ✅ Корректная обработка P2P соединений
/// ✅ Нет dummy контроллеров
Future<void> main() async {
  print('🚀 Демо боевого роутера для мобильных клиентов\n');

  // === СЕРВЕР ===

  // Создаем роутер с настроенным мониторингом
  final routerContract = RouterResponderContract();

  print('✅ Роутер создан с мониторингом:');
  print('   - Проверка клиентов: каждые 30 секунд');
  print('   - Таймаут неактивности: 2 минуты');
  print('   - Автоматическое удаление мертвых соединений\n');

  // === КЛИЕНТЫ ===

  // Эмуляция 2 клиентов для тестирования

  print('👤 Эмуляция клиента #1 (мобильный)...');
  await testClientRegistration('mobile-user-1', ['mobile', 'chat'], routerContract);

  await Future.delayed(Duration(seconds: 2));

  print('\n👤 Эмуляция клиента #2 (десктоп)...');
  await testClientRegistration('desktop-user-1', ['desktop', 'chat'], routerContract);

  await Future.delayed(Duration(seconds: 3));

  print('\n📊 Статистика роутера:');
  final stats = routerContract.routerImpl.stats;
  print('   - Активных клиентов: ${stats.activeClients}');
  print('   - Всего сообщений: ${stats.totalMessages}');
  print('   - Ошибок: ${stats.errorCount}');
  print('   - Время работы: ${DateTime.now().difference(stats.startTime!).inSeconds}с');

  print('\n⏳ Ждем 5 минут для демонстрации очистки неактивных клиентов...');
  print('   (В реальности достаточно 2 минут неактивности)');

  // Эмуляция длительного ожидания
  for (int i = 1; i <= 5; i++) {
    await Future.delayed(Duration(minutes: 1));
    final currentStats = routerContract.routerImpl.stats;
    print('   ⏰ $i мин: активных клиентов ${currentStats.activeClients}');
  }

  // Финальная статистика
  final finalStats = routerContract.routerImpl.stats;
  print('\n📊 Финальная статистика:');
  print('   - Активных клиентов: ${finalStats.activeClients}');
  print('   - Всего сообщений: ${finalStats.totalMessages}');
  print('   - Ошибок: ${finalStats.errorCount}');

  // Закрытие
  await routerContract.dispose();
  print('\n✅ Роутер закрыт. Демо завершено.');
}

/// Тестирует регистрацию клиента и его поведение
Future<void> testClientRegistration(
  String clientName,
  List<String> groups,
  RouterResponderContract router,
) async {
  // Создаем временный стрим для эмуляции клиента
  final clientStreamController = StreamController<RouterMessage>();

  try {
    // Регистрируем клиента
    final success = await router.routerImpl.registerClient(
      router.routerImpl.generateClientId(),
      clientStreamController,
      clientName: clientName,
      groups: groups,
      metadata: {
        'platform': groups.contains('mobile') ? 'mobile' : 'desktop',
        'version': '1.0.0',
        'userAgent': 'TestClient/1.0',
      },
    );

    if (success) {
      print('   ✅ Клиент $clientName зарегистрирован');

      // Получаем информацию о клиенте
      final clients = router.routerImpl.getActiveClients();
      final ourClient = clients.lastWhere((c) => c.clientName == clientName);

      print('   📱 ID: ${ourClient.clientId}');
      print('   👥 Группы: ${ourClient.groups.join(', ')}');
      print('   🕐 Подключен: ${ourClient.connectedAt}');

      // Эмуляция heartbeat'а
      router.routerImpl.updateClientActivity(ourClient.clientId);
      print('   💓 Heartbeat отправлен');
    } else {
      print('   ❌ Ошибка регистрации клиента $clientName');
    }
  } catch (e) {
    print('   ❌ Исключение при регистрации: $e');
  } finally {
    // Закрываем стрим через некоторое время (эмуляция отключения)
    Timer(Duration(minutes: 3), () {
      clientStreamController.close();
    });
  }
}
