// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Обертка BidiStream для клиентского стриминга
///
/// Позволяет отправлять поток запросов без ожидания ответа.
/// Упрощенная версия, работающая только в режиме noResponse=true.
class ClientStreamingBidiStream<RequestType extends IRpcSerializableMessage>
    extends RpcStream<RequestType, RpcNull> {
  /// Внутренний BidiStream
  final BidiStream<RequestType, RpcNull> _bidiStream;

  /// Внутренний флаг завершения потока для отслеживания состояния
  bool _isStreamFinished = false;

  /// Создает обертку для клиентского стриминга без ожидания ответа
  ClientStreamingBidiStream(this._bidiStream)
      : super(
          responseStream: _bidiStream,
          closeFunction: _bidiStream.close,
        );

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

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    // Сначала закрываем внутренний поток
    await _bidiStream.close();

    // Вызываем метод базового класса для установки флага _isClosed
    await super.close();
  }
}
