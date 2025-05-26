// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Серверная часть унарного вызова с поддержкой Stream ID.
///
/// Обрабатывает один запрос и отправляет один ответ.
/// Предоставляет простой API для реализации обработчиков унарных RPC методов.
/// Поддерживает автоматическое мультиплексирование по serviceName/methodName и Stream ID.
///
/// Пример использования:
/// ```dart
/// final server = UnaryServer<String, String>(
///   transport: transport,
///   serviceName: 'GreetingService',
///   methodName: 'SayHello',
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
///   handler: (request) async {
///     return "Эхо: $request";
///   }
/// );
/// ```
final class UnaryResponder<TRequest, TResponse> implements IRpcResponder {
  /// Транспорт для коммуникации
  final IRpcTransport _transport;

  @override
  final int id;

  /// Имя сервиса
  final String _serviceName;

  /// Имя метода
  final String _methodName;

  /// Путь метода в формате /<ServiceName>/<MethodName>
  late final String _methodPath;

  /// Сериализатор запросов
  final IRpcCodec<TRequest> _requestSerializer;

  /// Сериализатор ответов
  final IRpcCodec<TResponse> _responseSerializer;

  /// Логгер
  late final RpcLogger? _logger;

  /// Парсер для обработки фрагментированных сообщений
  late final RpcMessageParser _parser;

  /// Подписка на входящие сообщения
  StreamSubscription? _subscription;

  /// Создает сервер унарного вызова
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "GreetingService")
  /// [methodName] Имя метода (например, "SayHello")
  /// [requestCodec] Кодек для десериализации запроса
  /// [responseCodec] Кодек для сериализации ответа
  /// [handler] Функция-обработчик, вызываемая при получении запроса
  /// [logger] Опциональный логгер
  UnaryResponder({
    this.id = 0,
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    required FutureOr<TResponse> Function(TRequest request) handler,
    RpcLogger? logger,
  })  : _transport = transport,
        _serviceName = serviceName,
        _methodName = methodName,
        _requestSerializer = requestCodec,
        _responseSerializer = responseCodec {
    _logger = logger?.child('UnaryResponder');
    _parser = RpcMessageParser(logger: _logger);
    _methodPath = '/$_serviceName/$_methodName';
    _logger?.info('Создан унарный сервер для $_methodPath');
    _setupRequestHandler(handler);
  }

  void _setupRequestHandler(
    FutureOr<TResponse> Function(TRequest) handler,
  ) {
    _logger?.debug('Настройка обработчика запросов для $_methodPath');

    // Отслеживаем активные streams для этого метода
    final Map<int, bool> streamRequestHandled = <int, bool>{};
    final Map<int, bool> streamInitialHeadersSent = <int, bool>{};
    final Map<int, bool> streamBelongsToThisMethod = <int, bool>{};

    _subscription = _transport.incomingMessages.listen(
      (message) async {
        final streamId = message.streamId;

        // Если это метаданные, проверяем принадлежность к нашему методу
        if (message.isMetadataOnly && message.metadata != null) {
          if (message.methodPath == _methodPath) {
            streamBelongsToThisMethod[streamId] = true;
            _logger?.debug(
                'Унарный сервер: stream $streamId привязан к методу $_methodPath');
          }
          return; // Метаданные только регистрируем, но не обрабатываем
        }

        // Для сообщений с данными проверяем принадлежность к нашему методу
        if (!streamBelongsToThisMethod.containsKey(streamId)) {
          return; // Этот stream не для нашего метода
        }

        if (streamRequestHandled[streamId] == true) {
          // Игнорируем дополнительные сообщения после обработки первого запроса
          _logger?.debug(
              'Игнорируем дополнительное сообщение для stream $streamId (запрос уже обработан)');
          return;
        }

        if (!message.isMetadataOnly && message.payload != null) {
          streamRequestHandled[streamId] = true;
          _logger
              ?.info('Получен запрос для $_methodPath [streamId: $streamId]');

          try {
            // Отправляем начальные заголовки, если еще не отправляли
            if (streamInitialHeadersSent[streamId] != true) {
              _logger?.debug(
                  'Отправка начальных заголовков [streamId: $streamId]');
              await _transport.sendMetadata(
                streamId,
                RpcMetadata.forServerInitialResponse(),
              );
              streamInitialHeadersSent[streamId] = true;
            }

            // Десериализуем запрос
            // Используем парсер для извлечения сообщений из фрейма с префиксом
            _logger?.debug(
                'Парсинг фрейма запроса размером ${message.payload!.length} байт [streamId: $streamId]');
            final messages = _parser(message.payload!);
            if (messages.isEmpty) {
              _logger?.error(
                  'Не удалось извлечь сообщение из payload [streamId: $streamId]');
              throw Exception('Не удалось извлечь сообщение из payload');
            }

            _logger?.debug('Десериализация запроса [streamId: $streamId]');
            final request = _requestSerializer.deserialize(messages.first);

            _logger?.debug(
                'Обработка запроса для $_methodPath [streamId: $streamId]');

            // Обрабатываем запрос
            final response = await handler(request);
            _logger?.debug(
                'Запрос обработан, подготовка ответа [streamId: $streamId]');

            // Сериализуем и отправляем ответ
            _logger?.debug('Сериализация ответа [streamId: $streamId]');
            final serializedResponse = _responseSerializer.serialize(response);
            _logger?.debug(
                'Ответ сериализован, размер: ${serializedResponse.length} байт [streamId: $streamId]');
            final framedResponse = RpcMessageFrame.encode(serializedResponse);
            _logger?.debug('Отправка ответа [streamId: $streamId]');
            await _transport.sendMessage(
              streamId,
              framedResponse,
            );

            // Отправляем трейлер с успешным статусом
            _logger?.debug(
                'Отправка трейлера с успешным статусом [streamId: $streamId]');
            await _transport.sendMetadata(
              streamId,
              RpcMetadata.forTrailer(RpcStatus.OK),
              endStream: true,
            );

            _logger?.info(
                'Ответ успешно отправлен для $_methodPath [streamId: $streamId]');
          } catch (e, stackTrace) {
            _logger?.error(
              'Ошибка при обработке запроса [streamId: $streamId]',
              error: e,
              stackTrace: stackTrace,
            );

            // Отправляем начальные заголовки, если еще не отправляли
            if (streamInitialHeadersSent[streamId] != true) {
              await _transport.sendMetadata(
                streamId,
                RpcMetadata.forServerInitialResponse(),
              );
              streamInitialHeadersSent[streamId] = true;
            }

            // При ошибке отправляем трейлер с кодом ошибки
            _logger?.debug('Отправка трейлера с ошибкой [streamId: $streamId]');
            await _transport.sendMetadata(
              streamId,
              RpcMetadata.forTrailer(
                RpcStatus.INTERNAL,
                message: 'Ошибка при обработке запроса: $e',
              ),
              endStream: true,
            );
          } finally {
            // Очищаем состояние для этого stream
            _logger?.debug('Очистка состояния для stream $streamId');
            streamRequestHandled.remove(streamId);
            streamInitialHeadersSent.remove(streamId);
            streamBelongsToThisMethod.remove(streamId);
          }
        }

        // Если клиент закрыл поток без отправки данных
        if (message.isEndOfStream &&
            streamBelongsToThisMethod[streamId] == true &&
            streamRequestHandled[streamId] != true) {
          streamRequestHandled[streamId] = true;
          _logger?.warning(
              'Клиент закрыл поток без отправки данных [streamId: $streamId]');

          // Отправляем трейлер с ошибкой
          await _transport.sendMetadata(
            streamId,
            RpcMetadata.forTrailer(
              RpcStatus.INVALID_ARGUMENT,
              message: 'Запрос не получен: поток закрыт без данных',
            ),
            endStream: true,
          );

          // Очищаем состояние для этого stream
          streamRequestHandled.remove(streamId);
          streamInitialHeadersSent.remove(streamId);
          streamBelongsToThisMethod.remove(streamId);
        }
      },
      onError: (error, stackTrace) async {
        _logger?.error(
          'Ошибка в транспорте для $_methodPath',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Закрывает сервер и освобождает ресурсы
  ///
  /// ВНИМАНИЕ: Не закрывает транспорт, так как он может использоваться
  /// другими серверами. Транспорт должен закрываться явно.
  Future<void> close() async {
    _logger?.info('Закрытие унарного сервера $_methodPath');
    await _subscription?.cancel();
    _logger?.debug('Отменена подписка на входящие сообщения');
  }
}
