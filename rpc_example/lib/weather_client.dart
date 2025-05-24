import 'dart:async';

import 'generated/weather_service.pb.dart';
import 'weather_contract.dart';

class WeatherClient extends WeatherClientContract {
  WeatherClient(super.endpoint);

  @override
  Future<WeatherResponse> getCurrentWeather(WeatherRequest request) async {
    print('CLIENT: Отправка запроса getCurrentWeather для города: ${request.city}');
    final wrapped = WeatherRequestWrapper(request);
    print('CLIENT: Размер запроса: ${wrapped.serialize().length} байт');

    try {
      final response = await endpoint
          .unaryRequest(
            serviceName: serviceName,
            methodName: IWeatherContract.methodGetCurrentWeather,
          )
          .callBinary<WeatherRequestWrapper, WeatherResponseWrapper>(
            request: wrapped,
            responseParser: WeatherResponseWrapper.fromBuffer,
          );

      print('CLIENT: Получен ответ с температурой: ${response.proto.temperature}');
      return response.proto;
    } catch (e, stackTrace) {
      print('CLIENT ERROR: Ошибка при получении ответа: $e');
      print('CLIENT TRACE: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<ForecastResponse> getForecast(ForecastRequest request) async {
    final wrapped = ForecastRequestWrapper(request);

    final response = await endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: IWeatherContract.methodGetForecast,
        )
        .callBinary<ForecastRequestWrapper, ForecastResponseWrapper>(
          request: wrapped,
          responseParser: ForecastResponseWrapper.fromBuffer,
        );

    return response.proto;
  }

  @override
  Stream<WeatherUpdate> subscribeToUpdates(WeatherRequest request) {
    final wrapped = WeatherRequestWrapper(request);

    return endpoint
        .serverStream(
          serviceName: serviceName,
          methodName: IWeatherContract.methodSubscribeToUpdates,
        )
        .callBinary<WeatherRequestWrapper, WeatherUpdateWrapper>(
          request: wrapped,
          responseParser: WeatherUpdateWrapper.fromBuffer,
        )
        .map((wrapper) => wrapper.proto);
  }
}
