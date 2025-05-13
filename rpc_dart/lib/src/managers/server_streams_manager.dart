import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'stream_message.dart';

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

  /// Публикация данных во все активные стримы
  ///
  /// Сообщение автоматически оборачивается в [StreamMessage] и
  /// отправляется всем клиентам.
  void publish(T event, {Map<String, dynamic>? metadata}) {
    // Отправляем в основной контроллер с общим ID для broadcast
    if (!_mainController.isClosed) {
      final wrappedEvent = StreamMessage<T>(
        message: event,
        streamId: 'broadcast',
        metadata: metadata,
      );
      _mainController.add(wrappedEvent);
    }
  }

  /// Создание нового стрима для клиента
  ServerStreamingBidiStream<Request, T>
      createClientStream<Request extends IRpcSerializableMessage>() {
    final clientId = 'stream_${_streamCounter++}';
    final clientController = StreamController<T>.broadcast();

    // Подписываемся на основной стрим и передаем данные в клиентский контроллер
    final subscription = _mainController.stream.listen(
      (wrappedEvent) {
        if (!clientController.isClosed) {
          // Извлекаем оригинальное сообщение из обертки
          clientController.add(wrappedEvent.message);
        }
      },
      onError: (error) {
        if (!clientController.isClosed) {
          clientController.addError(error);
        }
      },
      onDone: () {
        // Не закрываем клиентский контроллер, чтобы можно было публиковать в него напрямую
      },
    );

    // Создаем BidiStreamGenerator, который будет генерировать ответы
    final generator = BidiStreamGenerator<Request, T>((requestStream) {
      // Подписываемся на входящие запросы, чтобы знать когда клиент отключается
      requestStream.listen(
        (request) {
          // Здесь можно обрабатывать запросы от клиента, если нужно
        },
        onDone: () {
          // Клиент отключился, закрываем его стрим
          closeClientStream(clientId);
        },
      );

      // Возвращаем стрим клиента
      return clientController.stream;
    });

    // Создаем BidiStream и конвертируем его в серверный стрим
    final bidiStream = generator.create();
    final serverStream = bidiStream.toServerStreaming();

    // Сохраняем информацию о клиентском стриме
    _clientStreams[clientId] = _ClientStreamWrapper(
      controller: clientController,
      subscription: subscription,
      clientId: clientId,
      createdAt: DateTime.now(),
    );

    return serverStream;
  }

  /// Прямая публикация в конкретный стрим клиента
  ///
  /// Сообщение автоматически оборачивается в [StreamMessage] с ID клиента.
  void publishToClient(String clientId, T event,
      {Map<String, dynamic>? metadata}) {
    final wrapper = _clientStreams[clientId];
    if (wrapper != null && !wrapper.controller.isClosed) {
      // Отправляем сообщение напрямую в клиентский контроллер
      wrapper.controller.add(event);

      // Обновляем время последней активности
      wrapper.updateLastActivity();
    }
  }

  /// Публикация обернутого сообщения
  ///
  /// Для случаев, когда сообщение уже оформлено как [StreamMessage]
  void publishWrapped(StreamMessage<T> wrappedEvent) {
    if (!_mainController.isClosed) {
      _mainController.add(wrappedEvent);
    }
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

  /// Закрытие конкретного клиентского стрима
  Future<void> closeClientStream(String clientId) async {
    final wrapper = _clientStreams.remove(clientId);
    if (wrapper != null) {
      await wrapper.dispose();
    }
  }

  /// Закрытие всех клиентских стримов
  Future<void> closeAllClientStreams() async {
    for (final clientId in _clientStreams.keys.toList()) {
      await closeClientStream(clientId);
    }
  }

  /// Освобождение всех ресурсов
  Future<void> dispose() async {
    // Закрываем все клиентские контроллеры
    await closeAllClientStreams();

    // Закрываем основной контроллер
    if (!_mainController.isClosed) {
      await _mainController.close();
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

  /// Освобождение ресурсов
  Future<void> dispose() async {
    await subscription.cancel();

    if (!controller.isClosed) {
      await controller.close();
    }
  }
}
