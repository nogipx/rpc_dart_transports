part of '_index.dart';

/// Запускает пример использования унарного RPC вызова
Future<void> runUnaryExample() async {
  await UnaryRpcExample.run();
}

/// Пример использования унарного RPC вызова с мультиплексированием по Stream ID.
///
/// Демонстрирует простой запрос-ответ с использованием UnaryClient и UnaryServer
/// в новой архитектуре с поддержкой мультиплексирования по уникальным Stream ID
/// согласно спецификации gRPC.
class UnaryRpcExample {
  /// Запускает демонстрацию унарного RPC вызова.
  ///
  /// Создает клиент и сервер с мультиплексированием и выполняет
  /// несколько унарных вызовов разных типов через один транспорт.
  /// Каждый вызов получает уникальный Stream ID.
  static Future<void> run() async {
    print(
        '\n=== Запуск примера унарного RPC с мультиплексированием по Stream ID ===\n');

    // Включаем отладочные логи для диагностики
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

    // Создаем одну пару соединенных транспортов для всех методов
    final (clientTransport, serverTransport) = RpcInMemoryTransport.pair(
      clientLogger: RpcLogger(
        "ClientTransport",
        colors: RpcLoggerColors.singleColor(AnsiColor.brightBlue),
      ),
      serverLogger: RpcLogger(
        "ServerTransport",
        colors: RpcLoggerColors.singleColor(AnsiColor.brightYellow),
      ),
    );

    // Создаем сериализатор для строк
    final stringSerializer = SimpleStringSerializer();

    // Определяем различные сервисы и методы для демонстрации мультиплексирования
    final services = [
      ('GreetingService', 'SayHello'),
      ('TimeService', 'GetCurrentTime'),
      ('StatusService', 'CheckHealth'),
      ('ErrorService', 'ThrowError'),
      ('EchoService', 'Echo'),
    ];

    // Создаем серверы для каждого метода - каждый обрабатывает свой путь
    final servers = <UnaryResponder>[];

    for (final (serviceName, methodName) in services) {
      final server = UnaryResponder<String, String>(
        transport: serverTransport,
        serviceName: serviceName,
        methodName: methodName,
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
        handler: (request) {
          print(
              'СЕРВЕР [$serviceName/$methodName]: Получен запрос: "$request"');

          // Обрабатываем разные запросы в зависимости от сервиса
          switch (serviceName) {
            case 'GreetingService':
              return 'Здравствуйте! Это ответ от $serviceName';
            case 'TimeService':
              return 'Текущее время: ${DateTime.now()}';
            case 'StatusService':
              return 'Все системы работают нормально в $serviceName';
            case 'ErrorService':
              throw Exception('Тестовая ошибка от $serviceName');
            case 'EchoService':
            default:
              return 'Эхо от $serviceName: $request';
          }
        },
        logger: RpcLogger(
          "$serviceName/$methodName-Server",
          colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
        ),
      );
      servers.add(server);
    }

    try {
      // Пример 1: Простой вызов приветствия
      print('КЛИЕНТ: Выполняем запрос к GreetingService/SayHello');
      final client1 = UnaryCaller<String, String>(
        transport: clientTransport,
        serviceName: 'GreetingService',
        methodName: 'SayHello',
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
        logger: RpcLogger(
          "GreetingClient",
          colors: RpcLoggerColors.singleColor(AnsiColor.brightMagenta),
        ),
      );
      final response1 = await client1.call('Привет');
      print('КЛИЕНТ: Получен ответ: "$response1"');
      await client1.close(); // Теперь не закрывает транспорт

      // Пример 2: Запрос времени
      print('\nКЛИЕНТ: Выполняем запрос к TimeService/GetCurrentTime');
      final client2 = UnaryCaller<String, String>(
        transport: clientTransport,
        serviceName: 'TimeService',
        methodName: 'GetCurrentTime',
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
        logger: RpcLogger(
          "TimeClient",
          colors: RpcLoggerColors.singleColor(AnsiColor.brightCyan),
        ),
      );
      final response2 = await client2.call('Время');
      print('КЛИЕНТ: Получен ответ: "$response2"');
      await client2.close();

      // Пример 3: Запрос с таймаутом
      print(
          '\nКЛИЕНТ: Выполняем запрос к StatusService/CheckHealth с таймаутом 500мс');
      final client3 = UnaryCaller<String, String>(
        transport: clientTransport,
        serviceName: 'StatusService',
        methodName: 'CheckHealth',
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
        logger: RpcLogger(
          "StatusClient",
          colors: RpcLoggerColors.singleColor(AnsiColor.brightWhite),
        ),
      );
      final response3 = await client3.call(
        'Статус',
        timeout: Duration(milliseconds: 500),
      );
      print('КЛИЕНТ: Получен ответ: "$response3"');
      await client3.close();

      // Пример 4: Вызов с ошибкой
      print(
          '\nКЛИЕНТ: Выполняем запрос к ErrorService/ThrowError (должен вернуть ошибку)');
      final client4 = UnaryCaller<String, String>(
        transport: clientTransport,
        serviceName: 'ErrorService',
        methodName: 'ThrowError',
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
        logger: RpcLogger(
          "ErrorClient",
          colors: RpcLoggerColors.singleColor(AnsiColor.brightRed),
        ),
      );
      try {
        await client4.call('Ошибка');
      } catch (e) {
        print('КЛИЕНТ: Получена ожидаемая ошибка: $e');
      }
      await client4.close();

      // Пример 5: Эхо-запрос с очень коротким таймаутом
      print(
          '\nКЛИЕНТ: Выполняем запрос к EchoService/Echo с очень коротким таймаутом (10мс)');
      final client5 = UnaryCaller<String, String>(
        transport: clientTransport,
        serviceName: 'EchoService',
        methodName: 'Echo',
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
        logger: RpcLogger(
          "EchoClient",
          colors: RpcLoggerColors.singleColor(AnsiColor.brightBlack),
        ),
      );
      try {
        await client5.call(
          'Эхо тест с таймаутом',
          timeout: Duration(milliseconds: 10),
        );
      } catch (e) {
        print('КЛИЕНТ: Получена ошибка таймаута: $e');
      }
      await client5.close();

      // Демонстрация параллельных запросов к разным сервисам
      print(
          '\nКЛИЕНТ: Демонстрация параллельных запросов с уникальными Stream ID');

      final parallelRequests = [
        ('GreetingService', 'SayHello', 'Параллельный привет'),
        ('TimeService', 'GetCurrentTime', 'Параллельное время'),
        ('EchoService', 'Echo', 'Параллельное эхо'),
      ];

      final futures = <Future<void>>[];

      for (final (serviceName, methodName, request) in parallelRequests) {
        final future = () async {
          final client = UnaryCaller<String, String>(
            transport: clientTransport,
            serviceName: serviceName,
            methodName: methodName,
            requestSerializer: stringSerializer,
            responseSerializer: stringSerializer,
            logger: RpcLogger(
              "$serviceName-ParallelClient",
              colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
            ),
          );

          try {
            print(
                'КЛИЕНТ: Параллельный запрос к $serviceName/$methodName: "$request"');
            final response =
                await client.call(request, timeout: Duration(seconds: 2));
            print(
                'КЛИЕНТ: Параллельный ответ от $serviceName/$methodName: "$response"');
          } catch (e) {
            print(
                'КЛИЕНТ: Параллельная ошибка от $serviceName/$methodName: $e');
          } finally {
            await client.close();
          }
        }();

        futures.add(future);
      }

      // Ждем завершения всех параллельных запросов
      await Future.wait(futures);
    } finally {
      // Закрываем все серверы (они тоже не закрывают транспорт)
      for (final server in servers) {
        await server.close();
      }

      // Закрываем основные транспорты в самом конце
      await clientTransport.close();
      await serverTransport.close();
    }

    print(
        '\n=== Пример унарного RPC с мультиплексированием по Stream ID завершен ===\n');
  }
}
