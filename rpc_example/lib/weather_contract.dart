import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:protobuf/protobuf.dart';
import 'generated/weather_service.pb.dart';

// Расширения для поддержки протобафа
extension ProtobufExtension on GeneratedMessage {
  Uint8List toBuffer() => writeToBuffer();
}

// Миксин для поддержки Protobuf сериализации
mixin ProtobufMessage implements IRpcSerializable {
  Uint8List toBuffer();

  @override
  Uint8List serialize() => toBuffer();

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;
}

// Расширяем классы Protobuf для поддержки RPC
extension WeatherRequestExt on WeatherRequest {
  WeatherRequestWrapper toWrapper() => WeatherRequestWrapper(this);
}

extension ForecastRequestExt on ForecastRequest {
  ForecastRequestWrapper toWrapper() => ForecastRequestWrapper(this);
}

// Обертки для Protobuf классов
class WeatherRequestWrapper with ProtobufMessage {
  final WeatherRequest _proto;

  WeatherRequestWrapper(this._proto);

  @override
  Uint8List toBuffer() => _proto.writeToBuffer();

  WeatherRequest get proto => _proto;
}

class WeatherResponseWrapper with ProtobufMessage {
  final WeatherResponse _proto;

  WeatherResponseWrapper(this._proto);

  @override
  Uint8List toBuffer() => _proto.writeToBuffer();

  WeatherResponse get proto => _proto;

  static WeatherResponseWrapper fromBuffer(Uint8List buffer) {
    try {
      return WeatherResponseWrapper(WeatherResponse.fromBuffer(buffer));
    } catch (e, stackTrace) {
      print('ERROR: Не удалось десериализовать WeatherResponse: $e');
      print('Buffer: ${buffer.length} bytes');
      print('Trace: $stackTrace');
      rethrow;
    }
  }
}

class ForecastRequestWrapper with ProtobufMessage {
  final ForecastRequest _proto;

  ForecastRequestWrapper(this._proto);

  @override
  Uint8List toBuffer() => _proto.writeToBuffer();

  ForecastRequest get proto => _proto;
}

class ForecastResponseWrapper with ProtobufMessage {
  final ForecastResponse _proto;

  ForecastResponseWrapper(this._proto);

  @override
  Uint8List toBuffer() => _proto.writeToBuffer();

  ForecastResponse get proto => _proto;

  static ForecastResponseWrapper fromBuffer(Uint8List buffer) {
    try {
      return ForecastResponseWrapper(ForecastResponse.fromBuffer(buffer));
    } catch (e, stackTrace) {
      print('ERROR: Не удалось десериализовать ForecastResponse: $e');
      print('Buffer: ${buffer.length} bytes');
      print('Trace: $stackTrace');
      rethrow;
    }
  }
}

class WeatherUpdateWrapper with ProtobufMessage {
  final WeatherUpdate _proto;

  WeatherUpdateWrapper(this._proto);

  @override
  Uint8List toBuffer() => _proto.writeToBuffer();

  WeatherUpdate get proto => _proto;

  static WeatherUpdateWrapper fromBuffer(Uint8List buffer) {
    try {
      return WeatherUpdateWrapper(WeatherUpdate.fromBuffer(buffer));
    } catch (e, stackTrace) {
      print('ERROR: Не удалось десериализовать WeatherUpdate: $e');
      print('Buffer: ${buffer.length} bytes');
      print('Trace: $stackTrace');
      rethrow;
    }
  }
}

// Общий интерфейс для клиента и сервера
abstract interface class IWeatherContract implements IRpcContract {
  // Имена методов
  static const methodGetCurrentWeather = 'getCurrentWeather';
  static const methodGetForecast = 'getForecast';
  static const methodSubscribeToUpdates = 'subscribeToUpdates';

  // Общее имя сервиса
  static const serviceNameValue = 'WeatherService';
}

// Контракт для сервера
abstract class WeatherServerContract extends RpcResponderContract implements IWeatherContract {
  WeatherServerContract() : super(IWeatherContract.serviceNameValue);

  @override
  void setup() {
    // Унарный метод: получить текущую погоду
    addUnaryMethod<WeatherRequestWrapper, WeatherResponseWrapper>(
      methodName: IWeatherContract.methodGetCurrentWeather,
      handler: getCurrentWeather,
      description: 'Получить текущую погоду по городу',
      serializationFormat: RpcSerializationFormat.binary,
    );

    // Унарный метод: получить прогноз на несколько дней
    addUnaryMethod<ForecastRequestWrapper, ForecastResponseWrapper>(
      methodName: IWeatherContract.methodGetForecast,
      handler: getForecast,
      description: 'Получить прогноз погоды на несколько дней',
      serializationFormat: RpcSerializationFormat.binary,
    );

    // Серверный стрим: подписка на обновления погоды
    addServerStreamMethod<WeatherRequestWrapper, WeatherUpdateWrapper>(
      methodName: IWeatherContract.methodSubscribeToUpdates,
      handler: subscribeToUpdates,
      description: 'Подписаться на обновления погоды в реальном времени',
      serializationFormat: RpcSerializationFormat.binary,
    );

    super.setup();
  }

  // Методы, которые должны быть реализованы наследниками
  Future<WeatherResponseWrapper> getCurrentWeather(WeatherRequestWrapper request);
  Future<ForecastResponseWrapper> getForecast(ForecastRequestWrapper request);
  Stream<WeatherUpdateWrapper> subscribeToUpdates(WeatherRequestWrapper request);
}

// Контракт для клиента
abstract class WeatherClientContract extends RpcCallerContract implements IWeatherContract {
  WeatherClientContract(RpcCallerEndpoint endpoint)
      : super(IWeatherContract.serviceNameValue, endpoint);

  Future<WeatherResponse> getCurrentWeather(WeatherRequest request);
  Future<ForecastResponse> getForecast(ForecastRequest request);
  Stream<WeatherUpdate> subscribeToUpdates(WeatherRequest request);
}
