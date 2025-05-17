// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Обертка BidiStream для клиентского стриминга
///
/// Позволяет отправлять поток запросов и получить ответ после завершения обработки.
/// Поддерживает режимы с ответом и без ответа (noResponse=true).
class ClientStreamingBidiStream<RequestType extends IRpcSerializableMessage,
        ResponseType extends IRpcSerializableMessage>
    extends RpcStream<RequestType, ResponseType> {
  /// Внутренний BidiStream
  final BidiStream<RequestType, ResponseType> _bidiStream;

  /// Внутренний флаг завершения потока для отслеживания состояния
  bool _isStreamFinished = false;

  /// Комплитер для ожидания ответа от сервера после завершения стрима
  final Completer<ResponseType?> _responseCompleter =
      Completer<ResponseType?>();

  /// Флаг указывающий, ожидается ли ответ от сервера
  final bool _expectResponse;

  /// Создает обертку для клиентского стриминга
  ///
  /// [bidiStream] - внутренний двунаправленный поток
  /// [expectResponse] - флаг, указывающий, ожидается ли ответ от сервера (по умолчанию true)
  ClientStreamingBidiStream(this._bidiStream, {bool expectResponse = true})
      : _expectResponse = expectResponse,
        super(
          responseStream: _bidiStream,
          closeFunction: _bidiStream.close,
        ) {
    // Если ожидается ответ, подписываемся на первое сообщение в потоке ответов
    if (_expectResponse) {
      _bidiStream.first.then((response) {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.complete(response);
        }
      }).catchError((error) {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.completeError(error);
        }
      });
    } else {
      // Если ответ не ожидается, сразу завершаем комплитер с null
      _responseCompleter.complete(null);
    }
  }

  /// Отправляет запрос через внутренний BidiStream
  void send(RequestType request) {
    _bidiStream.send(request);
  }

  /// Завершает отправку запросов, но не закрывает стрим
  Future<void> finishSending() async {
    await _bidiStream.finishTransfer();
  }

  /// Принудительно завершает обработку стрима и устанавливает флаг завершения
  ///
  /// Отличается от close() тем, что не закрывает полностью стрим,
  /// а только устанавливает флаг завершения для предотвращения
  /// повторной обработки сообщений
  void markAsFinished() {
    _isStreamFinished = true;
  }

  /// Проверяет, завершен ли стрим (логически)
  bool get isFinished => _isStreamFinished || isClosed;

  /// Получает ответ от сервера после завершения обработки стрима
  ///
  /// Возвращает Future, который завершится когда сервер отправит ответ
  /// после обработки всех полученных сообщений. Если ответ не ожидается,
  /// возвращает Future с null.
  Future<ResponseType?> getResponse() {
    return _responseCompleter.future;
  }

  /// Проверяет, ожидается ли ответ от сервера
  bool get expectsResponse => _expectResponse;

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    // Сначала закрываем внутренний поток
    await _bidiStream.close();

    // Если комплитер еще не завершен, завершаем его с null
    if (!_responseCompleter.isCompleted) {
      _responseCompleter.complete(null);
    }

    // Вызываем метод базового класса для установки флага _isClosed
    await super.close();
  }
}
