// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Класс для серверного стриминга с возможностью отправки одного запроса
///
/// Позволяет отправить не более одного запроса и затем получать поток ответов.
class ServerStreamingBidiStream<RequestType extends IRpcSerializableMessage,
        ResponseType extends IRpcSerializableMessage>
    extends RpcStream<RequestType, ResponseType> {
  final void Function(RequestType) _sendFunction;

  /// Флаг, указывающий, был ли отправлен запрос
  bool _requestSent = false;

  /// Конструктор обертки серверного стриминга
  ServerStreamingBidiStream({
    required Stream<ResponseType> stream,
    required Future<void> Function() closeFunction,
    required void Function(RequestType) sendFunction,
  })  : _sendFunction = sendFunction,
        super(
          responseStream: stream,
          closeFunction: closeFunction,
        );

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

  // Методы Stream, которые просто делегируют вызовы внутреннему стриму
  @override
  Stream<ResponseType> asBroadcastStream({
    void Function(StreamSubscription<ResponseType> subscription)? onListen,
    void Function(StreamSubscription<ResponseType> subscription)? onCancel,
  }) {
    return responseStream.asBroadcastStream(
        onListen: onListen, onCancel: onCancel);
  }

  @override
  StreamSubscription<ResponseType> listen(
    void Function(ResponseType event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return responseStream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(ResponseType event) convert) {
    return responseStream.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(ResponseType event) convert) {
    return responseStream.asyncMap(convert);
  }

  @override
  Stream<R1> cast<R1>() {
    return responseStream.cast<R1>();
  }

  @override
  Future<bool> contains(Object? needle) {
    return responseStream.contains(needle);
  }

  @override
  Stream<ResponseType> distinct(
      [bool Function(ResponseType previous, ResponseType next)? equals]) {
    return responseStream.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return responseStream.drain(futureValue);
  }

  @override
  Future<ResponseType> elementAt(int index) {
    return responseStream.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(ResponseType element) test) {
    return responseStream.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(ResponseType element) convert) {
    return responseStream.expand(convert);
  }

  @override
  Future<ResponseType> get first => responseStream.first;

  @override
  Future<ResponseType> firstWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return responseStream.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
    S initialValue,
    S Function(S previous, ResponseType element) combine,
  ) {
    return responseStream.fold(initialValue, combine);
  }

  @override
  Future<void> forEach(void Function(ResponseType element) action) {
    return responseStream.forEach(action);
  }

  @override
  Stream<ResponseType> handleError(
    Function onError, {
    bool Function(dynamic error)? test,
  }) {
    return responseStream.handleError(onError, test: test);
  }

  @override
  bool get isBroadcast => responseStream.isBroadcast;

  @override
  Future<bool> get isEmpty => responseStream.isEmpty;

  @override
  Future<String> join([String separator = '']) {
    return responseStream.join(separator);
  }

  @override
  Future<ResponseType> get last => responseStream.last;

  @override
  Future<ResponseType> lastWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return responseStream.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => responseStream.length;

  @override
  Stream<S> map<S>(S Function(ResponseType event) convert) {
    return responseStream.map(convert);
  }

  @override
  Future<ResponseType> reduce(
      ResponseType Function(ResponseType previous, ResponseType element)
          combine) {
    return responseStream.reduce(combine);
  }

  @override
  Future<ResponseType> get single => responseStream.single;

  @override
  Future<ResponseType> singleWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return responseStream.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<ResponseType> skip(int count) {
    return responseStream.skip(count);
  }

  @override
  Stream<ResponseType> skipWhile(bool Function(ResponseType element) test) {
    return responseStream.skipWhile(test);
  }

  @override
  Stream<ResponseType> take(int count) {
    return responseStream.take(count);
  }

  @override
  Stream<ResponseType> takeWhile(bool Function(ResponseType element) test) {
    return responseStream.takeWhile(test);
  }

  @override
  Stream<ResponseType> timeout(
    Duration timeLimit, {
    void Function(EventSink<ResponseType> sink)? onTimeout,
  }) {
    return responseStream.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<ResponseType>> toList() {
    return responseStream.toList();
  }

  @override
  Future<Set<ResponseType>> toSet() {
    return responseStream.toSet();
  }

  @override
  Stream<ResponseType> where(bool Function(ResponseType event) test) {
    return responseStream.where(test);
  }

  @override
  Future<bool> any(bool Function(ResponseType element) test) {
    return responseStream.any(test);
  }

  @override
  Future<void> pipe(StreamConsumer<ResponseType> streamConsumer) {
    return responseStream.pipe(streamConsumer);
  }

  @override
  Stream<S> transform<S>(StreamTransformer<ResponseType, S> streamTransformer) {
    return responseStream.transform(streamTransformer);
  }
}
