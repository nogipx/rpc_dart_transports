import 'package:rpc_dart/rpc_dart.dart';

import 'bidirectional.dart';
import 'bidirectional_models.dart';

/// Абстрактный контракт сервиса с двунаправленными методами
abstract base class DemoServiceContract extends RpcServiceContract {
  @override
  String get serviceName => 'DemoService';

  @override
  void setup() {
    // Регистрируем метод для простого двунаправленного стрима со строками
    addBidirectionalStreamingMethod<RpcString, RpcString>(
      methodName: simpleBidiMethod,
      handler: simpleBidirectionalHandler,
      argumentParser: RpcString.fromJson,
      responseParser: RpcString.fromJson,
    );

    // Регистрируем метод для комплексных данных
    addBidirectionalStreamingMethod<IRpcSerializableMessage, IRpcSerializableMessage>(
      methodName: complexBidiMethod,
      handler: complexBidirectionalHandler,
      argumentParser: parseComplexMessage,
      responseParser: parseComplexMessage,
    );
  }

  // Абстрактные методы, которые должны быть реализованы
  Stream<RpcString> simpleBidirectionalHandler(Stream<RpcString> requests, String messageId);
  Stream<IRpcSerializableMessage> complexBidirectionalHandler(
    Stream<IRpcSerializableMessage> requests,
    String messageId,
  );

  // Парсер для комплексных сообщений
  IRpcSerializableMessage parseComplexMessage(Map<String, dynamic> json) {
    // Определяем тип данных по структуре JSON
    if (json.containsKey('text') && json.containsKey('number') && json.containsKey('flag')) {
      return SimpleMessageData.fromJson(json);
    } else if (json.containsKey('config') && json.containsKey('items')) {
      return NestedData.fromJson(json);
    } else {
      return SimpleMessageData.fromJson(json);
    }
  }
}

/// Серверная реализация контракта
final class ServerDemoServiceContract extends DemoServiceContract {
  @override
  Stream<RpcString> simpleBidirectionalHandler(Stream<RpcString> requests, String messageId) {
    // Обрабатываем каждый входящий запрос и возвращаем ответ
    return requests.map((data) {
      print('Сервер получил: ${data.value}');
      return RpcString('Ответ: ${data.value}');
    });
  }

  @override
  Stream<IRpcSerializableMessage> complexBidirectionalHandler(
    Stream<IRpcSerializableMessage> requests,
    String messageId,
  ) {
    // Обрабатываем разные типы данных
    return requests.map((data) {
      if (data is SimpleMessageData) {
        return SimpleMessageData(
          text: '${data.text} (обработано)',
          number: data.number * 2,
          flag: !data.flag,
          timestamp: DateTime.now().toIso8601String(),
        );
      } else if (data is NestedData) {
        return NestedData(
          config: ConfigData(enabled: !data.config.enabled, timeout: data.config.timeout * 2),
          items: data.items,
          timestamp: DateTime.now().toIso8601String(),
        );
      } else {
        // Возвращаем пустой ответ для неизвестных типов
        return SimpleMessageData(
          text: 'Неизвестный тип данных',
          number: 0,
          flag: false,
          timestamp: DateTime.now().toIso8601String(),
        );
      }
    });
  }
}

/// Клиентская реализация контракта
final class ClientDemoServiceContract extends DemoServiceContract {
  final RpcEndpoint _endpoint;

  ClientDemoServiceContract(this._endpoint);

  @override
  Stream<RpcString> simpleBidirectionalHandler(Stream<RpcString> requests, String messageId) {
    // Клиент просто передает сообщения без обработки
    return requests;
  }

  @override
  Stream<IRpcSerializableMessage> complexBidirectionalHandler(
    Stream<IRpcSerializableMessage> requests,
    String messageId,
  ) {
    // Клиент просто передает сообщения без обработки
    return requests;
  }

  /// Открывает двунаправленный канал для простых сообщений
  Future<BidirectionalChannel<RpcString, RpcString>> simpleBidirectional() async {
    final channel = _endpoint
        .bidirectional(serviceName, simpleBidiMethod)
        .createChannel<RpcString, RpcString>(responseParser: RpcString.fromJson);
    return channel;
  }

  /// Открывает двунаправленный канал для комплексных данных
  Future<BidirectionalChannel<IRpcSerializableMessage, IRpcSerializableMessage>>
  complexBidirectional() async {
    final channel = _endpoint
        .bidirectional(serviceName, complexBidiMethod)
        .createChannel<IRpcSerializableMessage, IRpcSerializableMessage>(
          responseParser: parseComplexMessage,
        );
    return channel;
  }
}
