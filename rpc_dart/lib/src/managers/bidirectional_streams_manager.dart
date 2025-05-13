import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'stream_message.dart';

/// Улучшенный менеджер двунаправленных стримов с поддержкой обертки сообщений
///
/// В отличие от базовой версии, этот менеджер автоматически оборачивает запросы
/// в StreamMessage для упрощения маршрутизации ответов и сохранения метаданных.
/// Оба направления (запросы и ответы) поддерживают метаданные и отслеживание.
class BidirectionalStreamsManager<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  // Основной контроллер для публикации общих ответов (теперь тоже обернутых)
  final _mainOutputController =
      StreamController<StreamMessage<Response>>.broadcast();

  // Контроллер для входящих запросов от всех клиентов
  final _mainInputController =
      StreamController<StreamMessage<Request>>.broadcast();

  // Хранилище клиентских стримов
  final _clientStreams =
      <String, _EnhancedBidiStreamWrapper<Request, Response>>{};

  // Счетчик для генерации ID клиентов
  int _streamCounter = 0;

  // Коллбэк для обработки входящих запросов от клиентов
  final void Function(StreamMessage<Request>)? onRequestReceived;

  /// Конструктор улучшенного менеджера двунаправленных стримов
  ///
  /// [onRequestReceived] - опциональный коллбэк, который будет вызван при получении
  /// запроса от клиента. Функция получает StreamMessage с метаданными.
  BidirectionalStreamsManager({this.onRequestReceived});

  /// Публикация ответа во все активные клиентские стримы
  ///
  /// Ответ автоматически оборачивается в StreamMessage с ID 'broadcast'
  /// и отправляется всем подключенным клиентам.
  void publishResponse(Response response, {Map<String, dynamic>? metadata}) {
    if (!_mainOutputController.isClosed) {
      final wrappedResponse = StreamMessage<Response>(
        message: response,
        streamId: 'broadcast',
        metadata: metadata,
      );
      _mainOutputController.add(wrappedResponse);
    }
  }

  /// Публикация уже обернутого ответа
  ///
  /// Для случаев, когда ответ уже подготовлен как StreamMessage.
  void publishWrappedResponse(StreamMessage<Response> wrappedResponse) {
    if (!_mainOutputController.isClosed) {
      _mainOutputController.add(wrappedResponse);
    }
  }

  /// Создание нового двунаправленного стрима для клиента
  BidiStream<Request, Response> createClientBidiStream() {
    final clientId = 'bidi_stream_${_streamCounter++}';
    final creationTime = DateTime.now();

    // Создаем контроллеры для входящих и исходящих сообщений данного клиента
    final clientOutputController = StreamController<Response>.broadcast();
    final clientInputController = StreamController<Request>();

    // Подписываемся на основной выходной стрим и передаем данные клиенту
    final outputSubscription = _mainOutputController.stream.listen(
      (wrappedResponse) {
        if (!clientOutputController.isClosed) {
          // Отправляем клиенту оригинальное сообщение (без обертки)
          clientOutputController.add(wrappedResponse.message);

          // Если это индивидуальное сообщение для этого клиента или broadcast
          if (wrappedResponse.streamId == clientId ||
              wrappedResponse.streamId == 'broadcast') {
            // Обновляем время активности
            final wrapper = _clientStreams[clientId];
            wrapper?.updateLastActivity();
          }
        }
      },
      onError: (error) {
        if (!clientOutputController.isClosed) {
          clientOutputController.addError(error);
        }
      },
    );

    // Создаем обертку для BidiStream
    sendFunction(Request request) {
      if (!clientInputController.isClosed) {
        clientInputController.add(request);

        // Обновляем время активности
        final wrapper = _clientStreams[clientId];
        wrapper?.updateLastActivity();

        // Пересылаем запрос в общий входной поток с оберткой StreamMessage
        if (!_mainInputController.isClosed) {
          final wrappedRequest = StreamMessage<Request>(
            message: request,
            streamId: clientId,
            timestamp: DateTime.now(),
          );

          _mainInputController.add(wrappedRequest);

          // Если есть коллбэк, передаем ему обернутый запрос
          onRequestReceived?.call(wrappedRequest);
        }
      }
    }

    // Функция для завершения передачи
    finishTransferFunction() async {
      // Дополнительная логика может быть добавлена здесь
    }

    // Функция для закрытия стрима
    closeFunction() async {
      await outputSubscription.cancel();

      if (!clientInputController.isClosed) {
        await clientInputController.close();
      }

      if (!clientOutputController.isClosed) {
        await clientOutputController.close();
      }

      _clientStreams.remove(clientId);
    }

    // Создаем BidiStream
    final bidiStream = BidiStream<Request, Response>(
      responseStream: clientOutputController.stream,
      sendFunction: sendFunction,
      finishTransferFunction: finishTransferFunction,
      closeFunction: closeFunction,
    );

    // Сохраняем обертку для управления стримом
    _clientStreams[clientId] = _EnhancedBidiStreamWrapper(
      stream: bidiStream,
      inputController: clientInputController,
      outputController: clientOutputController,
      outputSubscription: outputSubscription,
      clientId: clientId,
      createdAt: creationTime,
    );

    return bidiStream;
  }

  /// Получение потока всех входящих запросов от клиентов с метаданными
  Stream<StreamMessage<Request>> get allRequestsStream =>
      _mainInputController.stream;

  /// Отправка ответа конкретному клиенту
  ///
  /// Ответ автоматически оборачивается в StreamMessage с ID клиента.
  void sendResponseToClient(String clientId, Response response,
      {Map<String, dynamic>? metadata}) {
    final wrapper = _clientStreams[clientId];
    if (wrapper != null && !wrapper.outputController.isClosed) {
      // Отправляем в основной поток для общего мониторинга/логирования
      final wrappedResponse = StreamMessage<Response>(
        message: response,
        streamId: clientId,
        metadata: metadata,
      );

      if (!_mainOutputController.isClosed) {
        _mainOutputController.add(wrappedResponse);
      }

      // Отправляем непосредственно клиенту
      wrapper.outputController.add(response);

      // Обновляем время активности
      wrapper.updateLastActivity();
    }
  }

  /// Отправка ответа нескольким клиентам
  ///
  /// Отправляет одинаковый ответ списку клиентов. Удобно для групповых
  /// сообщений, которые не нужно рассылать всем.
  void sendResponseToClients(
    List<String> clientIds,
    Response response, {
    Map<String, dynamic>? metadata,
  }) {
    for (final clientId in clientIds) {
      sendResponseToClient(clientId, response, metadata: metadata);
    }
  }

  /// Отправка ответа на основе метаданных запроса
  ///
  /// Удобный метод, позволяющий отправить ответ, используя
  /// информацию из обернутого запроса без явного указания ID клиента.
  void replyTo(
    StreamMessage<Request> request,
    Response response, {
    Map<String, dynamic>? metadata,
  }) {
    // Объединяем метаданные запроса с новыми метаданными
    final mergedMetadata = {...?request.metadata, ...?metadata};

    sendResponseToClient(request.streamId, response, metadata: mergedMetadata);
  }

  /// Получение списка ID активных клиентов
  List<String> getActiveClientIds() {
    return _clientStreams.keys.toList();
  }

  /// Получение данных о конкретном клиентском стриме
  // ignore: library_private_types_in_public_api
  _EnhancedBidiStreamWrapper<Request, Response>? getClientStreamInfo(
      String clientId) {
    return _clientStreams[clientId];
  }

  /// Получение списка неактивных клиентов
  ///
  /// Возвращает ID клиентов, которые не проявляли активность дольше указанного времени.
  List<String> getInactiveClientIds(Duration threshold) {
    final now = DateTime.now();
    return _clientStreams.entries
        .where((entry) => now.difference(entry.value.lastActivity) > threshold)
        .map((entry) => entry.key)
        .toList();
  }

  /// Количество активных клиентских стримов
  int get activeClientCount => _clientStreams.length;

  /// Закрытие соединения с конкретным клиентом
  Future<void> closeClientStream(String clientId) async {
    final wrapper = _clientStreams.remove(clientId);
    if (wrapper != null) {
      await wrapper.dispose();
    }
  }

  /// Закрытие всех клиентских соединений
  Future<void> closeAllClientStreams() async {
    for (final clientId in _clientStreams.keys.toList()) {
      await closeClientStream(clientId);
    }
  }

  /// Закрытие неактивных соединений
  ///
  /// Закрывает соединения с клиентами, которые не проявляли активность
  /// в течение указанного периода времени.
  Future<int> closeInactiveStreams(Duration inactivityThreshold) async {
    final inactiveIds = getInactiveClientIds(inactivityThreshold);
    for (final clientId in inactiveIds) {
      await closeClientStream(clientId);
    }
    return inactiveIds.length;
  }

  /// Освобождение всех ресурсов
  Future<void> dispose() async {
    // Закрываем все клиентские стримы
    await closeAllClientStreams();

    // Закрываем основные контроллеры
    if (!_mainInputController.isClosed) {
      await _mainInputController.close();
    }

    if (!_mainOutputController.isClosed) {
      await _mainOutputController.close();
    }
  }
}

/// Внутренний класс для хранения информации о клиентском стриме
class _EnhancedBidiStreamWrapper<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  final BidiStream<Request, Response> stream;
  final StreamController<Request> inputController;
  final StreamController<Response> outputController;
  final StreamSubscription<StreamMessage<Response>> outputSubscription;
  final String clientId;
  final DateTime createdAt;

  /// Время последней активности клиента
  DateTime lastActivity;

  _EnhancedBidiStreamWrapper({
    required this.stream,
    required this.inputController,
    required this.outputController,
    required this.outputSubscription,
    required this.clientId,
    required this.createdAt,
  }) : lastActivity = DateTime.now();

  /// Обновляет время последней активности
  void updateLastActivity() {
    lastActivity = DateTime.now();
  }

  /// Возвращает длительность активности стрима
  Duration getActiveDuration() {
    return DateTime.now().difference(createdAt);
  }

  /// Возвращает длительность с момента последней активности
  Duration getInactivityDuration() {
    return DateTime.now().difference(lastActivity);
  }

  /// Закрытие и очистка ресурсов
  Future<void> dispose() async {
    await outputSubscription.cancel();

    if (!inputController.isClosed) {
      await inputController.close();
    }

    if (!outputController.isClosed) {
      await outputController.close();
    }
  }
}
