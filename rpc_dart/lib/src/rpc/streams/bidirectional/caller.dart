// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Клиентская реализация двунаправленного стрима gRPC со Stream ID.
///
/// Обеспечивает полную реализацию клиентской стороны двунаправленного
/// стриминга (Bidirectional Streaming RPC). Позволяет клиенту отправлять
/// поток запросов серверу и одновременно получать поток ответов.
/// Каждый стрим использует уникальный Stream ID согласно gRPC спецификации.
///
/// Особенности:
/// - Асинхронный обмен сообщениями в обоих направлениях
/// - Потоковый интерфейс для отправки и получения (через Stream)
/// - Автоматическая сериализация/десериализация сообщений
/// - Корректная обработка заголовков и трейлеров gRPC
final class BidirectionalStreamCaller<TRequest, TResponse> {
  late final RpcLogger? _logger;

  /// Базовый транспорт для обмена данными
  final IRpcTransport _transport;

  /// Уникальный Stream ID для этого RPC вызова
  late final int _streamId;

  /// Имя сервиса
  final String _serviceName;

  /// Имя метода
  final String _methodName;

  /// Путь метода в формате /ServiceName/MethodName
  late final String _methodPath;

  /// Кодек для сериализации исходящих запросов
  final IRpcCodec<TRequest> _requestSerializer;

  /// Кодек для десериализации входящих ответов
  final IRpcCodec<TResponse> _responseSerializer;

  /// Контроллер потока исходящих запросов
  final StreamController<TRequest> _requestController =
      StreamController<TRequest>();

  /// Контроллер потока входящих ответов
  final StreamController<RpcMessage<TResponse>> _responseController =
      StreamController<RpcMessage<TResponse>>();

  /// Парсер для обработки фрагментированных сообщений
  late final RpcMessageParser _parser;

  /// Поток для отправки запросов (для внутреннего использования)
  StreamConsumer<TRequest> get requests => _requestController;

  /// Поток входящих ответов от сервера.
  ///
  /// Предоставляет доступ к потоку ответов, получаемых от сервера.
  /// Каждый элемент может быть:
  /// - Сообщение с полезной нагрузкой (payload)
  /// - Сообщение с метаданными (metadata)
  ///
  /// Поток завершается при получении трейлера с END_STREAM
  /// или при возникновении ошибки.
  Stream<RpcMessage<TResponse>> get responses => _responseController.stream;

  /// Создает новый клиентский двунаправленный стрим.
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "ChatService")
  /// [methodName] Имя метода (например, "Connect")
  /// [requestCodec] Кодек для сериализации запросов
  /// [responseCodec] Кодек для десериализации ответов
  /// [logger] Опциональный логгер
  BidirectionalStreamCaller({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    RpcLogger? logger,
  })  : _transport = transport,
        _serviceName = serviceName,
        _methodName = methodName,
        _requestSerializer = requestCodec,
        _responseSerializer = responseCodec {
    _logger = logger?.child('BidirectionalCaller');
    _parser = RpcMessageParser(logger: _logger);
    _streamId = _transport.createStream();
    _methodPath = '/$serviceName/$methodName';
    _logger?.info(
        'Создан двунаправленный стрим клиент для $_methodPath [streamId: $_streamId]');
    unawaited(_setupStreams());
  }

  /// Настраивает потоки данных между приложением и транспортом.
  ///
  /// Создает два пайплайна:
  /// 1. От приложения к сети: сериализация и отправка запросов
  /// 2. От сети к приложению: получение, парсинг и десериализация ответов
  Future<void> _setupStreams() async {
    _logger?.debug(
        'Настройка потоков для стрима $_methodPath [streamId: $_streamId]');

    // Отправляем начальные метаданные для инициализации RPC вызова
    final initialMetadata =
        RpcMetadata.forClientRequest(_serviceName, _methodName);
    await _transport.sendMetadata(_streamId, initialMetadata);
    _logger?.debug(
        'Начальные метаданные отправлены для $_methodPath [streamId: $_streamId]');

    // Настраиваем отправку запросов
    _requestController.stream.listen(
      (request) async {
        _logger?.debug(
            'Получен запрос для отправки в стрим $_methodPath [streamId: $_streamId]');
        final serialized = _requestSerializer.serialize(request);
        _logger?.debug(
            'Запрос сериализован, размер: ${serialized.length} байт [streamId: $_streamId]');
        final framedMessage = RpcMessageFrame.encode(serialized);
        await _transport.sendMessage(_streamId, framedMessage);
        _logger?.debug(
            'Отправлено сообщение через транспорт: размер ${framedMessage.length} байт [streamId: $_streamId]');
      },
      onDone: () async {
        _logger?.debug(
            'Поток запросов завершен, вызываем finishSending() [streamId: $_streamId]');
        await _transport.finishSending(_streamId);
        _logger?.info(
            'Отправка запросов завершена для $_methodPath [streamId: $_streamId]');
      },
      onError: (Object e, StackTrace stackTrace) {
        _logger?.error(
            'Ошибка в потоке запросов для $_methodPath [streamId: $_streamId]',
            error: e,
            stackTrace: stackTrace);
      },
    );

    add(RpcMessage<TResponse> response) {
      if (!_responseController.isClosed) {
        _logger?.debug(
            'Добавление ответа в поток $_methodPath [streamId: $_streamId]');
        _responseController.add(response);
      } else {
        _logger?.warning(
            'Попытка добавить ответ в закрытый контроллер $_methodPath [streamId: $_streamId]');
      }
    }

    error(Object error, [StackTrace? stackTrace]) {
      if (!_responseController.isClosed) {
        _logger?.error(
            'Добавление ошибки в поток ответов $_methodPath [streamId: $_streamId]',
            error: error,
            stackTrace: stackTrace);
        _responseController.addError(error, stackTrace);
      } else {
        _logger?.warning(
            'Попытка добавить ошибку в закрытый контроллер $_methodPath [streamId: $_streamId]');
      }
    }

    done() async {
      if (!_responseController.isClosed) {
        _logger?.info(
            'Закрытие потока ответов $_methodPath [streamId: $_streamId]');
        await _responseController.close();
      }
    }

    // Настраиваем прием ответов для нашего stream
    _transport.getMessagesForStream(_streamId).listen(
      (message) async {
        if (message.isMetadataOnly) {
          // Обрабатываем метаданные
          final statusCode =
              message.metadata?.getHeaderValue(RpcConstants.GRPC_STATUS_HEADER);

          if (statusCode != null) {
            _logger?.debug(
                'Получен статус: $statusCode для $_methodPath [streamId: $_streamId]');
          } else {
            _logger?.debug(
                'Получены метаданные от транспорта для $_methodPath [streamId: $_streamId]');
          }

          if (statusCode != null) {
            // Это трейлер, проверяем статус
            final code = int.parse(statusCode);
            if (code != RpcStatus.OK) {
              final errorMessage = message.metadata
                      ?.getHeaderValue(RpcConstants.GRPC_MESSAGE_HEADER) ??
                  '';
              _logger?.error(
                  'Ошибка gRPC: $code - $errorMessage для $_methodPath [streamId: $_streamId]');
              error(Exception('gRPC error $code: $errorMessage'));
            } else {
              _logger?.debug(
                  'Получен успешный статус завершения для $_methodPath [streamId: $_streamId]');
            }

            if (message.isEndOfStream) {
              _logger?.debug(
                  'Получен END_STREAM, закрываем контроллер $_methodPath [streamId: $_streamId]');
              await done();
            }
          }

          // Передаем метаданные в поток ответов
          final metadataMessage = RpcMessage<TResponse>(
            metadata: message.metadata,
            isMetadataOnly: true,
            isEndOfStream: message.isEndOfStream,
          );

          add(metadataMessage);
        } else if (message.payload != null) {
          // Обрабатываем сообщения
          final messageBytes = message.payload!;
          _logger?.debug(
            'Получено сообщение от транспорта размером: ${messageBytes.length} байт для $_methodPath [streamId: $_streamId]',
          );

          final messages = _parser(messageBytes);
          _logger?.debug(
              'Парсер извлек ${messages.length} сообщений из фрейма для $_methodPath [streamId: $_streamId]');

          for (var msgBytes in messages) {
            try {
              _logger?.debug(
                  'Десериализация сообщения размером ${msgBytes.length} байт для $_methodPath [streamId: $_streamId]');
              final response = _responseSerializer.deserialize(msgBytes);
              final responseMessage = RpcMessage.withPayload(response);
              add(responseMessage);
            } catch (e, stackTrace) {
              _logger?.error(
                'Ошибка при десериализации сообщения для $_methodPath [streamId: $_streamId]: $e',
                error: e,
                stackTrace: stackTrace,
              );
              error(e, stackTrace);
            }
          }
        }
      },
      onError: (e, stackTrace) async {
        _logger?.error(
          'Ошибка от транспорта для $_methodPath [streamId: $_streamId]: $e',
          error: e,
          stackTrace: stackTrace,
        );
        error(e, stackTrace);
        await done();
      },
      onDone: () async {
        _logger?.debug(
            'Транспорт завершил поток сообщений для $_methodPath [streamId: $_streamId]');
        await done();
      },
    );
  }

  /// Отправляет запрос серверу.
  ///
  /// Сериализует объект запроса и отправляет его серверу через транспорт.
  /// Запросы можно отправлять в любом порядке и в любое время,
  /// пока не вызван метод finishSending().
  ///
  /// [request] Объект запроса для отправки
  Future<void> send(TRequest request) async {
    if (!_requestController.isClosed) {
      _logger?.debug(
          'Отправка запроса в стрим $_methodPath [streamId: $_streamId]');
      _requestController.add(request);
    } else {
      _logger?.warning(
          'Попытка отправить запрос в закрытый стрим $_methodPath [streamId: $_streamId]');
    }
  }

  /// Завершает отправку запросов.
  ///
  /// Сигнализирует серверу, что клиент закончил отправку запросов.
  /// После вызова этого метода новые запросы отправлять нельзя,
  /// но можно продолжать получать ответы от сервера.
  Future<void> finishSending() async {
    if (!_requestController.isClosed) {
      _logger?.info(
          'Завершение отправки запросов для $_methodPath [streamId: $_streamId]');
      await _requestController.close();
    } else {
      _logger?.debug(
          'Попытка завершить уже закрытый поток запросов $_methodPath [streamId: $_streamId]');
    }
  }

  /// Закрывает стрим.
  ///
  /// Полностью завершает двунаправленный стрим, освобождая все ресурсы.
  /// - Завершает отправку запросов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки на события
  Future<void> close() async {
    _logger?.info(
        'Закрытие двунаправленного стрима $_methodPath [streamId: $_streamId]');
    finishSending();
    // Не закрываем транспорт, так как он может использоваться другими стримами
  }
}
