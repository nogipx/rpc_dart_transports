part of '../_index.dart';

class ServerStreamingBidiStream<RequestType extends IRpcSerializableMessage,
        ResponseType extends IRpcSerializableMessage>
    implements Stream<ResponseType> {
  final Stream<ResponseType> _stream;
  final Future<void> Function() _closeFunction;
  final void Function(RequestType) _sendFunction;

  /// Флаг, указывающий, был ли отправлен запрос
  bool _requestSent = false;

  /// Конструктор обертки двунаправленного стрима
  ServerStreamingBidiStream({
    required Stream<ResponseType> stream,
    required Future<void> Function() closeFunction,
    required void Function(RequestType) sendFunction,
  })  : _stream = stream,
        _closeFunction = closeFunction,
        _sendFunction = sendFunction;

  /// Отправляет запрос в стрим
  void sendRequest(RequestType request) {
    if (_requestSent) {
      throw RpcUnsupportedOperationException(
        operation: 'sendRequest',
        type: 'serverStreaming',
        details: {
          'message':
              'Невозможно отправить второй запрос в ServerStreamingBidiStream. '
                  'Этот тип стрима поддерживает только один запрос для инициализации.'
        },
      );
    }
    _requestSent = true;
    _sendFunction(request);
  }

  /// Закрывает стрим
  Future<void> close() {
    return _closeFunction();
  }

  // Методы Stream, которые просто делегируют вызовы внутреннему стриму
  @override
  Stream<ResponseType> asBroadcastStream({
    void Function(StreamSubscription<ResponseType> subscription)? onListen,
    void Function(StreamSubscription<ResponseType> subscription)? onCancel,
  }) {
    return _stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  StreamSubscription<ResponseType> listen(
    void Function(ResponseType event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(ResponseType event) convert) {
    return _stream.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(ResponseType event) convert) {
    return _stream.asyncMap(convert);
  }

  @override
  Stream<R1> cast<R1>() {
    return _stream.cast<R1>();
  }

  @override
  Future<bool> contains(Object? needle) {
    return _stream.contains(needle);
  }

  @override
  Stream<ResponseType> distinct(
      [bool Function(ResponseType previous, ResponseType next)? equals]) {
    return _stream.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return _stream.drain(futureValue);
  }

  @override
  Future<ResponseType> elementAt(int index) {
    return _stream.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(ResponseType element) test) {
    return _stream.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(ResponseType element) convert) {
    return _stream.expand(convert);
  }

  @override
  Future<ResponseType> get first => _stream.first;

  @override
  Future<ResponseType> firstWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return _stream.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
    S initialValue,
    S Function(S previous, ResponseType element) combine,
  ) {
    return _stream.fold(initialValue, combine);
  }

  @override
  Future<void> forEach(void Function(ResponseType element) action) {
    return _stream.forEach(action);
  }

  @override
  Stream<ResponseType> handleError(
    Function onError, {
    bool Function(dynamic error)? test,
  }) {
    return _stream.handleError(onError, test: test);
  }

  @override
  bool get isBroadcast => _stream.isBroadcast;

  @override
  Future<bool> get isEmpty => _stream.isEmpty;

  @override
  Future<String> join([String separator = '']) {
    return _stream.join(separator);
  }

  @override
  Future<ResponseType> get last => _stream.last;

  @override
  Future<ResponseType> lastWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return _stream.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => _stream.length;

  @override
  Stream<S> map<S>(S Function(ResponseType event) convert) {
    return _stream.map(convert);
  }

  @override
  Future<ResponseType> reduce(
      ResponseType Function(ResponseType previous, ResponseType element)
          combine) {
    return _stream.reduce(combine);
  }

  @override
  Future<ResponseType> get single => _stream.single;

  @override
  Future<ResponseType> singleWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return _stream.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<ResponseType> skip(int count) {
    return _stream.skip(count);
  }

  @override
  Stream<ResponseType> skipWhile(bool Function(ResponseType element) test) {
    return _stream.skipWhile(test);
  }

  @override
  Stream<ResponseType> take(int count) {
    return _stream.take(count);
  }

  @override
  Stream<ResponseType> takeWhile(bool Function(ResponseType element) test) {
    return _stream.takeWhile(test);
  }

  @override
  Stream<ResponseType> timeout(
    Duration timeLimit, {
    void Function(EventSink<ResponseType> sink)? onTimeout,
  }) {
    return _stream.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<ResponseType>> toList() {
    return _stream.toList();
  }

  @override
  Future<Set<ResponseType>> toSet() {
    return _stream.toSet();
  }

  @override
  Stream<ResponseType> where(bool Function(ResponseType event) test) {
    return _stream.where(test);
  }

  @override
  Future<bool> any(bool Function(ResponseType element) test) {
    return _stream.any(test);
  }

  @override
  Future<void> pipe(StreamConsumer<ResponseType> streamConsumer) {
    return _stream.pipe(streamConsumer);
  }

  @override
  Stream<S> transform<S>(StreamTransformer<ResponseType, S> streamTransformer) {
    return _stream.transform(streamTransformer);
  }
}
