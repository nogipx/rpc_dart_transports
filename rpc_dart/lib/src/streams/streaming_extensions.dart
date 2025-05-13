// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Расширения для BidiStream, позволяющие преобразовать его в однонаправленные стримы
extension BidiStreamExtensions<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> on BidiStream<Request, Response> {
  /// Преобразует двунаправленный стрим в серверный стрим (один запрос → много ответов)
  ///
  /// [initialRequest] - начальный запрос для отправки (опционально)
  ///
  /// Если указан initialRequest, он будет отправлен сразу после создания стрима
  ServerStreamingBidiStream<Request, Response> toServerStreaming({
    Request? initialRequest,
  }) {
    final serverStreamBidi = ServerStreamingBidiStream<Request, Response>(
      stream: this,
      sendFunction: send,
      closeFunction: close,
    );

    // Если был передан начальный запрос, отправляем его
    if (initialRequest != null) {
      serverStreamBidi.sendRequest(initialRequest);
    }

    return serverStreamBidi;
  }

  /// Преобразует двунаправленный стрим в клиентский стрим (много запросов → один ответ)
  ///
  /// Ограничивает стрим так, что он может получить только один ответ от сервера
  ClientStreamingBidiStream<Request, Response> toClientStreaming() {
    return ClientStreamingBidiStream<Request, Response>(this);
  }
}
