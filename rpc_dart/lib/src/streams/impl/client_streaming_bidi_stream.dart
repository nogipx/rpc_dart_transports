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

  /// Комплитер для ожидания ответа от сервера после завершения стрима
  final Completer<ResponseType?> _responseCompleter =
      Completer<ResponseType?>();

  /// Подписка на поток ответов
  StreamSubscription<ResponseType>? _subscription;

  /// Создает обертку для клиентского стриминга
  ///
  /// [bidiStream] - внутренний двунаправленный поток
  ClientStreamingBidiStream(this._bidiStream)
      : super(
          responseStream: _bidiStream,
          closeFunction: _bidiStream.close,
        ) {
    // Подписываемся на поток ответов с полной обработкой событий
    _subscription = _bidiStream.listen(
      (response) {
        // Когда получаем первое сообщение - сохраняем в комплитер
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.complete(response);
          // Отменяем подписку после получения первого сообщения
          _subscription?.cancel();
          _subscription = null;
        }
      },
      onError: (error) {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.completeError(error);
        }
        _subscription?.cancel();
        _subscription = null;
      },
      onDone: () {
        // Поток завершился без сообщений - это нормальный сценарий
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.complete(null);
        }
        _subscription = null;
      },
      // Используем cancelOnError, чтобы автоматически отменять подписку при ошибке
      cancelOnError: true,
    );
  }

  /// Отправляет запрос через внутренний BidiStream
  void send(RequestType request) {
    _bidiStream.send(request);
  }

  /// Завершает отправку запросов, но не закрывает стрим
  Future<void> finishSending() async {
    // Явно отправляем маркер завершения потока через _bidiStream
    try {
      // Если поток не завершен и не закрыт, отправляем маркер завершения
      if (!_bidiStream.isTransferFinished && !_bidiStream.isClosed) {
        // Используем явную реализацию finishTransfer в BidiStream
        await _bidiStream.finishTransfer();
      }
    } catch (e) {
      // В случае ошибки при отправке маркера, логируем и продолжаем
      RpcLogger('ClientStreamingBidiStream').error(
        'Ошибка при завершении отправки: $e',
        error: e,
      );
    }
  }

  /// Получает ответ от сервера после завершения обработки стрима
  ///
  /// Возвращает Future, который завершится когда сервер отправит ответ
  /// после обработки всех полученных сообщений. Если ответ не ожидается,
  /// возвращает Future с null.
  Future<ResponseType?> getResponse() {
    return _responseCompleter.future;
  }

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    // Отменяем подписку, если она еще активна
    await _subscription?.cancel();
    _subscription = null;

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
