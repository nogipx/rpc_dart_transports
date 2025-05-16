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
}
