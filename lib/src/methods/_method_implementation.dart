part of '_method.dart';

/// Класс, представляющий реализацию RPC метода
final class RpcMethodImplementation<Request, Response> {
  /// Контракт метода
  final RpcMethodContract<Request, Response> contract;

  /// Тип метода
  final RpcMethodType type;

  /// Обработчик унарного метода
  final Future<Response> Function(Request)? _unaryHandler;

  /// Обработчик серверного стрима
  final Stream<Response> Function(Request)? _serverStreamHandler;

  /// Обработчик клиентского стрима
  final Future<Response> Function(Stream<Request>)? _clientStreamHandler;

  /// Обработчик двунаправленного стрима
  final Stream<Response> Function(Stream<Request>, String)?
      _bidirectionalHandler;

  /// Создает реализацию унарного метода
  RpcMethodImplementation.unary(
    this.contract,
    Future<Response> Function(Request) handler,
  )   : type = RpcMethodType.unary,
        _unaryHandler = handler,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = null;

  /// Создает реализацию серверного стрима
  RpcMethodImplementation.serverStream(
    this.contract,
    Stream<Response> Function(Request) handler,
  )   : type = RpcMethodType.serverStreaming,
        _unaryHandler = null,
        _serverStreamHandler = handler,
        _clientStreamHandler = null,
        _bidirectionalHandler = null;

  /// Создает реализацию клиентского стрима
  RpcMethodImplementation.clientStream(
    this.contract,
    Future<Response> Function(Stream<Request>) handler,
  )   : type = RpcMethodType.clientStreaming,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = handler,
        _bidirectionalHandler = null;

  /// Создает реализацию двунаправленного стрима
  RpcMethodImplementation.bidirectional(
    this.contract,
    Stream<Response> Function(Stream<Request>, String) handler,
  )   : type = RpcMethodType.bidirectional,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = handler;

  /// Вызывает метод с указанным запросом
  Future<Response> invoke(Request request) async {
    if (type == RpcMethodType.unary && _unaryHandler != null) {
      return await _unaryHandler!(request);
    }

    throw StateError('Метод типа $type не поддерживает прямой вызов');
  }

  /// Открывает стрим ответов для указанного запроса
  Stream<Response> openStream(Request request) {
    if (type == RpcMethodType.serverStreaming && _serverStreamHandler != null) {
      return _serverStreamHandler!(request);
    }

    throw StateError('Метод типа $type не поддерживает открытие стрима');
  }

  /// Обрабатывает поток запросов и возвращает один ответ
  Future<Response> handleClientStream(Stream<Request> requestsStream) async {
    if (type == RpcMethodType.clientStreaming && _clientStreamHandler != null) {
      return await _clientStreamHandler!(requestsStream);
    }

    throw StateError('Метод типа $type не поддерживает клиентский стриминг');
  }

  /// Открывает двунаправленный стрим
  Stream<Response> openBidirectionalStream(
      Stream<Request> requestsStream, String messageId) {
    if (type == RpcMethodType.bidirectional && _bidirectionalHandler != null) {
      return _bidirectionalHandler!(requestsStream, messageId);
    }

    throw StateError(
        'Метод типа $type не поддерживает двунаправленный стриминг');
  }
}
