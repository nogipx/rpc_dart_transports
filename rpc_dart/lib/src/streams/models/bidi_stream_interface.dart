// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Интерфейс двунаправленного стрима
///
/// Определяет контракт для двунаправленных стримов,
/// совмещая возможности Stream с методами отправки запросов
class BidiStreamInterface<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> implements Stream<Response> {
  final Stream<Response> stream;
  final void Function(Request) sendFunction;
  final Future<void> Function() closeFunction;

  BidiStreamInterface({
    required this.stream,
    required this.sendFunction,
    required this.closeFunction,
  });

  /// Отправляет запрос через стрим
  void send(Request request) {
    sendFunction(request);
  }

  /// Закрывает стрим
  Future<void> close() async {
    await closeFunction();
  }

  @override
  StreamSubscription<Response> listen(
    void Function(Response event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  // Реализация остальных методов Stream для полной совместимости
  @override
  Stream<Response> asBroadcastStream({
    void Function(StreamSubscription<Response> subscription)? onListen,
    void Function(StreamSubscription<Response> subscription)? onCancel,
  }) {
    return stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(Response event) convert) {
    return stream.asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(Response event) convert) {
    return stream.asyncMap(convert);
  }

  @override
  Stream<R> cast<R>() {
    return stream.cast<R>();
  }

  @override
  Future<bool> contains(Object? needle) {
    return stream.contains(needle);
  }

  @override
  Stream<Response> distinct(
      [bool Function(Response previous, Response next)? equals]) {
    return stream.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return stream.drain(futureValue);
  }

  @override
  Future<Response> elementAt(int index) {
    return stream.elementAt(index);
  }

  @override
  Future<bool> every(bool Function(Response element) test) {
    return stream.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(Response element) convert) {
    return stream.expand(convert);
  }

  @override
  Future<Response> get first => stream.first;

  @override
  Future<Response> firstWhere(
    bool Function(Response element) test, {
    Response Function()? orElse,
  }) {
    return stream.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
    S initialValue,
    S Function(S previous, Response element) combine,
  ) {
    return stream.fold(initialValue, combine);
  }

  @override
  Future<void> forEach(void Function(Response element) action) {
    return stream.forEach(action);
  }

  @override
  bool get isBroadcast => stream.isBroadcast;

  @override
  Future<bool> get isEmpty => stream.isEmpty;

  @override
  Future<String> join([String separator = ""]) {
    return stream.join(separator);
  }

  @override
  Future<Response> get last => stream.last;

  @override
  Future<Response> lastWhere(
    bool Function(Response element) test, {
    Response Function()? orElse,
  }) {
    return stream.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => stream.length;

  @override
  Stream<S> map<S>(S Function(Response event) convert) {
    return stream.map(convert);
  }

  @override
  Future<Response> reduce(
    Response Function(Response previous, Response element) combine,
  ) {
    return stream.reduce(combine);
  }

  @override
  Future<Response> get single => stream.single;

  @override
  Future<Response> singleWhere(
    bool Function(Response element) test, {
    Response Function()? orElse,
  }) {
    return stream.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<Response> skip(int count) {
    return stream.skip(count);
  }

  @override
  Stream<Response> skipWhile(bool Function(Response element) test) {
    return stream.skipWhile(test);
  }

  @override
  Stream<Response> take(int count) {
    return stream.take(count);
  }

  @override
  Stream<Response> takeWhile(bool Function(Response element) test) {
    return stream.takeWhile(test);
  }

  @override
  Stream<Response> timeout(
    Duration timeLimit, {
    void Function(EventSink<Response> sink)? onTimeout,
  }) {
    return stream.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<Response>> toList() {
    return stream.toList();
  }

  @override
  Future<Set<Response>> toSet() {
    return stream.toSet();
  }

  @override
  Stream<Response> where(bool Function(Response event) test) {
    return stream.where(test);
  }

  @override
  Future<bool> any(bool Function(Response element) test) {
    return stream.any(test);
  }

  @override
  Stream<Response> handleError(
    Function onError, {
    bool Function(dynamic error)? test,
  }) {
    return stream.handleError(onError, test: test);
  }

  @override
  Future<void> pipe(StreamConsumer<Response> streamConsumer) {
    return stream.pipe(streamConsumer);
  }

  @override
  Stream<T> transform<T>(StreamTransformer<Response, T> streamTransformer) {
    return stream.transform(streamTransformer);
  }
}
