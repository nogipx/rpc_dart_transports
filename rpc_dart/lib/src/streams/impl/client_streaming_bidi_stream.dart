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

  /// Логгер для отладки
  final RpcLogger _logger = RpcLogger('ClientStreamingBidiStream');

  /// Флаг, указывающий, что финализация стрима уже в процессе
  bool _isFinalizingStream = false;

  /// Последний полученный ответ
  ResponseType? _lastResponse;

  /// Флаг, указывающий что ответ был обработан
  bool _wasResponseProcessed = false;

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
        _logger.debug('Получен ответ от сервера: $response');
        // Сохраняем ответ, даже если комплитер уже завершен
        _lastResponse = response;
        _wasResponseProcessed = true;

        // Когда получаем первое сообщение - сохраняем в комплитер
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.complete(response);
          // Отменяем подписку после получения первого сообщения
          _safelyDetachSubscription();
        }
      },
      onError: (error, stackTrace) {
        _logger.error('Ошибка в потоке ответов: $error',
            error: error, stackTrace: stackTrace);
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.completeError(error, stackTrace);
        }
        _safelyDetachSubscription();
      },
      onDone: () {
        _logger.debug('Поток ответов завершен');
        // Поток завершился без сообщений - это нормальный сценарий
        if (!_responseCompleter.isCompleted) {
          // Если у нас уже был ответ, но он не был отправлен через комплитер
          if (_wasResponseProcessed && _lastResponse != null) {
            _responseCompleter.complete(_lastResponse);
            _logger.debug(
                'Поток завершен - отправляем сохраненный ответ: $_lastResponse');
          } else {
            _responseCompleter.complete(null);
            _logger.debug('Поток завершен без ответа');
          }
        }
        _subscription = null;
      },
      // Используем cancelOnError, чтобы автоматически отменять подписку при ошибке
      cancelOnError: true,
    );
  }

  /// Безопасно отменяет подписку на поток ответов
  void _safelyDetachSubscription() {
    if (_subscription != null) {
      _subscription!.cancel().then((_) {
        _subscription = null;
      }).catchError((e) {
        _logger.error('Ошибка при отмене подписки: $e', error: e);
        _subscription = null;
      });
    }
  }

  /// Отправляет запрос через внутренний BidiStream
  void send(RequestType request) {
    try {
      _bidiStream.send(request);
    } catch (e, stackTrace) {
      _logger.error('Ошибка при отправке запроса: $e',
          error: e, stackTrace: stackTrace);
      // Проверяем, не является ли ошибка связанной с закрытым потоком
      if (e is StateError && e.toString().contains('закрытый поток')) {
        // В этом случае просто логируем и возвращаемся
        return;
      }
      // Для других ошибок пробрасываем исключение
      rethrow;
    }
  }

  /// Завершает отправку запросов, но не закрывает стрим
  Future<void> finishSending() async {
    // Предотвращаем двойной вызов финализации
    if (_isFinalizingStream) {
      _logger.debug('Финализация уже выполняется, пропускаем повторный вызов');
      return;
    }

    _isFinalizingStream = true;

    // Явно отправляем маркер завершения потока через _bidiStream
    try {
      // Если поток не завершен и не закрыт, отправляем маркер завершения
      if (!_bidiStream.isTransferFinished && !_bidiStream.isClosed) {
        _logger.debug('Вызов finishTransfer для завершения отправки данных');
        // Используем явную реализацию finishTransfer в BidiStream
        await _bidiStream.finishTransfer();
        _logger.debug('Успешно завершена отправка данных');
      } else {
        _logger
            .debug('Поток уже завершен или закрыт, пропускаем finishTransfer');
      }
    } catch (e, stackTrace) {
      // В случае ошибки при отправке маркера, логируем и продолжаем
      _logger.error(
        'Ошибка при завершении отправки: $e',
        error: e,
        stackTrace: stackTrace,
      );

      // Если стрим был закрыт во время финализации, отражаем это в состоянии
      if (e is StateError && e.toString().contains('закрытый поток')) {
        _logger.debug('Поток уже закрыт, отмечаем как закрытый и продолжаем');
      }
    } finally {
      _isFinalizingStream = false;
    }
  }

  /// Получает ответ от сервера после завершения обработки стрима
  ///
  /// Возвращает Future, который завершится когда сервер отправит ответ
  /// после обработки всех полученных сообщений. Если ответ не ожидается,
  /// возвращает Future с null.
  Future<ResponseType?> getResponse() {
    // Если уже получили ответ, возвращаем его сразу
    if (_wasResponseProcessed && _lastResponse != null) {
      _logger.debug('Возвращаем уже полученный ответ: $_lastResponse');
      return Future.value(_lastResponse);
    }

    // В противном случае возвращаем фьючер комплитера
    return _responseCompleter.future;
  }

  @override
  Future<void> close() async {
    // Если стрим уже закрыт, просто выходим
    if (_isClosed) {
      _logger.debug('Поток уже закрыт, пропускаем close()');
      return;
    }

    _logger.debug('Закрытие клиентского стриминг потока');

    try {
      // Закрываем внутренний стрим
      await _bidiStream.close();
      _logger.debug('Внутренний поток закрыт');

      // Отменяем подписку на ответы
      await _subscription?.cancel();
      _subscription = null;

      // Устанавливаем флаг закрытия перед завершением комплитера
      _isClosed = true;

      // Завершаем комплитер ответа с null, если он еще не завершен
      if (!_responseCompleter.isCompleted) {
        _logger.debug('Комплитер ответа завершен с null');
        _responseCompleter.complete(null);
      }

      // Очищаем последний ответ
      _lastResponse = null;

      // Завершаем все ожидающие операции
      _isFinalizingStream = false;
      _wasResponseProcessed = true;

      _logger.debug('Поток полностью закрыт');
    } catch (e, stack) {
      _logger.error(
        'Ошибка при закрытии потока: $e',
        error: e,
        stackTrace: stack,
      );

      // Отметка потока как закрытого даже при ошибке
      _isClosed = true;

      // Перехватываем и логируем ошибку, но не пробрасываем дальше
      // для обеспечения корректного закрытия в любом случае

      // Завершаем комплитер в любом случае, если он еще не завершен
      if (!_responseCompleter.isCompleted) {
        _responseCompleter.complete(null);
      }
    }
  }
}
