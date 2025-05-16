// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Обертка BidiStream для клиентского стриминга
///
/// Позволяет отправлять поток запросов и получить один ответ.
class ClientStreamingBidiStream<RequestType extends IRpcSerializableMessage,
        ResponseType extends IRpcSerializableMessage>
    extends RpcStream<RequestType, ResponseType> {
  /// Внутренний BidiStream
  final BidiStream<RequestType, ResponseType> _bidiStream;

  /// Completer для отслеживания ответа
  final Completer<ResponseType> _responseCompleter = Completer<ResponseType>();

  /// Подписка на поток ответов
  StreamSubscription<ResponseType>? _subscription;

  /// Создает обертку для клиентского стриминга
  ClientStreamingBidiStream(this._bidiStream)
      : super(
          responseStream: _bidiStream,
          closeFunction: _bidiStream.close,
        ) {
    // Подписываемся на первый элемент потока ответов
    _subscription = _bidiStream.listen(
      (response) {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.complete(response);
        }
      },
      onError: (error) {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.completeError(error);
        }
      },
      onDone: () {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.completeError(
            RpcUnsupportedOperationException(
              operation: 'getResponse',
              type: 'clientStreaming',
              details: {
                'message': 'Поток завершился без ответа',
              },
            ),
          );
        }
        _subscription?.cancel();
        _subscription = null;
      },
    );
  }

  /// Отправляет запрос через внутренний BidiStream
  void send(RequestType request) {
    _bidiStream.send(request);
  }

  /// Завершает отправку запросов, но не закрывает стрим
  Future<void> finishSending() async {
    await _bidiStream.finishTransfer();
  }

  /// Ожидает получения единственного ответа
  ///
  /// Типичное использование клиентского стриминга предполагает
  /// получение одного ответа после серии запросов.
  Future<ResponseType> getResponse() async {
    // Возвращаем Future из Completer, который будет завершен,
    // когда придет первый ответ или произойдет ошибка
    return _responseCompleter.future;
  }

  @override
  Future<void> close() async {
    await _bidiStream.close();
    await _subscription?.cancel();
    _subscription = null;
  }
}
