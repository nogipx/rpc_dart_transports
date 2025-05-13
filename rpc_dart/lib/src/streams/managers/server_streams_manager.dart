part of '../_index.dart';

/// Универсальный менеджер для управления стримами и их трансляции клиентам
///
/// Позволяет создавать "материнский" стрим, от которого затем создаются
/// дочерние стримы для клиентов. При публикации события в основной стрим,
/// оно автоматически транслируется во все дочерние стримы.
///
/// Эта версия поддерживает автоматическое оборачивание сообщений в [StreamMessage]
/// для включения метаданных о клиентском стриме.
class ServerStreamsManager<T extends IRpcSerializableMessage> {
  // Основной контроллер для публикации данных
  final _mainController = StreamController<StreamMessage<T>>.broadcast();

  // Хранилище активных клиентских стримов
  final _clientStreams = <String, _ClientStreamWrapper<T>>{};

  // Счетчик для генерации клиентских ID
  int _streamCounter = 0;

  // Флаг закрытия менеджера
  bool _isDisposed = false;

  /// Публикация данных во все активные стримы
  ///
  /// Сообщение автоматически оборачивается в [StreamMessage] и
  /// отправляется всем клиентам.
  void publish(T event, {Map<String, dynamic>? metadata}) {
    if (_isDisposed || _mainController.isClosed) return;

    // Отправляем в основной контроллер с общим ID для broadcast
    final wrappedEvent = StreamMessage<T>(
      message: event,
      streamId: 'broadcast',
      metadata: metadata,
    );
    _mainController.add(wrappedEvent);
  }

  /// Создание нового стрима для клиента
  ///
  /// Возвращаемый стрим имеет расширенный функционал [ServerStreamingBidiStream]
  /// для поддержки двунаправленного взаимодействия
  ServerStreamingBidiStream<T, R>
      createClientStream<R extends IRpcSerializableMessage>() {
    if (_isDisposed) {
      throw StateError('ServerStreamsManager уже закрыт');
    }

    final clientId = 'stream_${_streamCounter++}';
    final clientController = StreamController<T>.broadcast();

    // Подписываемся на основной стрим и передаем данные в клиентский контроллер
    final subscription = _mainController.stream.listen(
      (wrappedEvent) {
        if (!clientController.isClosed &&
            (wrappedEvent.streamId == 'broadcast' ||
                wrappedEvent.streamId == clientId)) {
          try {
            // Извлекаем оригинальное сообщение из обертки
            clientController.add(wrappedEvent.message);

            // Обновляем время активности
            final wrapper = _clientStreams[clientId];
            wrapper?.updateLastActivity();
          } catch (e) {
            streamLogger.error('Ошибка при отправке данных клиенту', e);
          }
        }
      },
      onError: (error, stackTrace) {
        if (!clientController.isClosed) {
          try {
            clientController.addError(error, stackTrace);
          } catch (e) {
            streamLogger.error('Ошибка при передаче ошибки клиенту', e);
          }
        }
      },
      onDone: () {
        if (!clientController.isClosed) {
          clientController.close().catchError((e) {
            streamLogger.error(
                'Ошибка при закрытии клиентского контроллера', e);
          });
        }
      },
    );

    // Функция обработки запросов от клиента
    void sendFunction(R request) {
      // Если необходимо, можно добавить обработку запроса здесь
      // Например, вызвать глобальный обработчик запросов или отправить событие

      // Обновляем время последней активности
      final wrapper = _clientStreams[clientId];
      wrapper?.updateLastActivity();
    }

    // Сохраняем информацию о клиентском стриме
    _clientStreams[clientId] = _ClientStreamWrapper(
      controller: clientController,
      subscription: subscription,
      clientId: clientId,
      createdAt: DateTime.now(),
    );

    // Создаем и возвращаем обертку с расширенным API
    return ServerStreamingBidiStream<T, R>(
      stream: clientController.stream,
      closeFunction: () => closeClientStream(clientId),
      sendFunction: sendFunction,
    );
  }

  /// Прямая публикация в конкретный стрим клиента
  ///
  /// Сообщение автоматически оборачивается в [StreamMessage] с ID клиента.
  void publishToClient(String clientId, T event,
      {Map<String, dynamic>? metadata}) {
    if (_isDisposed) return;

    final wrapper = _clientStreams[clientId];
    if (wrapper != null && !wrapper.controller.isClosed) {
      try {
        // Создаем обернутое сообщение
        final wrappedEvent = StreamMessage<T>(
          message: event,
          streamId: clientId,
          metadata: metadata,
        );

        // Добавляем в основной контроллер для логирования и передачи конкретному клиенту
        if (!_mainController.isClosed) {
          _mainController.add(wrappedEvent);
        }

        // Обновляем время последней активности
        wrapper.updateLastActivity();
      } catch (e) {
        streamLogger.error('Ошибка при публикации данных клиенту $clientId', e);
      }
    }
  }

  /// Публикация обернутого сообщения
  ///
  /// Для случаев, когда сообщение уже оформлено как [StreamMessage]
  void publishWrapped(StreamMessage<T> wrappedEvent) {
    if (_isDisposed || _mainController.isClosed) return;

    _mainController.add(wrappedEvent);
  }

  /// Получение списка идентификаторов активных клиентов
  List<String> getActiveClientIds() {
    return _clientStreams.keys.toList();
  }

  /// Количество активных клиентских стримов
  int get activeClientCount => _clientStreams.length;

  /// Получение информации о клиентском стриме
  // ignore: library_private_types_in_public_api
  _ClientStreamWrapper<T>? getClientInfo(String clientId) {
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

  /// Закрытие конкретного клиентского стрима
  Future<void> closeClientStream(String clientId) async {
    if (_isDisposed) return;

    final wrapper = _clientStreams.remove(clientId);
    if (wrapper != null) {
      await wrapper.dispose();
    }
  }

  /// Закрытие всех клиентских стримов
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

    // Закрываем все клиентские контроллеры
    await closeAllClientStreams();

    // Закрываем основной контроллер
    try {
      if (!_mainController.isClosed) {
        await _mainController.close();
      }
    } catch (e) {
      streamLogger.error('Ошибка при закрытии основного контроллера', e);
    }
  }
}

/// Класс для хранения информации о клиентском стриме
class _ClientStreamWrapper<T extends IRpcSerializableMessage> {
  final StreamController<T> controller;
  final StreamSubscription<StreamMessage<T>> subscription;
  final String clientId;
  final DateTime createdAt;

  /// Время последней активности клиента
  DateTime lastActivity;

  _ClientStreamWrapper({
    required this.controller,
    required this.subscription,
    required this.clientId,
    required this.createdAt,
  }) : lastActivity = DateTime.now();

  /// Обновляет время последней активности
  void updateLastActivity() {
    lastActivity = DateTime.now();
  }

  /// Длительность активности стрима
  Duration getActiveDuration() {
    return DateTime.now().difference(createdAt);
  }

  /// Длительность неактивности стрима
  Duration getInactivityDuration() {
    return DateTime.now().difference(lastActivity);
  }

  /// Освобождение ресурсов
  Future<void> dispose() async {
    try {
      await subscription.cancel();
    } catch (e) {
      streamLogger.error('Ошибка при отмене подписки', e);
    }

    try {
      if (!controller.isClosed) {
        await controller.close();
      }
    } catch (e) {
      streamLogger.error('Ошибка при закрытии контроллера', e);
    }
  }
}
