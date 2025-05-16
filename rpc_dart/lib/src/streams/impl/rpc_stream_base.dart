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
}
