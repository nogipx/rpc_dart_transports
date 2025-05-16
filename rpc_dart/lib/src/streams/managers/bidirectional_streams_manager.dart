// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

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

  // Флаг, указывающий, что менеджер закрыт
  bool _isDisposed = false;

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
    if (_isDisposed || _mainOutputController.isClosed) return;

    final wrappedResponse = StreamMessage<Response>(
      message: response,
      streamId: 'broadcast',
      metadata: metadata,
    );
    _mainOutputController.add(wrappedResponse);
  }

  /// Публикация уже обернутого ответа
  ///
  /// Для случаев, когда ответ уже подготовлен как StreamMessage.
  void publishWrappedResponse(StreamMessage<Response> wrappedResponse) {
    if (_isDisposed || _mainOutputController.isClosed) return;

    _mainOutputController.add(wrappedResponse);
  }

  /// Создание нового двунаправленного стрима для клиента
  ///
  /// Возвращает объект, который реализует Stream<Response> и имеет метод send()
  /// для отправки сообщений Request.
  BidiStreamInterface<Request, Response> createClientBidiStream() {
    if (_isDisposed) {
      throw StateError('BidirectionalStreamsManager уже закрыт');
    }

    final clientId = 'bidi_stream_${_streamCounter++}';
    final creationTime = DateTime.now();

    // Создаем стрим контроллеры для входящих и исходящих сообщений
    final clientOutputController = StreamController<Response>.broadcast();
    final clientInputController = StreamController<Request>();

    // Подписываемся на основной выходной стрим и передаем данные клиенту
    final outputSubscription = _mainOutputController.stream.listen(
      (wrappedResponse) {
        // Проверяем, подходит ли сообщение для этого клиента
        if ((wrappedResponse.streamId == clientId ||
                wrappedResponse.streamId == 'broadcast') &&
            !clientOutputController.isClosed) {
          try {
            // Отправляем клиенту оригинальное сообщение (без обертки)
            clientOutputController.add(wrappedResponse.message);

            // Обновляем время активности
            final wrapper = _clientStreams[clientId];
            wrapper?.updateLastActivity();
          } catch (e) {
            RpcLog.error(
              message: 'Ошибка при отправке ответа клиенту',
              source: 'BidirectionalStreamsManager',
              error: {'error': e.toString()},
            );
          }
        }
      },
      onError: (error, stackTrace) {
        if (!clientOutputController.isClosed) {
          try {
            clientOutputController.addError(error, stackTrace);
          } catch (e) {
            RpcLog.error(
              message: 'Ошибка при передаче ошибки клиенту',
              source: 'BidirectionalStreamsManager',
              error: {'error': e.toString()},
            );
          }
        }
      },
      onDone: () {
        if (!clientOutputController.isClosed) {
          clientOutputController.close().catchError((e) {
            RpcLog.error(
              message: 'Ошибка при закрытии outputController',
              source: 'BidirectionalStreamsManager',
              error: {'error': e.toString()},
            );
          });
        }
      },
    );

    // Функция отправки сообщений от клиента
    void sendFunction(Request request) {
      if (_isDisposed || clientInputController.isClosed) return;

      try {
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
      } catch (e) {
        RpcLog.error(
          message: 'Ошибка при отправке запроса',
          source: 'BidirectionalStreamsManager',
          error: {'error': e.toString()},
        );
      }
    }

    // Функция закрытия клиентского стрима
    Future<void> closeFunction() async {
      try {
        await outputSubscription.cancel();
      } catch (e) {
        RpcLog.error(
          message: 'Ошибка при отмене подписки',
          source: 'BidirectionalStreamsManager',
          error: {'error': e.toString()},
        );
      }

      try {
        if (!clientInputController.isClosed) {
          await clientInputController.close();
        }
      } catch (e) {
        RpcLog.error(
          message: 'Ошибка при закрытии inputController',
          source: 'BidirectionalStreamsManager',
          error: {'error': e.toString()},
        );
      }

      try {
        if (!clientOutputController.isClosed) {
          await clientOutputController.close();
        }
      } catch (e) {
        RpcLog.error(
          message: 'Ошибка при закрытии outputController',
          source: 'BidirectionalStreamsManager',
          error: {'error': e.toString()},
        );
      }

      _clientStreams.remove(clientId);
    }

    // Создаем двунаправленный стрим
    final bidiStream = BidiStreamInterface<Request, Response>(
      stream: clientOutputController.stream,
      sendFunction: sendFunction,
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
      _isDisposed ? Stream.empty() : _mainInputController.stream;

  /// Отправка ответа конкретному клиенту
  ///
  /// Ответ автоматически оборачивается в StreamMessage с ID клиента.
  void sendResponseToClient(String clientId, Response response,
      {Map<String, dynamic>? metadata}) {
    if (_isDisposed) return;

    final wrapper = _clientStreams[clientId];
    if (wrapper != null && !wrapper.outputController.isClosed) {
      try {
        // Отправляем в основной поток для общего мониторинга/логирования
        final wrappedResponse = StreamMessage<Response>(
          message: response,
          streamId: clientId,
          metadata: metadata,
        );

        if (!_mainOutputController.isClosed) {
          _mainOutputController.add(wrappedResponse);
        }

        // Обновляем время активности
        wrapper.updateLastActivity();
      } catch (e) {
        RpcLog.error(
          message: 'Ошибка при отправке ответа клиенту $clientId',
          source: 'BidirectionalStreamsManager',
          error: {'error': e.toString()},
        );
      }
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
    if (_isDisposed) return;

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
    if (_isDisposed) return;

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
    if (_isDisposed) return;

    final wrapper = _clientStreams.remove(clientId);
    if (wrapper != null) {
      await wrapper.dispose();
    }
  }

  /// Закрытие всех клиентских соединений
  Future<void> closeAllClientStreams() async {
    if (_isDisposed) return;

    final clientIds = _clientStreams.keys.toList();
    for (final clientId in clientIds) {
      await closeClientStream(clientId);
    }
  }

  /// Закрытие неактивных соединений
  ///
  /// Закрывает соединения с клиентами, которые не проявляли активность
  /// в течение указанного периода времени.
  Future<int> closeInactiveStreams(Duration inactivityThreshold) async {
    if (_isDisposed) return 0;

    final inactiveIds = getInactiveClientIds(inactivityThreshold);
    for (final clientId in inactiveIds) {
      await closeClientStream(clientId);
    }
    return inactiveIds.length;
  }

  /// Освобождение всех ресурсов
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Закрываем все клиентские стримы
    await closeAllClientStreams();

    // Закрываем основные контроллеры
    try {
      if (!_mainInputController.isClosed) {
        await _mainInputController.close();
      }
    } catch (e) {
      RpcLog.error(
        message: 'Ошибка при закрытии _mainInputController',
        source: 'BidirectionalStreamsManager',
        error: {'error': e.toString()},
      );
    }

    try {
      if (!_mainOutputController.isClosed) {
        await _mainOutputController.close();
      }
    } catch (e) {
      RpcLog.error(
        message: 'Ошибка при закрытии _mainOutputController',
        source: 'BidirectionalStreamsManager',
        error: {'error': e.toString()},
      );
    }
  }
}

/// Внутренний класс для хранения информации о клиентском стриме
class _EnhancedBidiStreamWrapper<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  final BidiStreamInterface<Request, Response> stream;
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
    try {
      await outputSubscription.cancel();
    } catch (e) {
      RpcLog.error(
        message: 'Ошибка при отмене подписки',
        source: 'BidirectionalStreamsManager',
        error: {'error': e.toString()},
      );
    }

    try {
      if (!inputController.isClosed) {
        await inputController.close();
      }
    } catch (e) {
      RpcLog.error(
        message: 'Ошибка при закрытии inputController',
        source: 'BidirectionalStreamsManager',
        error: {'error': e.toString()},
      );
    }

    try {
      if (!outputController.isClosed) {
        await outputController.close();
      }
    } catch (e) {
      RpcLog.error(
        message: 'Ошибка при закрытии outputController',
        source: 'BidirectionalStreamsManager',
        error: {'error': e.toString()},
      );
    }
  }
}
