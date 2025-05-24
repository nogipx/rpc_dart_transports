import 'dart:async';
import 'dart:math';

import 'generated/weather_service.pb.dart';
import 'weather_contract.dart';

class WeatherServer extends WeatherServerContract {
  final Random _random = Random();
  final Map<String, StreamController<WeatherUpdateWrapper>> _cityUpdates = {};

  @override
  String get serviceName => 'WeatherService';

  @override
  Future<WeatherResponseWrapper> getCurrentWeather(WeatherRequestWrapper request) async {
    print('SERVER: Получен запрос getCurrentWeather для города: ${request.proto.city}');

    try {
      // Симулируем небольшую задержку
      await Future.delayed(Duration(milliseconds: 200));

      // В реальном приложении здесь был бы запрос к API погоды
      final proto = WeatherResponse()
        ..city = request.proto.city
        ..temperature = 15 + _random.nextDouble() * 15
        ..condition = _getRandomCondition()
        ..humidity = 40 + _random.nextDouble() * 40
        ..windSpeed = 2 + _random.nextDouble() * 8;

      print('SERVER: Сформирован ответ с температурой: ${proto.temperature}');
      final response = WeatherResponseWrapper(proto);
      print('SERVER: Размер сериализованного ответа: ${response.serialize().length} байт');
      return response;
    } catch (e, stackTrace) {
      print('SERVER ERROR: Ошибка при обработке запроса getCurrentWeather: $e');
      print('SERVER TRACE: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<ForecastResponseWrapper> getForecast(ForecastRequestWrapper request) async {
    // Симулируем задержку
    await Future.delayed(Duration(milliseconds: 300));

    final proto = ForecastResponse()..city = request.proto.city;

    // Генерируем прогноз на запрошенное количество дней
    final now = DateTime.now();
    for (int i = 0; i < request.proto.days; i++) {
      final date = now.add(Duration(days: i));
      final forecast = DailyForecast()
        ..date = date.toIso8601String().split('T').first
        ..temperatureMin = 10 + _random.nextDouble() * 10
        ..temperatureMax = 20 + _random.nextDouble() * 10
        ..condition = _getRandomCondition();

      proto.forecast.add(forecast);
    }

    return ForecastResponseWrapper(proto);
  }

  @override
  Stream<WeatherUpdateWrapper> subscribeToUpdates(WeatherRequestWrapper request) {
    final city = request.proto.city;

    // Создаем контроллер для города, если его еще нет
    _cityUpdates[city] ??= StreamController<WeatherUpdateWrapper>.broadcast();

    // Запускаем симуляцию обновлений погоды
    _simulateWeatherUpdates(city);

    return _cityUpdates[city]!.stream;
  }

  void _simulateWeatherUpdates(String city) {
    // Проверяем, что контроллер существует и не закрыт
    if (!_cityUpdates.containsKey(city) || _cityUpdates[city]!.isClosed) {
      return;
    }

    // Отправляем обновление
    final proto = WeatherUpdate()
      ..city = city
      ..temperature = 15 + _random.nextDouble() * 15
      ..condition = _getRandomCondition();

    _cityUpdates[city]!.add(WeatherUpdateWrapper(proto));

    // Планируем следующее обновление
    Future.delayed(Duration(seconds: 2)).then((_) {
      _simulateWeatherUpdates(city);
    });
  }

  String _getRandomCondition() {
    final conditions = ['Солнечно', 'Облачно', 'Дождь', 'Снег', 'Туман', 'Ветрено'];
    return conditions[_random.nextInt(conditions.length)];
  }
}
