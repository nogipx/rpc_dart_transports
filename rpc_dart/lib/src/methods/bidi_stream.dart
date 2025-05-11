part of '_method.dart';

/// Двунаправленный стрим с возможностью отправки и получения сообщений
class BidiStream<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> extends Stream<Response> {
  final Stream<Response> _responseStream;
  final void Function(Request request) _sendFunction;
  final Future<void> Function() _closeFunction;
  bool _isClosed = false;

  BidiStream({
    required Stream<Response> responseStream,
    required void Function(Request request) sendFunction,
    required Future<void> Function() closeFunction,
  })  : _responseStream = responseStream,
        _sendFunction = sendFunction,
        _closeFunction = closeFunction;

  /// Отправляет запрос в канал
  void send(Request request) {
    if (_isClosed) {
      throw StateError('Канал закрыт для отправки');
    }
    _sendFunction(request);
  }

  /// Закрывает канал
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _closeFunction();
  }

  /// Проверяет, закрыт ли канал
  bool get isClosed => _isClosed;

  @override
  StreamSubscription<Response> listen(
    void Function(Response event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _responseStream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

/// Декоратор для создания двунаправленных стримов на основе async* генераторов
class BidiStreamGenerator<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  /// Функция-генератор, которая принимает стрим запросов и возвращает стрим ответов
  final Stream<Response> Function(Stream<Request>) _generator;

  /// Создает новый декоратор с указанной функцией-генератором
  BidiStreamGenerator(this._generator);

  /// Создает BidiStream из текущего генератора и начального стрима запросов
  BidiStream<Request, Response> create([Stream<Request>? initialRequests]) {
    // Создаем контроллер для запросов
    final requestController = StreamController<Request>();

    // Если есть начальные запросы, перенаправляем их в контроллер
    if (initialRequests != null) {
      initialRequests.listen(
        (request) => requestController.add(request),
        onError: (error) => requestController.addError(error),
        onDone:
            () {}, // Не закрываем контроллер, так как через него можно будет отправлять запросы позже
      );
    }

    // Генерируем ответы с помощью переданного генератора
    final responseStream = _generator(requestController.stream);

    // Создаем BidiStream
    return BidiStream<Request, Response>(
      responseStream: responseStream,
      sendFunction: (request) {
        if (!requestController.isClosed) {
          requestController.add(request);
        }
      },
      closeFunction: () async {
        if (!requestController.isClosed) {
          await requestController.close();
        }
      },
    );
  }
}
