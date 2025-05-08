part of '_index.dart';

/// Типизированный Endpoint с поддержкой контрактов
class RpcEndpoint<T extends RpcSerializableMessage> implements _RpcEndpoint {
  /// Делегат для базовой функциональности
  final _RpcEndpointBase _delegate;

  /// Зарегистрированные контракты сервисов
  final Map<String, RpcServiceContract<T>> _contracts = {};

  /// Зарегистрированные реализации методов
  final Map<String, Map<String, RpcMethodImplementation>> _implementations = {};

  /// Создает новый типизированный Endpoint
  RpcEndpoint(RpcTransport transport, RpcSerializer serializer)
      : _delegate = _RpcEndpointBase(transport, serializer);

  @override
  RpcTransport get transport => _delegate.transport;

  @override
  RpcSerializer get serializer => _delegate.serializer;

  @override
  void addMiddleware(RpcMiddleware middleware) =>
      _delegate.addMiddleware(middleware);

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<void> closeStream(
    String streamId, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _delegate.closeStream(
        streamId,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<dynamic> invoke(
    String serviceName,
    String methodName,
    dynamic request, {
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) =>
      _delegate.invoke(
        serviceName,
        methodName,
        request,
        timeout: timeout,
        metadata: metadata,
      );

  @override
  bool get isActive => _delegate.isActive;

  @override
  Stream<dynamic> openStream(
    String serviceName,
    String methodName, {
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) =>
      _delegate.openStream(
        serviceName,
        methodName,
        request: request,
        metadata: metadata,
        streamId: streamId,
      );

  @override
  void registerMethod(
    String serviceName,
    String methodName,
    Future<dynamic> Function(RpcMethodContext) handler,
  ) =>
      _delegate.registerMethod(serviceName, methodName, handler);

  @override
  Future<void> sendStreamData(
    String streamId,
    dynamic data, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _delegate.sendStreamData(
        streamId,
        data,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<void> sendStreamError(
    String streamId,
    String error, {
    Map<String, dynamic>? metadata,
  }) =>
      _delegate.sendStreamError(streamId, error, metadata: metadata);

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
    _delegate.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Если request - это Map и мы получили функцию fromJson, преобразуем объект
          final typedRequest = (context.payload is Map<String, dynamic> &&
                  argumentParser != null)
              ? argumentParser(context.payload)
              : context.payload;

          // Получаем типизированный ответ от обработчика
          final response = await implementation.invoke(typedRequest);

          // Преобразуем ответ в формат для передачи (JSON для RpcMessage)
          final result = response is RpcMessage ? response.toJson() : response;

          return result;
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
    _delegate.registerMethod(
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
            messageId,
            serviceName,
            methodName,
            typedRequest,
            implementation,
            responseParser,
          );

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
      RpcMethodImplementation<Request, Response> implementation,
      [Response Function(Map<String, dynamic>)? responseParser]) {
    // Запускаем стрим от обработчика
    final stream = implementation.openStream(request);

    // Подписываемся на события и пересылаем их через публичный API Endpoint
    stream.listen((data) {
      // Преобразуем данные и отправляем их в поток
      // Важно отправлять с указанием serviceName и methodName для middleware
      final processedData = data is RpcMessage ? data.toJson() : data;

      _delegate.sendStreamData(
        messageId,
        processedData,
        serviceName: serviceName,
        methodName: methodName,
      );
    }, onError: (error) {
      // Отправляем ошибку
      _delegate.sendStreamError(
        messageId,
        error.toString(),
      );
    }, onDone: () {
      // Закрываем стрим с указанием serviceName и methodName для middleware
      _delegate.closeStream(
        messageId,
        serviceName: serviceName,
        methodName: methodName,
      );
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

    // Вызываем метод через базовый Endpoint (с поддержкой middleware)
    final response = await _delegate.invoke(
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

    // Открываем поток через базовый Endpoint (с поддержкой middleware)
    final stream = _delegate.openStream(
      serviceName,
      methodName,
      request: dynamicRequest,
      metadata: metadata,
      streamId: streamId,
    );

    // Оборачиваем поток для проверки типов
    final responseParser = contract.getResponseParser(methodContract);
    final typedController = StreamController<Response>.broadcast();

    stream.listen(
      (data) {
        try {
          final typedData = responseParser(data);
          if (methodContract.validateResponse(typedData)) {
            typedController.add(typedData);
          } else {
            typedController
                .addError('Тип данных в потоке не соответствует контракту');
          }
        } catch (e) {
          typedController.addError(e);
        }
      },
      onError: (error) => typedController.addError(error),
      onDone: () => typedController.close(),
    );

    return typedController.stream;
  }

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
