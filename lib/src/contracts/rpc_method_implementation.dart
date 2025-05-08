import '_index.dart' show RpcMethodContract, RpcMethodType;

/// Класс, предоставляющий реализацию типизированного метода
final class RpcMethodImplementation<Request, Response> {
  /// Ссылка на контракт метода
  final RpcMethodContract<Request, Response> contract;

  /// Обработчик для унарного метода
  final Future<Response> Function(Request)? unaryHandler;

  /// Обработчик для стримингового метода
  final Stream<Response> Function(Request)? streamHandler;

  /// Обработчик для двунаправленного стрима
  final Stream<Response> Function(Stream<Request>)? bidirectionalHandler;

  /// Стандартный конструктор
  RpcMethodImplementation({
    required this.contract,
    this.unaryHandler,
    this.streamHandler,
    this.bidirectionalHandler,
  });

  /// Создает реализацию метода-заглушки
  RpcMethodImplementation.stub()
      : contract =
            RpcMethodContract(methodName: '', methodType: RpcMethodType.unary),
        unaryHandler = null,
        streamHandler = null,
        bidirectionalHandler = null;

  /// Создает реализацию унарного метода
  RpcMethodImplementation.unary(
    this.contract,
    Future<Response> Function(Request) handler,
  )   : unaryHandler = handler,
        streamHandler = null,
        bidirectionalHandler = null {
    if (contract.methodType != RpcMethodType.unary) {
      throw ArgumentError('Метод ${contract.methodName} не является унарным');
    }
  }

  /// Создает реализацию стримингового метода
  RpcMethodImplementation.serverStream(
    this.contract,
    Stream<Response> Function(Request) handler,
  )   : streamHandler = handler,
        unaryHandler = null,
        bidirectionalHandler = null {
    if (contract.methodType != RpcMethodType.serverStreaming) {
      throw ArgumentError(
          'Метод ${contract.methodName} не является серверным стримом');
    }
  }

  /// Создает реализацию двунаправленного стримингового метода
  RpcMethodImplementation.bidirectionalStream(
    this.contract,
    Stream<Response> Function(Stream<Request>) handler,
  )   : bidirectionalHandler = handler,
        streamHandler = null,
        unaryHandler = null {
    if (contract.methodType != RpcMethodType.bidirectional) {
      throw ArgumentError(
          'Метод ${contract.methodName} не является двунаправленным стримом');
    }
  }

  /// Вызывает метод с типизированным параметром
  Future<Response> invoke(dynamic request) async {
    if (!contract.validateRequest(request)) {
      throw ArgumentError(
        'Неверный тип запроса: ${request.runtimeType}, ожидается: $Request',
      );
    }

    if (unaryHandler != null) {
      final result = await unaryHandler!(request as Request);

      if (!contract.validateResponse(result)) {
        throw StateError(
          'Неверный тип ответа: ${result.runtimeType}, ожидается: $Response',
        );
      }

      return result;
    }

    throw UnsupportedError(
        'Метод ${contract.methodName} не поддерживает унарный вызов');
  }

  /// Открывает поток с типизированным параметром
  Stream<Response> openStream(dynamic request) {
    if (!contract.validateRequest(request)) {
      throw ArgumentError(
        'Неверный тип запроса: ${request.runtimeType}, ожидается: $Request',
      );
    }

    if (streamHandler != null) {
      final stream = streamHandler!(request as Request);
      // Проверяем типы всех элементов в стриме
      return stream.map((item) {
        if (!contract.validateResponse(item)) {
          throw StateError(
            'Неверный тип элемента в потоке: ${item.runtimeType}, ожидается: $Response',
          );
        }
        return item;
      });
    }

    throw UnsupportedError(
        'Метод ${contract.methodName} не поддерживает потоковый вызов');
  }

  /// Открывает двунаправленный поток
  Stream<Response> openBidirectionalStream(Stream<dynamic> requestStream) {
    if (bidirectionalHandler == null) {
      throw UnsupportedError(
          'Метод ${contract.methodName} не поддерживает двунаправленный потоковый вызов');
    }

    // Преобразуем входящие данные к типизированному стриму Request
    final typedRequestStream = requestStream.map((request) {
      if (!contract.validateRequest(request)) {
        throw ArgumentError(
          'Неверный тип запроса в потоке: ${request.runtimeType}, ожидается: $Request',
        );
      }
      return request as Request;
    });

    // Получаем ответный стрим от обработчика
    final responseStream = bidirectionalHandler!(typedRequestStream);

    // Проверяем типы всех исходящих элементов
    return responseStream.map((response) {
      if (!contract.validateResponse(response)) {
        throw StateError(
          'Неверный тип ответа в потоке: ${response.runtimeType}, ожидается: $Response',
        );
      }
      return response;
    });
  }
}
