import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Типизированный Endpoint с поддержкой контрактов
base class TypedRpcEndpoint<T extends RpcSerializableMessage>
    extends RpcEndpoint {
  /// Зарегистрированные контракты сервисов
  final Map<String, RpcServiceContract<T>> _contracts = {};

  /// Зарегистрированные реализации методов
  final Map<String, Map<String, RpcMethodImplementation>> _implementations = {};

  /// Создает новый типизированный Endpoint
  TypedRpcEndpoint(super.transport, super.serializer);

  /// Регистрирует контракт сервиса
  void registerContract(RpcServiceContract<T> contract) {
    if (_contracts.containsKey(contract.serviceName)) {
      throw StateError(
          'Контракт для сервиса ${contract.serviceName} уже зарегистрирован');
    }
    _contracts[contract.serviceName] = contract;
    _implementations[contract.serviceName] = {};

    if (contract is DeclarativeRpcServiceContract<T>) {
      _registerDeclarativeContract(contract);
    }
  }

  void _registerDeclarativeContract(DeclarativeRpcServiceContract<T> contract) {
    contract.registerMethodsFromClass();

    for (final method in contract.methods) {
      final methodType = method.methodType;
      final methodName = method.methodName;
      final handler = contract.getHandler(method);
      final argumentParser = contract.getArgumentParser(method);
      final responseParser = contract.getResponseParser(method);

      if (methodType == RpcMethodType.unary) {
        registerUnaryMethod(
          contract.serviceName,
          methodName,
          handler,
          argumentParser,
          responseParser,
        );
      } else if (methodType == RpcMethodType.serverStreaming) {
        registerStreamMethod(
          contract.serviceName,
          methodName,
          handler,
          argumentParser,
          responseParser,
        );
      }
    }
  }

  /// Регистрирует типизированную реализацию унарного метода
  void registerUnaryMethod<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Future<Response> Function(Request) handler,
    Request Function(Map<String, dynamic>)? argumentParser,
    Response Function(Map<String, dynamic>)? responseParser,
  ) {
    final contract = _getMethodContract<Request, Response>(
      serviceName,
      methodName,
      RpcMethodType.unary,
    );

    final implementation = RpcMethodImplementation.unary(contract, handler);

    _implementations[serviceName]![methodName] = implementation;

    // Регистрируем обертку для стандартного endpoint
    super.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Если request - это Map и мы получили функцию fromJson, преобразуем объект
          final typedRequest = (context.payload is Map<String, dynamic> &&
                  argumentParser != null)
              ? argumentParser(context.payload)
              : context.payload;

          final response = await implementation.invoke(typedRequest);
          if (response is RpcMessage) {
            return response.toJson();
          }
          return response;
        } catch (e) {
          rethrow;
        }
      },
    );
  }

  /// Регистрирует типизированную реализацию стримингового метода
  void registerStreamMethod<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Stream<Response> Function(Request) handler,
    Request Function(Map<String, dynamic>)? argumentParser,
    Response Function(Map<String, dynamic>)? responseParser,
  ) {
    final contract = _getMethodContract<Request, Response>(
      serviceName,
      methodName,
      RpcMethodType.serverStreaming,
    );

    final implementation =
        RpcMethodImplementation.serverStream(contract, handler);

    _implementations[serviceName]![methodName] = implementation;

    // Регистрируем низкоуровневый обработчик
    super.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Конвертируем запрос в типизированный, если нужно
          final typedRequest = (context.payload is Map<String, dynamic> &&
                  argumentParser != null)
              ? argumentParser(context.payload)
              : context.payload;

          // Получаем ID сообщения из контекста
          final messageId = context.messageId;

          // Запускаем обработку стрима в фоновом режиме
          _activateStreamHandler(
              messageId, serviceName, methodName, typedRequest, implementation);

          // Возвращаем только подтверждение принятия запроса
          // Сами данные будут отправляться через streamData сообщения при активации потока
          return {'status': 'streaming'};
        } catch (e) {
          rethrow;
        }
      },
    );
  }

  /// Активирует обработчик стрима и связывает его с транспортом
  void _activateStreamHandler<Request, Response>(
      String messageId,
      String serviceName,
      String methodName,
      Request request,
      RpcMethodImplementation<Request, Response> implementation) {
    // Запускаем стрим от обработчика
    final stream = implementation.openStream(request);

    // Подписываемся на события и пересылаем их через публичный API Endpoint
    stream.listen((data) {
      // Отправляем данные в поток
      super.sendStreamData(
        messageId,
        data is RpcMessage ? data.toJson() : data,
      );
    }, onError: (error) {
      // Отправляем ошибку
      super.sendStreamError(
        messageId,
        error.toString(),
      );
    }, onDone: () {
      // Закрываем стрим
      super.closeStream(messageId);
    });
  }

  /// Вызывает типизированный метод и возвращает типизированный ответ
  Future<Response> invokeTyped<Request extends T, Response extends T>({
    required String serviceName,
    required String methodName,
    required Request request,
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) async {
    // Проверяем наличие контракта
    final contract = _getServiceContract(serviceName);
    final methodContract =
        contract.findMethodTyped<Request, Response>(methodName);

    if (methodContract == null) {
      throw ArgumentError(
          'Метод $methodName не найден в контракте сервиса $serviceName');
    }

    // Проверяем типы
    if (!methodContract.validateRequest(request)) {
      throw ArgumentError(
          'Тип запроса ${request.runtimeType} не соответствует контракту метода $methodName');
    }

    // Конвертируем запрос в JSON, если это Message
    final dynamicRequest = request is RpcMessage ? request.toJson() : request;

    // Вызываем метод через базовый Endpoint
    final response = await super.invoke(
      serviceName,
      methodName,
      dynamicRequest,
      timeout: timeout,
      metadata: metadata,
    );

    final typedResponse = contract.getResponseParser(methodContract)(response);

    if (!methodContract.validateResponse(typedResponse)) {
      throw ArgumentError(
          'Тип ответа ${response.runtimeType} не соответствует контракту метода $methodName');
    }

    return typedResponse;
  }

  /// Открывает типизированный поток данных
  Stream<Response> openTypedStream<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Request request, {
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Проверяем наличие контракта
    final contract = _getServiceContract(serviceName);
    final methodContract =
        contract.findMethodTyped<Request, Response>(methodName);

    if (methodContract == null) {
      throw ArgumentError(
          'Метод $methodName не найден в контракте сервиса $serviceName');
    }

    // Проверяем типы
    if (!methodContract.validateRequest(request)) {
      throw ArgumentError(
          'Тип запроса ${request.runtimeType} не соответствует контракту метода $methodName');
    }

    // Конвертируем запрос в JSON, если это Message
    final dynamicRequest = request is RpcMessage ? request.toJson() : request;

    // Открываем поток через базовый Endpoint
    final stream = super.openStream(
      serviceName,
      methodName,
      request: dynamicRequest,
      metadata: metadata,
      streamId: streamId,
    );

    // Оборачиваем поток для проверки типов
    return stream.map((data) {
      dynamic dynamicData = data;

      if (data is Map<String, dynamic>) {
        try {
          dynamicData = contract.getResponseParser(methodContract)(data);

          // Обязательно проверяем, что распарсенные данные соответствуют ожидаемому типу
          if (!methodContract.validateResponse(dynamicData)) {
            throw StateError(
                'Тип данных в потоке после парсинга не соответствует контракту метода $methodName');
          }
        } catch (e) {
          // В случае ошибки парсинга или валидации выбрасываем исключение
          throw StateError(
              'Ошибка при парсинге данных потока для метода $methodName: ${e.toString()}');
        }
      } else if (data is Response) {
        // Если данные уже имеют тип Response, проверяем их валидность
        if (!methodContract.validateResponse(data)) {
          throw StateError(
              'Тип данных в потоке ${data.runtimeType} не соответствует контракту метода $methodName');
        }
      } else {
        // Данные не являются ни Map<String, dynamic>, ни Response - это ошибка
        throw StateError(
            'Получены данные неожиданного типа ${data.runtimeType} в потоке для метода $methodName');
      }

      return dynamicData;
    });
  }

  // Вспомогательные методы

  /// Получает контракт сервиса
  RpcServiceContract<T> _getServiceContract(String serviceName) {
    final contract = _contracts[serviceName];
    if (contract == null) {
      throw ArgumentError(
          'Контракт для сервиса $serviceName не зарегистрирован');
    }
    return contract;
  }

  /// Получает типизированный контракт метода
  RpcMethodContract<Request, Response>
      _getMethodContract<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    RpcMethodType expectedType,
  ) {
    final contract = _getServiceContract(serviceName);
    final methodContract =
        contract.findMethodTyped<Request, Response>(methodName);

    if (methodContract == null) {
      throw ArgumentError(
          'Метод $methodName не найден в контракте сервиса $serviceName');
    }

    if (methodContract.methodType != expectedType) {
      throw ArgumentError(
          'Метод $methodName имеет тип ${methodContract.methodType}, но ожидался $expectedType');
    }

    return methodContract;
  }
}
