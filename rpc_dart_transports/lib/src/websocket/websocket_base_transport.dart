// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Базовый класс для WebSocket транспорта
///
/// Содержит общую логику для клиентской и серверной реализаций
abstract class RpcWebSocketTransportBase implements IRpcTransport {
  /// WebSocket канал для обмена сообщениями
  final WebSocketChannel _channel;

  /// Контроллер для управления потоком входящих сообщений
  final StreamController<RpcTransportMessage> _incomingController =
      StreamController<RpcTransportMessage>.broadcast();

  /// Флаг закрытия транспорта
  bool _closed = false;

  /// Активные потоки и их состояние
  final Map<int, bool> _streamSendingFinished = <int, bool>{};

  /// Карта, сопоставляющая Stream ID с путями методов
  final Map<int, String> _streamMethodPaths = {};

  /// Парсер сообщений для корректной обработки gRPC фреймов
  late final RpcMessageParser _parser;

  /// Логгер для отладки
  final RpcLogger? _logger;

  /// Создает новый базовый WebSocket транспорт
  ///
  /// [channel] WebSocket канал для коммуникации
  /// [logger] Опциональный логгер для отладки
  RpcWebSocketTransportBase(
    this._channel, {
    RpcLogger? logger,
  }) : _logger = logger {
    _parser = RpcMessageParser(logger: _logger);
    _setupListener();
  }

  /// Получает менеджер Stream ID (реализуется в подклассах)
  RpcStreamIdManager get idManager;

  /// Устанавливает слушатель для входящих WebSocket сообщений
  void _setupListener() {
    _logger?.debug('Устанавливаем слушатель WebSocket');
    _channel.stream.listen(
      _handleIncomingMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
    _logger?.debug('Слушатель WebSocket установлен');
  }

  /// Обрабатывает входящее WebSocket сообщение
  void _handleIncomingMessage(dynamic message) {
    try {
      _logger?.debug('Получено сообщение: ${message.runtimeType}');
      if (message is List<int>) {
        // Обрабатываем бинарные данные
        _handleBinaryMessage(Uint8List.fromList(message));
      } else {
        _logger?.warning(
            'Получено сообщение неизвестного типа: ${message.runtimeType}, ожидался бинарный формат');
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при обработке входящего сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Обрабатывает входящее бинарное сообщение
  void _handleBinaryMessage(Uint8List binaryData) {
    try {
      _logger?.debug(
          'Обработка бинарного сообщения длиной: ${binaryData.length} байт');

      // Пытаемся декодировать заголовок сообщения
      final header = RpcTransportFrame.decode(binaryData);

      if (header == null) {
        _logger?.warning(
            'Невозможно декодировать заголовок транспортного сообщения');
        return;
      }

      _logger?.debug(
          'Декодирован заголовок: streamId=${header.streamId}, type=${header.type}, endStream=${header.isEndOfStream}, path=${header.methodPath}');

      // Вычисляем размер заголовка
      final headerSize = RpcTransportFrame.size(header.methodPath);
      _logger?.debug('Размер заголовка: $headerSize байт');

      // Если сообщение меньше размера заголовка, это ошибка
      if (binaryData.length < headerSize) {
        _logger?.warning('Сообщение слишком короткое для заголовка');
        return;
      }

      // Извлекаем полезную нагрузку (если есть)
      final Uint8List? payload = binaryData.length > headerSize
          ? binaryData.sublist(headerSize)
          : null;

      _logger?.debug('Размер payload: ${payload?.length} байт');

      // Обрабатываем сообщение в зависимости от типа
      if (header.type == RpcTransportFrame.typeMetadata) {
        // Метаданные
        _processMetadataMessage(header, payload);
      } else if (header.type == RpcTransportFrame.typeData) {
        // Данные
        _processDataMessage(header, payload);
      } else {
        _logger?.warning('Получен неизвестный тип сообщения: ${header.type}');
      }

      // Если это сообщение завершающее, освобождаем ID
      if (header.isEndOfStream) {
        _handleEndOfStream(header.streamId);
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при обработке бинарного сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Обрабатывает сообщение с метаданными
  void _processMetadataMessage(RpcTransportFrame header, Uint8List? payload) {
    final streamId = header.streamId;

    _logger?.debug(
        'Обработка метаданных для stream $streamId, path: ${header.methodPath}');

    // Если есть путь метода, сохраняем его
    if (header.methodPath != null) {
      _streamMethodPaths[streamId] = header.methodPath!;
    }

    // Парсим заголовки из payload, если они есть
    final List<RpcHeader> headers = [];
    if (payload != null && payload.isNotEmpty) {
      try {
        // Предполагаем, что payload содержит пары имя-значение в формате:
        // [длина имени (2 байта)][имя][длина значения (2 байта)][значение]...
        int offset = 0;
        while (offset < payload.length) {
          // Читаем длину имени
          if (offset + 2 > payload.length) break;
          int nameLength = (payload[offset] << 8) | payload[offset + 1];
          offset += 2;

          // Читаем имя
          if (offset + nameLength > payload.length) break;
          String name =
              utf8.decode(payload.sublist(offset, offset + nameLength));
          offset += nameLength;

          // Читаем длину значения
          if (offset + 2 > payload.length) break;
          int valueLength = (payload[offset] << 8) | payload[offset + 1];
          offset += 2;

          // Читаем значение
          if (offset + valueLength > payload.length) break;
          String value =
              utf8.decode(payload.sublist(offset, offset + valueLength));
          offset += valueLength;

          headers.add(RpcHeader(name, value));
          _logger?.debug('  Заголовок: $name = $value');
        }
      } catch (e, stackTrace) {
        _logger?.error(
          'Ошибка при парсинге заголовков: $e',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    final methodPath = header.methodPath;

    final metadata = RpcMetadata(headers);
    if (methodPath != null) {
      // Если у нас есть путь метода, добавляем заголовки HTTP/2
      final parts = methodPath.split('/');
      if (parts.length >= 3 && parts[0].isEmpty) {
        // Добавляем стандартные HTTP/2 заголовки gRPC
        headers.addAll([
          RpcHeader(':method', 'POST'),
          RpcHeader(':path', methodPath),
          RpcHeader(':scheme', 'http'),
          RpcHeader('content-type', 'application/grpc'),
          RpcHeader(':authority', ''),
        ]);
      }
    }

    final transportMessage = RpcTransportMessage(
      streamId: streamId,
      metadata: metadata,
      isEndOfStream: header.isEndOfStream,
      methodPath: header.methodPath,
    );

    _logger?.debug(
        'Добавление метаданных в поток incomingMessages для stream $streamId');
    _incomingController.add(transportMessage);
  }

  /// Обрабатывает сообщение с данными
  void _processDataMessage(RpcTransportFrame header, Uint8List? payload) {
    final streamId = header.streamId;

    _logger?.debug('Обработка данных для stream $streamId');

    if (payload != null) {
      _logger?.debug(
          'Получены данные размером: ${payload.length} байт для stream $streamId');

      // Используем парсер для обработки gRPC фреймов
      try {
        // Декодируем полезную нагрузку через RpcMessageParser
        final decodedPayloads = _parser(payload);
        _logger?.debug('Декодировано ${decodedPayloads.length} пакетов данных');

        for (final decodedPayload in decodedPayloads) {
          final transportMessage = RpcTransportMessage(
            streamId: streamId,
            payload: decodedPayload,
            isEndOfStream: header.isEndOfStream,
          );

          _logger?.debug(
              'Добавление декодированных данных в поток incomingMessages для stream $streamId');
          _incomingController.add(transportMessage);
        }
      } catch (e) {
        // Если парсер не смог обработать данные, передаем их как есть
        _logger?.warning(
            'Невозможно декодировать gRPC фрейм, передаем данные как есть: $e');

        final transportMessage = RpcTransportMessage(
          streamId: streamId,
          payload: payload,
          isEndOfStream: header.isEndOfStream,
        );

        _incomingController.add(transportMessage);
      }
    } else {
      _logger?.warning(
          'Получено сообщение данных без payload для stream $streamId');
    }
  }

  /// Обрабатывает завершение потока
  void _handleEndOfStream(int streamId) {
    _logger?.debug('Получен END_STREAM для stream $streamId');

    if (idManager.isActive(streamId)) {
      idManager.releaseId(streamId);
      _logger?.debug(
          'Освобожден ID $streamId, активных потоков: ${idManager.activeCount}');
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

    final streamId = idManager.generateId();
    _streamSendingFinished[streamId] = false;
    _logger?.debug('Создан stream $streamId');
    return streamId;
  }

  @override
  bool releaseStreamId(int streamId) {
    if (_closed) return false;

    _streamSendingFinished.remove(streamId);
    _streamMethodPaths.remove(streamId); // Удаляем сохраненный путь метода

    final released = idManager.releaseId(streamId);
    if (released) {
      _logger?.debug(
          'Освобожден ID $streamId, активных потоков: ${idManager.activeCount}');
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
      _logger?.debug(
          'Отправка метаданных для stream $streamId: ${metadata.headers.length} заголовков, path: ${metadata.methodPath}');

      // Сохраняем методопуть для данного потока
      if (metadata.methodPath != null) {
        _streamMethodPaths[streamId] = metadata.methodPath!;
      }

      // Создаем заголовок транспортного сообщения
      final header = RpcTransportFrame(
        streamId: streamId,
        type: RpcTransportFrame.typeMetadata,
        isEndOfStream: endStream,
        methodPath: metadata.methodPath,
      );

      // Кодируем заголовки в бинарный формат
      final List<int> headersBytes = [];
      for (final header in metadata.headers) {
        final nameBytes = utf8.encode(header.name);
        final valueBytes = utf8.encode(header.value);

        // Добавляем длину имени (2 байта)
        headersBytes.add((nameBytes.length >> 8) & 0xFF);
        headersBytes.add(nameBytes.length & 0xFF);

        // Добавляем имя
        headersBytes.addAll(nameBytes);

        // Добавляем длину значения (2 байта)
        headersBytes.add((valueBytes.length >> 8) & 0xFF);
        headersBytes.add(valueBytes.length & 0xFF);

        // Добавляем значение
        headersBytes.addAll(valueBytes);
      }

      // Комбинируем заголовок и данные
      final headerBytes = header.encode();
      _logger?.debug('Размер заголовка фрейма: ${headerBytes.length} байт');

      final message = Uint8List(headerBytes.length + headersBytes.length);

      // Копируем заголовок
      message.setRange(0, headerBytes.length, headerBytes);

      // Копируем данные заголовков
      if (headersBytes.isNotEmpty) {
        message.setRange(headerBytes.length, message.length, headersBytes);
      }

      // Отправляем бинарное сообщение
      _logger?.debug(
          'Отправка бинарного сообщения размером ${message.length} байт');
      _channel.sink.add(message);

      _logger?.debug(
          'Отправлены метаданные для stream $streamId, endStream: $endStream, path: ${metadata.methodPath}');

      if (endStream) {
        _streamSendingFinished[streamId] = true;
        // Не освобождаем ID сразу, оставляем для потенциальных ответов
      }
    } catch (e, stackTrace) {
      _logger?.error('Ошибка при отправке метаданных: $e',
          error: e, stackTrace: stackTrace);
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
      _logger?.debug(
          'Отправка данных для stream $streamId, размер: ${data.length} байт, endStream: $endStream');

      // Получаем путь метода из сохраненных
      String? methodPath = _streamMethodPaths[streamId];

      // Создаем заголовок транспортного сообщения
      final header = RpcTransportFrame(
        streamId: streamId,
        type: RpcTransportFrame.typeData,
        isEndOfStream: endStream,
        methodPath: methodPath,
      );

      // Кодируем данные с использованием gRPC формата
      final encodedData = RpcMessageFrame.encode(data);
      _logger
          ?.debug('Размер закодированных данных: ${encodedData.length} байт');

      // Комбинируем заголовок и данные
      final headerBytes = header.encode();
      _logger?.debug('Размер заголовка фрейма: ${headerBytes.length} байт');

      final message = Uint8List(headerBytes.length + encodedData.length);

      // Копируем заголовок
      message.setRange(0, headerBytes.length, headerBytes);

      // Копируем данные
      message.setRange(headerBytes.length, message.length, encodedData);

      // Отправляем бинарное сообщение
      _logger?.debug(
          'Отправка бинарного сообщения размером ${message.length} байт');
      _channel.sink.add(message);

      _logger?.debug(
          'Отправлено бинарное сообщение для stream $streamId, размер: ${data.length} байт, endStream: $endStream');

      if (endStream) {
        _streamSendingFinished[streamId] = true;

        if (idManager.isActive(streamId)) {
          idManager.releaseId(streamId);
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
      _logger?.debug(
          'Стрим $streamId уже завершен, пропускаем отправку флага завершения');
      return; // Уже завершен
    }

    try {
      _logger?.debug('Отправка флага завершения потока для ID $streamId');
      _streamSendingFinished[streamId] = true;

      // Сохраняем methodPath, связанный с данным потоком
      String? methodPath = _streamMethodPaths[streamId];

      // Создаем заголовок с флагом завершения
      final header = RpcTransportFrame(
        streamId: streamId,
        type: RpcTransportFrame.typeMetadata,
        isEndOfStream: true,
        methodPath: methodPath,
      );

      // Отправляем пустое сообщение с флагом завершения
      final message = header.encode();
      _logger?.debug(
          'Отправка сообщения завершения размером ${message.length} байт');
      _channel.sink.add(message);

      // Освобождаем ID после отправки флага завершения
      if (idManager.isActive(streamId)) {
        idManager.releaseId(streamId);
        _logger
            ?.debug('Освобожден ID $streamId после отправки флага завершения');
      }
    } catch (e, stackTrace) {
      _logger?.error('Ошибка при завершении отправки: $e',
          error: e, stackTrace: stackTrace);
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
    idManager.reset();
    _logger?.debug('Сброшен менеджер ID при закрытии');

    try {
      await _channel.sink.close();
      _logger?.info('WebSocket транспорт закрыт');
    } catch (e) {
      _logger?.error('Ошибка при закрытии WebSocket: $e');
      rethrow;
    }
  }
}
