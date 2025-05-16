// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Базовый абстрактный класс для всех типов RPC-стримов
///
/// Обеспечивает базовую функциональность, общую для всех типов стримов:
/// - Получение сообщений (Stream<ResponseType>)
/// - Закрытие потока
abstract class RpcStream<RequestType extends IRpcSerializableMessage,
    ResponseType extends IRpcSerializableMessage> extends Stream<ResponseType> {
  /// Базовый поток ответов
  final Stream<ResponseType> _responseStream;

  /// Функция закрытия потока
  final Future<void> Function() _closeFunction;

  /// Состояние - закрыт ли поток
  bool _isClosed = false;

  /// Создает базовый RPC-поток
  RpcStream({
    required Stream<ResponseType> responseStream,
    required Future<void> Function() closeFunction,
  })  : _responseStream = responseStream,
        _closeFunction = closeFunction;

  /// Доступ к потоку ответов для наследников
  @protected
  Stream<ResponseType> get responseStream => _responseStream;

  /// Возвращает, закрыт ли поток
  bool get isClosed => _isClosed;

  /// Закрывает поток
  Future<void> close() async {
    if (_isClosed) {
      return;
    }

    _isClosed = true;
    await _closeFunction();
  }

  // Реализация всех методов Stream через делегирование к _responseStream
  @override
  StreamSubscription<ResponseType> listen(
    void Function(ResponseType event)? onData, {
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

  @override
  Stream<ResponseType> asBroadcastStream({
    void Function(StreamSubscription<ResponseType> subscription)? onListen,
    void Function(StreamSubscription<ResponseType> subscription)? onCancel,
  }) {
    return _responseStream.asBroadcastStream(
      onListen: onListen,
      onCancel: onCancel,
    );
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(ResponseType event) convert) {
    return _responseStream.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(ResponseType event) convert) {
    return _responseStream.asyncMap(convert);
  }

  @override
  Stream<R> cast<R>() {
    return _responseStream.cast<R>();
  }

  @override
  Future<bool> contains(Object? needle) {
    return _responseStream.contains(needle);
  }

  @override
  Stream<ResponseType> distinct([
    bool Function(ResponseType previous, ResponseType next)? equals,
  ]) {
    return _responseStream.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return _responseStream.drain(futureValue);
  }

  @override
  Future<ResponseType> elementAt(int index) {
    return _responseStream.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(ResponseType element) test) {
    return _responseStream.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(ResponseType element) convert) {
    return _responseStream.expand(convert);
  }

  @override
  Future<ResponseType> get first => _responseStream.first;

  @override
  Future<ResponseType> firstWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return _responseStream.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
    S initialValue,
    S Function(S previous, ResponseType element) combine,
  ) {
    return _responseStream.fold(initialValue, combine);
  }

  @override
  Future<void> forEach(void Function(ResponseType element) action) {
    return _responseStream.forEach(action);
  }

  @override
  Stream<ResponseType> handleError(
    Function onError, {
    bool Function(dynamic error)? test,
  }) {
    return _responseStream.handleError(onError, test: test);
  }

  @override
  bool get isBroadcast => _responseStream.isBroadcast;

  @override
  Future<bool> get isEmpty => _responseStream.isEmpty;

  @override
  Future<String> join([String separator = '']) {
    return _responseStream.join(separator);
  }

  @override
  Future<ResponseType> get last => _responseStream.last;

  @override
  Future<ResponseType> lastWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return _responseStream.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => _responseStream.length;

  @override
  Stream<S> map<S>(S Function(ResponseType event) convert) {
    return _responseStream.map(convert);
  }

  @override
  Future<ResponseType> reduce(
    ResponseType Function(ResponseType previous, ResponseType element) combine,
  ) {
    return _responseStream.reduce(combine);
  }

  @override
  Future<ResponseType> get single => _responseStream.single;

  @override
  Future<ResponseType> singleWhere(
    bool Function(ResponseType element) test, {
    ResponseType Function()? orElse,
  }) {
    return _responseStream.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<ResponseType> skip(int count) {
    return _responseStream.skip(count);
  }

  @override
  Stream<ResponseType> skipWhile(bool Function(ResponseType element) test) {
    return _responseStream.skipWhile(test);
  }

  @override
  Stream<ResponseType> take(int count) {
    return _responseStream.take(count);
  }

  @override
  Stream<ResponseType> takeWhile(bool Function(ResponseType element) test) {
    return _responseStream.takeWhile(test);
  }

  @override
  Stream<ResponseType> timeout(
    Duration timeLimit, {
    void Function(EventSink<ResponseType> sink)? onTimeout,
  }) {
    return _responseStream.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<ResponseType>> toList() {
    return _responseStream.toList();
  }

  @override
  Future<Set<ResponseType>> toSet() {
    return _responseStream.toSet();
  }

  @override
  Stream<ResponseType> where(bool Function(ResponseType event) test) {
    return _responseStream.where(test);
  }

  @override
  Future<bool> any(bool Function(ResponseType element) test) {
    return _responseStream.any(test);
  }

  @override
  Future<void> pipe(StreamConsumer<ResponseType> streamConsumer) {
    return _responseStream.pipe(streamConsumer);
  }

  @override
  Stream<S> transform<S>(StreamTransformer<ResponseType, S> streamTransformer) {
    return _responseStream.transform(streamTransformer);
  }
}
