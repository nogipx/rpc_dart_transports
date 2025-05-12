// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Обертка над BidiStream, специфичная для Server Streaming:
/// клиент отправляет один запрос, а сервер отправляет поток ответов
final class ServerStreamingBidiStream<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> extends Stream<Response> {
  final BidiStream<Request, Response> _bidiStream;
  bool _alreadySent = false;

  /// Создает обертку над BidiStream для Server Streaming
  ServerStreamingBidiStream(this._bidiStream);

  /// Отправляет один запрос серверу
  /// Можно отправить только один запрос, повторные вызовы вызовут ошибку
  void sendRequest(Request request) {
    if (_alreadySent) {
      throw StateError(
          'Для Server Streaming можно отправить только один запрос');
    }
    _alreadySent = true;
    _bidiStream.send(request);
  }

  /// Закрывает стрим
  Future<void> close() => _bidiStream.close();

  /// Проверяет, закрыт ли стрим
  bool get isClosed => _bidiStream.isClosed;

  @override
  StreamSubscription<Response> listen(
    void Function(Response event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _bidiStream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
