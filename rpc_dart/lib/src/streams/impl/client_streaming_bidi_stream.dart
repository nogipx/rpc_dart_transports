// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Обертка над BidiStream, специфичная для Client Streaming:
/// клиент отправляет поток запросов, а сервер отправляет один ответ
final class ClientStreamingBidiStream<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  final BidiStream<Request, Response> _bidiStream;
  final Completer<Response> _responseCompleter = Completer<Response>();
  StreamSubscription? _subscription;
  bool _isClosed = false;
  bool _isFinished = false;

  /// Создает обертку над BidiStream для Client Streaming
  ClientStreamingBidiStream(this._bidiStream) {
    // Подписываемся на ответы и берем только первый
    _subscription = _bidiStream.listen((response) {
      if (!_responseCompleter.isCompleted) {
        _responseCompleter.complete(response);
        // Отписываемся сразу после получения ответа
        // чтобы избежать утечки памяти
        _subscription?.cancel();
        _subscription = null;
      }
    }, onError: (e) {
      if (!_responseCompleter.isCompleted) {
        _responseCompleter.completeError(e);
        // Отписываемся и при ошибке
        _subscription?.cancel();
        _subscription = null;
      }
    }, onDone: () {
      // Если поток завершился без ответа
      if (!_responseCompleter.isCompleted) {
        _responseCompleter.completeError('Поток завершился без ответа');
        _subscription?.cancel();
        _subscription = null;
      }
    });
  }

  /// Отправляет запрос серверу
  /// Можно отправлять любое количество запросов
  void send(Request request) {
    if (_isClosed || _isFinished) {
      throw StateError(
          'Невозможно отправить запрос: поток закрыт или передача данных завершена');
    }
    _bidiStream.send(request);
  }

  /// Завершает отправку данных и сигнализирует серверу, что больше запросов не будет
  /// После вызова этого метода нельзя отправлять новые запросы
  /// Используйте этот метод перед getResponse() для получения результата
  Future<void> finishSending() async {
    if (_isClosed || _isFinished) {
      return; // Поток уже закрыт или передача данных завершена
    }

    _isFinished = true;

    // Используем новый метод finishTransfer базового потока
    await _bidiStream.finishTransfer();
    // Отправка данных завершена, ожидаем ответ от сервера
  }

  /// Получает ответ от сервера
  /// Возвращает Future, который завершится, когда придет ответ от сервера
  /// Рекомендуется вызывать после finishSending()
  Future<Response> getResponse() {
    if (!_isFinished && !_isClosed) {
      // Предупреждение: вызов getResponse() без finishSending() может привести к тому,
      // что сервер будет ожидать дополнительные данные и не отправит ответ
    }
    return _responseCompleter.future;
  }

  /// Проверяет, получен ли уже ответ
  bool get hasResponse => _responseCompleter.isCompleted;

  /// Проверяет, закрыт ли стрим
  bool get isClosed => _isClosed || _bidiStream.isClosed;

  /// Проверяет, завершена ли отправка данных
  bool get isFinishedSending => _isFinished || _bidiStream.isTransferFinished;

  /// Закрывает стрим и очищает ресурсы
  Future<void> close() async {
    if (_isClosed) {
      return; // Поток уже закрыт
    }

    // Если отправка еще не завершена, завершаем её
    if (!_isFinished) {
      await finishSending();
    }

    _isClosed = true;

    try {
      // Закрываем базовый поток (если еще не закрыт)
      if (!_bidiStream.isClosed) {
        await _bidiStream.close();
      }
    } catch (e) {
      // Ошибка при закрытии игнорируется, так как мы в процессе очистки ресурсов
    } finally {
      // Всегда отменяем подписку при закрытии
      if (_subscription != null) {
        await _subscription?.cancel();
        _subscription = null;
      }
    }
  }
}
