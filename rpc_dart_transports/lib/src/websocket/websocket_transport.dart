// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Менеджер для управления Stream ID.
///
/// Отвечает за генерацию уникальных ID для потоков gRPC
/// согласно спецификации HTTP/2, где клиент использует
/// нечетные ID, а сервер - четные.
class _WebSocketStreamIdManager {
  /// Флаг, указывающий, является ли транспорт клиентским
  final bool isClient;

  /// Текущий идентификатор (инкрементируется при создании нового потока)
  int _currentId;

  /// Множество активных идентификаторов
  final Set<int> _activeIds = {};

  /// Создает новый менеджер идентификаторов потоков
  ///
  /// [isClient] Если true, использует нечетные ID, иначе - четные
  _WebSocketStreamIdManager({
    required this.isClient,
  }) : _currentId = isClient ? -1 : 0;

  /// Возвращает новый идентификатор потока
  int generateId() {
    _currentId += 2;
    final id = _currentId;
    _activeIds.add(id);
    return id;
  }

  /// Освобождает идентификатор потока
  ///
  /// Возвращает true, если ID был успешно освобожден
  bool releaseId(int id) {
    return _activeIds.remove(id);
  }

  /// Проверяет, используется ли идентификатор
  bool isActive(int id) {
    return _activeIds.contains(id);
  }

  /// Сбрасывает менеджер в начальное состояние
  void reset() {
    _currentId = isClient ? -1 : 0;
    _activeIds.clear();
  }

  /// Возвращает количество активных идентификаторов
  int get activeCount => _activeIds.length;

  /// Возвращает множество активных идентификаторов
  Set<int> get activeIds => Set.from(_activeIds);
}

/// Структура сообщения для WebSocket транспорта
class _WebSocketMessage {
  /// Идентификатор потока
  final int streamId;

  /// Тип сообщения
  final String type;

  /// Данные сообщения (метаданные или полезная нагрузка)
  final dynamic data;

  /// Флаг завершения потока
  final bool isEndOfStream;

  /// Путь метода (для первоначальных метаданных)
  final String? methodPath;

  const _WebSocketMessage({
    required this.streamId,
    required this.type,
    required this.data,
    this.isEndOfStream = false,
    this.methodPath,
  });

  /// Создает сообщение с метаданными
  factory _WebSocketMessage.metadata(
    int streamId,
    List<Map<String, String>> headers, {
    bool isEndOfStream = false,
    String? methodPath,
  }) {
    return _WebSocketMessage(
      streamId: streamId,
      type: 'metadata',
      data: headers,
      isEndOfStream: isEndOfStream,
      methodPath: methodPath,
    );
  }

  /// Создает сообщение с данными
  factory _WebSocketMessage.data(
    int streamId,
    String base64Data, {
    bool isEndOfStream = false,
  }) {
    return _WebSocketMessage(
      streamId: streamId,
      type: 'data',
      data: base64Data,
      isEndOfStream: isEndOfStream,
    );
  }

  /// Преобразует сообщение в JSON для отправки
  Map<String, dynamic> toJson() {
    final result = {
      'streamId': streamId,
      'type': type,
      'data': data,
      'isEndOfStream': isEndOfStream,
    };

    if (methodPath != null) {
      result['methodPath'] = methodPath;
    }

    return result;
  }

  /// Создает сообщение из JSON
  factory _WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return _WebSocketMessage(
      streamId: json['streamId'] as int,
      type: json['type'] as String,
      data: json['data'],
      isEndOfStream: json['isEndOfStream'] as bool,
      methodPath: json['methodPath'] as String?,
    );
  }
}

/// Реализация транспорта WebSocket для RPC
///
/// Обеспечивает коммуникацию через WebSocket с поддержкой мультиплексирования
/// потоков по уникальным Stream ID согласно спецификации gRPC.
class RpcWebSocketTransport implements IRpcTransport {
  /// WebSocket канал для обмена сообщениями
  final WebSocketChannel _channel;

  /// Менеджер Stream ID
  final _WebSocketStreamIdManager _idManager;

  /// Контроллер для управления потоком входящих сообщений
  final StreamController<RpcTransportMessage> _incomingController =
      StreamController<RpcTransportMessage>.broadcast();

  /// Флаг закрытия транспорта
  bool _closed = false;

  /// Активные потоки и их состояние
  final Map<int, bool> _streamSendingFinished = <int, bool>{};

  /// Карта, сопоставляющая Stream ID с путями методов
  final Map<int, String> _streamMethodPaths = {};

  /// Логгер для отладки
  final RpcLogger? _logger;

  /// Создает новый WebSocket транспорт
  ///
  /// [channel] WebSocket канал для коммуникации
  /// [isClient] Флаг клиентского транспорта (влияет на генерацию Stream ID)
  /// [logger] Опциональный логгер для отладки
  RpcWebSocketTransport(
    this._channel, {
    bool isClient = true,
    RpcLogger? logger,
  })  : _idManager = _WebSocketStreamIdManager(isClient: isClient),
        _logger = logger {
    _setupListener();
  }

  /// Устанавливает слушатель для входящих WebSocket сообщений
  void _setupListener() {
    _channel.stream.listen(
      _handleIncomingMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
  }

  /// Обрабатывает входящее WebSocket сообщение
  void _handleIncomingMessage(dynamic message) {
    try {
      if (message is String) {
        final decoded = jsonDecode(message);
        if (decoded is Map<String, dynamic>) {
          final wsMessage = _WebSocketMessage.fromJson(decoded);
          _processWebSocketMessage(wsMessage);
        } else {
          _logger?.warning('Получено некорректное сообщение: $message');
        }
      } else {
        _logger?.warning(
            'Получено сообщение неизвестного типа: ${message.runtimeType}');
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при обработке входящего сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Обрабатывает ошибку WebSocket соединения
  void _handleError(Object error, StackTrace stackTrace) {
    _logger?.error(
      'Ошибка WebSocket соединения: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Обрабатывает закрытие WebSocket соединения
  void _handleDone() {
    _logger?.info('WebSocket соединение закрыто');
    close();
  }

  /// Преобразует WebSocket сообщение в сообщение транспорта
  void _processWebSocketMessage(_WebSocketMessage wsMessage) {
    final streamId = wsMessage.streamId;

    _logger?.debug(
        'Получено WebSocket сообщение типа: ${wsMessage.type} для stream $streamId, isEndOfStream: ${wsMessage.isEndOfStream}, methodPath: ${wsMessage.methodPath}');

    if (wsMessage.type == 'metadata') {
      // Обрабатываем метаданные
      _logger?.debug('Обработка метаданных для stream $streamId');

      if (wsMessage.data is List) {
        final headers = <RpcHeader>[];
        for (var header in wsMessage.data) {
          if (header is Map<String, dynamic>) {
            headers.add(RpcHeader(
              header['name'] as String,
              header['value'] as String,
            ));
            _logger
                ?.debug('  Заголовок: ${header['name']} = ${header['value']}');
          }
        }

        final metadata = RpcMetadata(headers);
        final transportMessage = RpcTransportMessage(
          streamId: streamId,
          metadata: metadata,
          isEndOfStream: wsMessage.isEndOfStream,
          methodPath: wsMessage.methodPath,
        );

        _logger?.debug(
            'Добавление метаданных в поток incomingMessages для stream $streamId');
        _incomingController.add(transportMessage);
      } else {
        _logger?.warning(
            'Получены метаданные неверного формата: ${wsMessage.data.runtimeType}');
      }
    } else if (wsMessage.type == 'data') {
      // Обрабатываем данные
      _logger?.debug('Обработка данных для stream $streamId');

      if (wsMessage.data is String) {
        try {
          final base64Data = wsMessage.data as String;
          final bytes = base64Decode(base64Data);

          _logger?.debug(
              'Декодированы данные размером: ${bytes.length} байт для stream $streamId');

          final transportMessage = RpcTransportMessage(
            streamId: streamId,
            payload: bytes,
            isEndOfStream: wsMessage.isEndOfStream,
          );

          _logger?.debug(
              'Добавление данных в поток incomingMessages для stream $streamId');
          _incomingController.add(transportMessage);
        } catch (e, stackTrace) {
          _logger?.error(
            'Ошибка декодирования base64 данных: $e',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } else {
        _logger?.warning(
            'Получены данные неверного формата: ${wsMessage.data.runtimeType}');
      }
    } else {
      _logger?.warning('Получен неизвестный тип сообщения: ${wsMessage.type}');
    }

    // Если это сообщение завершающее, освобождаем ID
    if (wsMessage.isEndOfStream) {
      _logger?.debug('Получен END_STREAM для stream $streamId');

      if (_idManager.isActive(streamId)) {
        _idManager.releaseId(streamId);
        _logger?.debug(
            'Освобожден ID $streamId, активных потоков: ${_idManager.activeCount}');
      }
    }
  }

  @override
  Stream<RpcTransportMessage> get incomingMessages =>
      _incomingController.stream;

  @override
  Stream<RpcTransportMessage> getMessagesForStream(int streamId) {
    return incomingMessages.where((message) => message.streamId == streamId);
  }

  @override
  int createStream() {
    if (_closed) {
      throw StateError('WebSocket транспорт закрыт');
    }

    final streamId = _idManager.generateId();
    _streamSendingFinished[streamId] = false;
    _logger?.debug('Создан stream $streamId');
    return streamId;
  }

  @override
  bool releaseStreamId(int streamId) {
    if (_closed) return false;

    _streamSendingFinished.remove(streamId);
    _streamMethodPaths.remove(streamId); // Удаляем сохраненный путь метода

    final released = _idManager.releaseId(streamId);
    if (released) {
      _logger?.debug(
          'Освобожден ID $streamId, активных потоков: ${_idManager.activeCount}');
    } else {
      _logger?.debug(
          'ID уже был освобожден или никогда не использовался [streamId: $streamId]');
    }

    return released;
  }

  @override
  Future<void> sendMetadata(
    int streamId,
    RpcMetadata metadata, {
    bool endStream = false,
  }) async {
    if (_closed) return;

    try {
      // Сохраняем методопуть для данного потока
      if (metadata.methodPath != null) {
        _streamMethodPaths[streamId] = metadata.methodPath!;
      }

      final wsMessage = _WebSocketMessage.metadata(
        streamId,
        metadata.headers
            .map((header) => {'name': header.name, 'value': header.value})
            .toList(),
        isEndOfStream: endStream,
        methodPath: metadata.methodPath,
      );

      final jsonMessage = jsonEncode(wsMessage.toJson());
      _channel.sink.add(jsonMessage);

      _logger?.debug(
          'Отправлены метаданные для stream $streamId, endStream: $endStream, path: ${metadata.methodPath}');

      if (endStream) {
        _streamSendingFinished[streamId] = true;
        // Не освобождаем ID сразу, оставляем для потенциальных ответов
      }
    } catch (e) {
      _logger?.error('Ошибка при отправке метаданных: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendMessage(
    int streamId,
    Uint8List data, {
    bool endStream = false,
  }) async {
    if (_closed) {
      _logger?.warning('Попытка отправить данные после закрытия транспорта');
      return;
    }

    try {
      // Преобразуем бинарные данные в Base64 для безопасной передачи через WebSocket
      final base64Data = base64Encode(data);

      final wsMessage = _WebSocketMessage.data(
        streamId,
        base64Data,
        isEndOfStream: endStream,
      );

      final jsonMessage = jsonEncode(wsMessage.toJson());
      _channel.sink.add(jsonMessage);

      _logger?.debug(
          'Отправлено сообщение для stream $streamId, размер: ${data.length} байт, endStream: $endStream');

      if (endStream) {
        _streamSendingFinished[streamId] = true;

        if (_idManager.isActive(streamId)) {
          _idManager.releaseId(streamId);
          _logger?.debug(
              'Освобожден ID $streamId после отправки сообщения с endStream=true');
        }
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при отправке сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> finishSending(int streamId) async {
    if (_closed) return;

    if (_streamSendingFinished[streamId] == true) {
      return; // Уже завершен
    }

    try {
      _logger?.debug('Отправлен флаг завершения потока для ID $streamId');
      _streamSendingFinished[streamId] = true;

      // Сохраняем methodPath, связанный с данным потоком
      String? methodPath = _streamMethodPaths[streamId];

      // Отправляем пустые метаданные с флагом END_STREAM для конкретного stream
      final wsMessage = _WebSocketMessage.metadata(
        streamId,
        [], // Пустые метаданные
        isEndOfStream: true,
        methodPath: methodPath, // Используем сохраненный путь
      );

      final jsonMessage = jsonEncode(wsMessage.toJson());
      _channel.sink.add(jsonMessage);
    } catch (e) {
      _logger?.error('Ошибка при завершении отправки: $e');
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;

    _closed = true;
    _streamSendingFinished.clear();
    _streamMethodPaths.clear(); // Очищаем пути методов

    // Сбрасываем менеджер ID
    _idManager.reset();
    _logger?.debug('Сброшен менеджер ID при закрытии');

    try {
      await _channel.sink.close();
      _logger?.info('WebSocket транспорт закрыт');
    } catch (e) {
      _logger?.error('Ошибка при закрытии WebSocket: $e');
      rethrow;
    }
  }

  /// Фабричный метод для создания клиентского WebSocket транспорта
  ///
  /// [uri] URI для подключения к WebSocket серверу
  /// [protocols] Опциональные подпротоколы WebSocket
  /// [headers] Опциональные HTTP заголовки для установки соединения
  /// [logger] Опциональный логгер для отладки
  static RpcWebSocketTransport connect(
    Uri uri, {
    Iterable<String>? protocols,
    Map<String, dynamic>? headers,
    RpcLogger? logger,
  }) {
    final channel = IOWebSocketChannel.connect(
      uri,
      protocols: protocols,
      headers: headers,
    );
    return RpcWebSocketTransport(channel, isClient: true, logger: logger);
  }
}
