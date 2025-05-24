import 'package:rpc_example/generated/weather_service.pb.dart';
import 'package:rpc_example/weather_contract.dart';

void main() {
  print('==== Тест сериализации/десериализации Protobuf ====');
  testProtobufSerialization();
  testWrapperSerialization();
}

void testProtobufSerialization() {
  print('\n1. Тестируем нативную сериализацию/десериализацию Protobuf');

  // Создаем объект запроса погоды
  final weatherRequest = WeatherRequest()..city = 'Москва';

  // Сериализуем в бинарный формат
  final bytes = weatherRequest.writeToBuffer();
  print('Сериализованный запрос: ${bytes.length} байт');

  // Десериализуем обратно
  final weatherRequestRestored = WeatherRequest.fromBuffer(bytes);
  print('Десериализованный город: ${weatherRequestRestored.city}');

  // Проверяем, что данные сохранились
  final isRequestEqual = weatherRequest.city == weatherRequestRestored.city;
  print('Данные сохранились корректно: $isRequestEqual');

  // Создаем объект ответа
  final weatherResponse = WeatherResponse()
    ..city = 'Москва'
    ..temperature = 25.5
    ..condition = 'Солнечно'
    ..humidity = 60.0
    ..windSpeed = 5.0;

  // Сериализуем в бинарный формат
  final responseBytes = weatherResponse.writeToBuffer();
  print('Сериализованный ответ: ${responseBytes.length} байт');

  // Десериализуем обратно
  final weatherResponseRestored = WeatherResponse.fromBuffer(responseBytes);
  print('Десериализованные данные:');
  print('  Город: ${weatherResponseRestored.city}');
  print('  Температура: ${weatherResponseRestored.temperature}');
  print('  Условия: ${weatherResponseRestored.condition}');

  // Проверяем, что данные сохранились
  final isResponseEqual = weatherResponse.city == weatherResponseRestored.city &&
      weatherResponse.temperature == weatherResponseRestored.temperature &&
      weatherResponse.condition == weatherResponseRestored.condition;
  print('Данные сохранились корректно: $isResponseEqual');
}

void testWrapperSerialization() {
  print('\n2. Тестируем сериализацию/десериализацию обертки (wrapper)');

  // Создаем Protobuf-объект
  final weatherResponse = WeatherResponse()
    ..city = 'Москва'
    ..temperature = 25.5
    ..condition = 'Солнечно'
    ..humidity = 60.0
    ..windSpeed = 5.0;

  // Оборачиваем в wrapper
  final wrapper = WeatherResponseWrapper(weatherResponse);

  // Сериализуем с помощью метода serialize() из интерфейса IRpcSerializable
  final serialized = wrapper.serialize();
  print('Размер сериализованного wrapper: ${serialized.length} байт');

  // Десериализуем с помощью статического метода fromBuffer
  final restoredWrapper = WeatherResponseWrapper.fromBuffer(serialized);

  // Получаем Protobuf-объект из wrapper
  final restoredResponse = restoredWrapper.proto;

  // Проверяем, что данные сохранились
  print('Десериализованные данные из wrapper:');
  print('  Город: ${restoredResponse.city}');
  print('  Температура: ${restoredResponse.temperature}');
  print('  Условия: ${restoredResponse.condition}');

  final isWrapperEqual = weatherResponse.city == restoredResponse.city &&
      weatherResponse.temperature == restoredResponse.temperature &&
      weatherResponse.condition == restoredResponse.condition;
  print('Данные в wrapper сохранились корректно: $isWrapperEqual');

  // Проверяем, что формат сериализации указан правильно
  print('Формат сериализации wrapper: ${wrapper.getFormat().name}');
}
