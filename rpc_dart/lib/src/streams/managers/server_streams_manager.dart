// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Универсальный менеджер для управления стримами и их трансляции клиентам
///
/// Позволяет создавать "материнский" стрим, от которого затем создаются
/// дочерние стримы для клиентов. При публикации события в основной стрим,
/// оно автоматически транслируется во все дочерние стримы.
///
/// Эта версия поддерживает автоматическое оборачивание сообщений в [StreamMessage]
/// для включения метаданных о клиентском стриме.
class ServerStreamsManager<ResponseType extends IRpcSerializableMessage> {
  // Основной контроллер для публикации данных
  final _mainController =
      StreamController<StreamMessage<ResponseType>>.broadcast();

  // Хранилище активных клиентских стримов
  final _clientStreams = <String, _ClientStreamWrapper<ResponseType>>{};

  // Счетчик для генерации клиентских ID
  int _streamCounter = 0;

  // Флаг закрытия менеджера
  bool _isDisposed = false;

  /// Публикация данных во все активные стримы
  ///
  /// Сообщение автоматически оборачивается в [StreamMessage] и
  /// отправляется всем клиентам.
  void publish(ResponseType event, {Map<String, dynamic>? metadata}) {
    if (_isDisposed || _mainController.isClosed) return;

    // Отправляем в основной контроллер с общим ID для broadcast
    final wrappedEvent = StreamMessage<ResponseType>(
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
  ServerStreamingBidiStream<RequestType, ResponseType>
      createClientStream<RequestType extends IRpcSerializableMessage>() {
    if (_isDisposed) {
      throw StateError('ServerStreamsManager уже закрыт');
    }

    final clientId = 'stream_${_streamCounter++}';
    final clientController = StreamController<ResponseType>.broadcast();

    // Подписываемся на основной стрим и передаем данные в клиентский контроллер
    final subscription = _mainController.stream.listen(
      (wrappedEvent) {
        if (!clientController.isClosed &&
            (wrappedEvent.streamId == 'broadcast' ||
                (wrappedEvent.streamId == clientId &&
                    wrappedEvent.metadata?['type'] != 'clientRequest'))) {
          try {
            // Извлекаем оригинальное сообщение из обертки
            clientController.add(wrappedEvent.message);

            // Обновляем время активности
            final wrapper = _clientStreams[clientId];
            wrapper?.updateLastActivity();
          } catch (e) {
            RpcLog.error(
              message: 'Ошибка при отправке данных клиенту',
              source: 'ServerStreamsManager',
              error: {'error': e.toString()},
            );
          }
        }
      },
      onError: (error, stackTrace) {
        if (!clientController.isClosed) {
          try {
            clientController.addError(error, stackTrace);
          } catch (e) {
            RpcLog.error(
              message: 'Ошибка при передаче ошибки клиенту',
              source: 'ServerStreamsManager',
              error: {'error': e.toString()},
            );
          }
        }
      },
      onDone: () {
        if (!clientController.isClosed) {
          clientController.close().catchError((e) {
            RpcLog.error(
              message: 'Ошибка при закрытии клиентского контроллера',
              source: 'ServerStreamsManager',
              error: {'error': e.toString()},
            );
          });
        }
      },
    );

    // Функция обработки запросов от клиента
    void sendFunction(RequestType request) {
      // Логируем получение запроса от клиента
      RpcLog.debug(
        message: 'Получен запрос от клиента $clientId: ${request.runtimeType}',
        source: 'ServerStreamsManager',
      );

      // Больше не отправляем запросы клиента в основной контроллер
      // Клиенты не могут общаться напрямую, это серверный стриминг

      // Только обновляем время последней активности
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
    return ServerStreamingBidiStream<RequestType, ResponseType>(
      stream: clientController.stream,
      closeFunction: () => closeClientStream(clientId),
      sendFunction: sendFunction,
    );
  }

  /// Прямая публикация в конкретный стрим клиента
  ///
  /// Сообщение автоматически оборачивается в [StreamMessage] с ID клиента.
  void publishToClient(String clientId, ResponseType event,
      {Map<String, dynamic>? metadata}) {
    if (_isDisposed) return;

    final wrapper = _clientStreams[clientId];
    if (wrapper != null && !wrapper.controller.isClosed) {
      try {
        // Создаем обернутое сообщение
        final wrappedEvent = StreamMessage<ResponseType>(
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
        RpcLog.error(
          message: 'Ошибка при публикации данных клиенту $clientId',
          source: 'ServerStreamsManager',
          error: {'error': e.toString()},
        );
      }
    }
  }

  /// Публикация обернутого сообщения
  ///
  /// Для случаев, когда сообщение уже оформлено как [StreamMessage]
  void publishWrapped(StreamMessage<ResponseType> wrappedEvent) {
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
  _ClientStreamWrapper<ResponseType>? getClientInfo(String clientId) {
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
      RpcLog.error(
        message: 'Ошибка при закрытии основного контроллера',
        source: 'ServerStreamsManager',
        error: {'error': e.toString()},
      );
    }
  }
}

/// Класс для хранения информации о клиентском стриме
class _ClientStreamWrapper<ResponseType extends IRpcSerializableMessage> {
  final StreamController<ResponseType> controller;
  final StreamSubscription<StreamMessage<ResponseType>> subscription;
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
      RpcLog.error(
        message: 'Ошибка при отмене подписки',
        source: 'ServerStreamsManager',
        error: {'error': e.toString()},
      );
    }

    try {
      if (!controller.isClosed) {
        await controller.close();
      }
    } catch (e) {
      RpcLog.error(
        message: 'Ошибка при закрытии контроллера',
        source: 'ServerStreamsManager',
        error: {'error': e.toString()},
      );
    }
  }
}
