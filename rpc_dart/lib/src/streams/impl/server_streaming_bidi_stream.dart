part of '../_index.dart';

/// Обертка для Stream, предоставляющая двунаправленный функционал
///
/// Эта обертка превращает обычный Stream в двунаправленный с методами
/// для отправки запросов и закрытия. Используется для обратной совместимости
/// с кодом, ожидающим более богатый API, чем просто Stream.
class ServerStreamingBidiStream<T extends IRpcSerializableMessage,
    R extends IRpcSerializableMessage> implements Stream<T> {
  final Stream<T> _stream;
  final Future<void> Function() _closeFunction;
  final void Function(R) _sendFunction;

  /// Флаг, указывающий, был ли отправлен запрос
  bool _requestSent = false;

  /// Конструктор обертки двунаправленного стрима
  ServerStreamingBidiStream({
    required Stream<T> stream,
    required Future<void> Function() closeFunction,
    required void Function(R) sendFunction,
  })  : _stream = stream,
        _closeFunction = closeFunction,
        _sendFunction = sendFunction;

  /// Отправляет запрос в стрим
  void sendRequest(R request) {
    if (_requestSent) {
      throw StateError(
          'Невозможно отправить второй запрос в ServerStreamingBidiStream. '
          'Этот тип стрима поддерживает только один запрос.');
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
  Stream<T> asBroadcastStream({
    void Function(StreamSubscription<T> subscription)? onListen,
    void Function(StreamSubscription<T> subscription)? onCancel,
  }) {
    return _stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
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
  Stream<E> asyncExpand<E>(Stream<E>? Function(T event) convert) {
    return _stream.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(T event) convert) {
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
  Stream<T> distinct([bool Function(T previous, T next)? equals]) {
    return _stream.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return _stream.drain(futureValue);
  }

  @override
  Future<T> elementAt(int index) {
    return _stream.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(T element) test) {
    return _stream.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(T element) convert) {
    return _stream.expand(convert);
  }

  @override
  Future<T> get first => _stream.first;

  @override
  Future<T> firstWhere(
    bool Function(T element) test, {
    T Function()? orElse,
  }) {
    return _stream.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
    S initialValue,
    S Function(S previous, T element) combine,
  ) {
    return _stream.fold(initialValue, combine);
  }

  @override
  Future<void> forEach(void Function(T element) action) {
    return _stream.forEach(action);
  }

  @override
  Stream<T> handleError(
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
  Future<T> get last => _stream.last;

  @override
  Future<T> lastWhere(
    bool Function(T element) test, {
    T Function()? orElse,
  }) {
    return _stream.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => _stream.length;

  @override
  Stream<S> map<S>(S Function(T event) convert) {
    return _stream.map(convert);
  }

  @override
  Future<T> reduce(T Function(T previous, T element) combine) {
    return _stream.reduce(combine);
  }

  @override
  Future<T> get single => _stream.single;

  @override
  Future<T> singleWhere(
    bool Function(T element) test, {
    T Function()? orElse,
  }) {
    return _stream.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<T> skip(int count) {
    return _stream.skip(count);
  }

  @override
  Stream<T> skipWhile(bool Function(T element) test) {
    return _stream.skipWhile(test);
  }

  @override
  Stream<T> take(int count) {
    return _stream.take(count);
  }

  @override
  Stream<T> takeWhile(bool Function(T element) test) {
    return _stream.takeWhile(test);
  }

  @override
  Stream<T> timeout(
    Duration timeLimit, {
    void Function(EventSink<T> sink)? onTimeout,
  }) {
    return _stream.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<T>> toList() {
    return _stream.toList();
  }

  @override
  Future<Set<T>> toSet() {
    return _stream.toSet();
  }

  @override
  Stream<T> where(bool Function(T event) test) {
    return _stream.where(test);
  }

  @override
  Future<bool> any(bool Function(T element) test) {
    return _stream.any(test);
  }

  @override
  Future<void> pipe(StreamConsumer<T> streamConsumer) {
    return _stream.pipe(streamConsumer);
  }

  @override
  Stream<S> transform<S>(StreamTransformer<T, S> streamTransformer) {
    return _stream.transform(streamTransformer);
  }
}
