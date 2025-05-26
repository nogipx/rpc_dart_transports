// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Серверная реализация двунаправленного стрима gRPC со Stream ID.
///
/// Обеспечивает полную реализацию серверной стороны двунаправленного
/// стриминга gRPC. Обрабатывает входящие запросы от клиента и позволяет
/// отправлять ответы асинхронно, независимо от получения запросов.
/// Использует уникальный Stream ID для идентификации вызова.
///
/// Ключевые возможности:
/// - Асинхронная обработка потока входящих запросов
/// - Асинхронная отправка потока ответов
/// - Автоматическая сериализация/десериализация сообщений
/// - Управление статусами и ошибками gRPC
final class BidirectionalStreamResponder<TRequest, TResponse>
    implements IRpcResponder {
  late final RpcLogger? _logger;

  @override
  final int id;

  /// Базовый транспорт для обмена данными
  final IRpcTransport _transport;

  /// Имя сервиса
  final String serviceName;

  /// Имя метода
  final String methodName;

  /// Путь метода в формате /<ServiceName>/<MethodName>
  late final String _methodPath;

  /// Кодек для десериализации входящих запросов
  final IRpcCodec<TRequest> _requestSerializer;

  /// Кодек для сериализации исходящих ответов
  final IRpcCodec<TResponse> _responseSerializer;

  /// Контроллер потока входящих запросов
  final StreamController<TRequest> _requestController =
      StreamController<TRequest>();

  /// Контроллер потока исходящих ответов
  final StreamController<TResponse> _responseController =
      StreamController<TResponse>();

  /// Парсер для обработки фрагментированных сообщений
  late final RpcMessageParser _parser;

  /// Stream ID для активного соединения (устанавливается при первом входящем вызове)
  int? _activeStreamId;

  /// Поток входящих запросов от клиента.
  ///
  /// Предоставляет доступ к потоку запросов, получаемых от клиента.
  /// Бизнес-логика может подписаться на этот поток для обработки запросов.
  /// Поток завершается, когда клиент завершает свою часть стрима.
  Stream<TRequest> get requests => _requestController.stream;

  /// Создает новый серверный двунаправленный стрим.
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "ChatService")
  /// [methodName] Имя метода (например, "Connect")
  /// [requestCodec] Кодек для десериализации запросов
  /// [responseCodec] Кодек для сериализации ответов
  /// [logger] Опциональный логгер
  BidirectionalStreamResponder({
    this.id = 0,
    required IRpcTransport transport,
    required this.serviceName,
    required this.methodName,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    RpcLogger? logger,
  })  : _transport = transport,
        _requestSerializer = requestCodec,
        _responseSerializer = responseCodec {
    _logger = logger?.child('BidirectionalResponder');
    _parser = RpcMessageParser(logger: _logger);
    _methodPath = '/$serviceName/$methodName';
    _logger?.info('Создан серверный двунаправленный стрим для $_methodPath');
    unawaited(_setupStreams());
  }

  /// Настраивает потоки данных для обработки запросов и отправки ответов.
  ///
  /// 1. Слушает все входящие сообщения и реагирует на новые Stream ID
  /// 2. Настраивает пайплайн для отправки ответов
  /// 3. Настраивает обработку входящих сообщений от клиента
  Future<void> _setupStreams() async {
    _logger?.debug('Настройка обработки сообщений для $_methodPath');

    // Слушаем ВСЕ входящие сообщения для обнаружения новых вызовов
    _transport.incomingMessages.listen(
      (message) async {
        // Если это новый Stream ID и метаданные, проверяем путь метода
        if (message.isMetadataOnly &&
            message.metadata != null &&
            _activeStreamId == null) {
          // Проверяем, что это вызов нашего метода
          if (message.methodPath == _methodPath) {
            _activeStreamId = message.streamId;
            _logger?.debug(
                'Новый вызов $_methodPath на stream ${message.streamId}');

            // Отправляем начальные заголовки в ответ
            final initialHeaders = RpcMetadata.forServerInitialResponse();
            await _transport.sendMetadata(_activeStreamId!, initialHeaders);
            _logger?.debug(
                'Начальные заголовки отправлены для $_methodPath [streamId: ${message.streamId}]');

            // Настраиваем отправку ответов для этого stream
            _responseController.stream.listen(
              (response) async {
                _logger?.debug(
                    'Отправка ответа для $_methodPath [streamId: ${message.streamId}]');
                final serialized = _responseSerializer.serialize(response);
                _logger?.debug(
                    'Ответ сериализован, размер: ${serialized.length} байт [streamId: ${message.streamId}]');
                final framedMessage = RpcMessageFrame.encode(serialized);
                await _transport.sendMessage(_activeStreamId!, framedMessage);
                _logger?.debug(
                  'Ответ фреймирован и отправлен, размер: ${framedMessage.length} байт [streamId: ${message.streamId}]',
                );
              },
              onDone: () async {
                // Отправляем трейлер при завершении отправки ответов
                _logger?.info(
                    'Завершение отправки ответов для $_methodPath [streamId: ${message.streamId}]');
                final trailers = RpcMetadata.forTrailer(RpcStatus.OK);
                await _transport.sendMetadata(_activeStreamId!, trailers,
                    endStream: true);
                _logger?.debug(
                    'Трейлер отправлен для $_methodPath [streamId: ${message.streamId}]');
              },
              onError: (Object e, StackTrace stackTrace) {
                _logger?.error(
                    'Ошибка при отправке ответа для $_methodPath [streamId: ${message.streamId}]',
                    error: e,
                    stackTrace: stackTrace);
              },
            );
          } else {
            // Это не наш метод, игнорируем
            _logger?.debug(
                'Игнорируем вызов ${message.methodPath}, ожидаем $_methodPath [streamId: ${message.streamId}]');
            return;
          }
        }

        // Обрабатываем данные только для нашего активного stream
        if (message.streamId == _activeStreamId) {
          if (!message.isMetadataOnly && message.payload != null) {
            // Обрабатываем сообщения
            final messageBytes = message.payload!;
            _logger?.debug(
              'Получено сообщение от клиента размером: ${messageBytes.length} байт [streamId: ${message.streamId}]',
            );
            final messages = _parser(messageBytes);
            _logger?.debug(
                'Парсер извлек ${messages.length} сообщений из фрейма [streamId: ${message.streamId}]');

            for (var msgBytes in messages) {
              try {
                _logger?.debug(
                    'Десериализация запроса размером ${msgBytes.length} байт [streamId: ${message.streamId}]');
                final request = _requestSerializer.deserialize(msgBytes);
                _requestController.add(request);
                _logger?.debug(
                    'Запрос десериализован и добавлен в поток запросов [streamId: ${message.streamId}]');
              } catch (e, stackTrace) {
                _logger?.error(
                    'Ошибка при десериализации запроса [streamId: ${message.streamId}]',
                    error: e,
                    stackTrace: stackTrace);
                _requestController.addError(e, stackTrace);
              }
            }
          }

          // Если это конец потока запросов, закрываем контроллер
          if (message.isEndOfStream) {
            _logger?.debug(
                'Получен END_STREAM, закрываем контроллер запросов [streamId: ${message.streamId}]');
            _requestController.close();
          }
        }
      },
      onError: (error, stackTrace) {
        _logger?.error('Ошибка от транспорта: $error',
            error: error, stackTrace: stackTrace);
        _requestController.addError(error, stackTrace);
        _requestController.close();
        if (_activeStreamId != null) {
          sendError(RpcStatus.INTERNAL, 'Внутренняя ошибка: $error');
        }
      },
      onDone: () {
        _logger?.debug('Транспорт завершил поток сообщений для $_methodPath');
        if (!_requestController.isClosed) {
          _requestController.close();
        }
      },
    );
  }

  /// Отправляет ответ клиенту.
  ///
  /// Сериализует объект ответа и отправляет его клиенту.
  /// Ответы можно отправлять в любом порядке и в любое время,
  /// пока не вызван метод finishSending().
  ///
  /// [response] Объект ответа для отправки
  Future<void> send(TResponse response) async {
    if (_activeStreamId == null) {
      _logger?.warning(
          'Попытка отправить ответ без активного соединения для $_methodPath');
      return;
    }

    if (!_responseController.isClosed) {
      _logger?.debug(
          'Отправка ответа в стрим $_methodPath [streamId: $_activeStreamId]');
      _responseController.add(response);
    } else {
      _logger?.warning(
          'Попытка отправить ответ в закрытый стрим $_methodPath [streamId: $_activeStreamId]');
    }
  }

  /// Отправляет сообщение об ошибке клиенту.
  ///
  /// Завершает поток с указанным кодом ошибки gRPC и текстовым сообщением.
  /// После вызова этого метода стрим завершается и новые ответы
  /// отправлять невозможно.
  ///
  /// [statusCode] Код ошибки gRPC (см. GrpcStatus)
  /// [message] Текстовое сообщение с описанием ошибки
  Future<void> sendError(int statusCode, String message) async {
    if (_activeStreamId == null) {
      _logger?.warning(
          'Попытка отправить ошибку без активного соединения для $_methodPath');
      return;
    }

    _logger?.error(
        'Отправка ошибки клиенту: $statusCode - $message [streamId: $_activeStreamId]');

    if (!_responseController.isClosed) {
      _responseController.close();
    }

    final trailers = RpcMetadata.forTrailer(statusCode, message: message);
    await _transport.sendMetadata(_activeStreamId!, trailers, endStream: true);
    _logger?.debug(
        'Трейлер с ошибкой отправлен клиенту [streamId: $_activeStreamId]');
  }

  /// Завершает отправку ответов.
  ///
  /// Сигнализирует клиенту, что сервер закончил отправку ответов.
  /// Автоматически отправляет трейлер с успешным статусом.
  /// После вызова этого метода новые ответы отправлять нельзя.
  Future<void> finishReceiving() async {
    if (!_responseController.isClosed) {
      _logger?.info(
          'Завершение отправки ответов для $_methodPath [streamId: $_activeStreamId]');
      await _responseController.close();
    } else {
      _logger?.debug(
          'Попытка завершить уже закрытый поток ответов $_methodPath [streamId: $_activeStreamId]');
    }
  }

  /// Закрывает стрим и освобождает ресурсы.
  ///
  /// Полностью завершает двунаправленный стрим:
  /// - Завершает отправку ответов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки
  Future<void> close() async {
    _logger?.info(
        'Закрытие двунаправленного стрима сервера $_methodPath [streamId: $_activeStreamId]');

    // Если нет активного соединения, просто закрываем контроллеры
    if (_activeStreamId == null) {
      if (!_requestController.isClosed) {
        _requestController.close();
      }
      if (!_responseController.isClosed) {
        _responseController.close();
      }
      return;
    }

    // Если есть активное соединение, корректно завершаем его
    await finishReceiving();
    // Не закрываем транспорт, так как он может использоваться другими стримами
  }
}
