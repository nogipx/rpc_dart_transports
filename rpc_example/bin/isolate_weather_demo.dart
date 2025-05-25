import 'dart:async';

import 'package:rpc_dart/src/_index.dart';
import 'package:rpc_example/generated/weather_service.pb.dart';
import 'package:rpc_example/weather_client.dart';
import 'package:rpc_example/weather_server.dart';

void serverIsolateEntrypoint(IRpcTransport transport, Map<String, dynamic> customParams) {
  print('ISOLATE: Запуск серверного изолята');
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем серверный эндпоинт
  final serverEndpoint = RpcResponderEndpoint(transport: transport);

  // Создаем и регистрируем сервер погоды
  final server = WeatherServer();
  serverEndpoint.registerServiceContract(server);

  // Явно запускаем прослушивание (хотя это должно происходить автоматически при регистрации)
  serverEndpoint.start();

  print('ISOLATE: Сервер погоды запущен и зарегистрирован');
}

Future<void> main() async {
  print('===== Запуск демонстрации WeatherService с изолятами =====');

  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем транспорт на изолятах
  print('Запуск изолята с сервером...');
  final result = await RpcIsolateTransport.spawn(
    entrypoint: serverIsolateEntrypoint,
    customParams: {},
    debugName: 'weather-server-isolate',
  );

  final hostTransport = result.transport;
  final killIsolate = result.kill;

  try {
    // Создаем клиентский эндпоинт
    final clientEndpoint = RpcCallerEndpoint(transport: hostTransport);
    print('Клиентский эндпоинт создан');

    // Создаем клиента
    final client = WeatherClient(clientEndpoint);
    print('Клиент погоды создан');

    // 1. Получаем текущую погоду
    print('\n--- Получение текущей погоды ---');
    final weatherRequest = WeatherRequest()..city = 'Москва';

    try {
      print('Отправка запроса getCurrentWeather...');
      final weatherResponse = await client.getCurrentWeather(weatherRequest);
      print('Погода в ${weatherResponse.city}:');
      print('  Температура: ${weatherResponse.temperature.toStringAsFixed(1)}°C');
      print('  Условия: ${weatherResponse.condition}');
      print('  Влажность: ${weatherResponse.humidity.toStringAsFixed(1)}%');
      print('  Скорость ветра: ${weatherResponse.windSpeed.toStringAsFixed(1)} м/с');
    } catch (e, stackTrace) {
      print('ОШИБКА при получении текущей погоды: $e');
      print('Stack trace: $stackTrace');
    }

    // 2. Получаем прогноз на 3 дня
    print('\n--- Получение прогноза на 3 дня ---');
    final forecastRequest = ForecastRequest()
      ..city = 'Санкт-Петербург'
      ..days = 3;

    try {
      print('Отправка запроса getForecast...');
      final forecastResponse = await client.getForecast(forecastRequest);
      print('Прогноз для ${forecastResponse.city}:');
      for (final day in forecastResponse.forecast) {
        print(
          '  ${day.date}: ${day.temperatureMin.toStringAsFixed(1)}°C - ${day.temperatureMax.toStringAsFixed(1)}°C, ${day.condition}',
        );
      }
    } catch (e, stackTrace) {
      print('ОШИБКА при получении прогноза: $e');
      print('Stack trace: $stackTrace');
    }

    // 3. Подписываемся на обновления
    print('\n--- Подписка на обновления погоды ---');
    final streamRequest = WeatherRequest()..city = 'Новосибирск';

    StreamSubscription<WeatherUpdate>? subscription;
    try {
      print('Отправка запроса subscribeToUpdates...');
      subscription = client.subscribeToUpdates(streamRequest).listen(
        (update) {
          print(
            'Обновление для ${update.city}: ${update.temperature.toStringAsFixed(1)}°C, ${update.condition}',
          );
        },
        onError: (e, stackTrace) {
          print('Ошибка потока: $e');
          print('Stack trace: $stackTrace');
        },
        onDone: () => print('Поток обновлений завершен'),
      );

      // Слушаем обновления 10 секунд
      print('Ожидание обновлений в течение 10 секунд...');
      await Future.delayed(Duration(seconds: 10));
      await subscription.cancel();
      print('Подписка отменена');
    } catch (e, stackTrace) {
      print('ОШИБКА при подписке на обновления: $e');
      print('Stack trace: $stackTrace');
      await subscription?.cancel();
    } finally {
      // Закрываем клиентский эндпоинт
      await clientEndpoint.close();
    }
  } finally {
    // Убиваем изолят
    print('Завершение изолята...');
    killIsolate();
    print('\n===== Демонстрация WeatherService завершена =====');
  }
}
