// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';
import 'package:rpc_dart/rpc_dart.dart';

/// Обработчик входящих WebSocket сообщений
///
/// Отвечает за парсинг и декодирование входящих сообщений от WebSocket.
/// Выделен из WebSocketTransportBase для улучшения читаемости.
class WebSocketMessageProcessor {
  final RpcLogger? _logger;

  /// Парсер сообщений для корректной обработки gRPC фреймов
  late final RpcMessageParser _parser;

  /// Активные потоки и их методы
  final Map<int, String> _streamMethodPaths = {};

  WebSocketMessageProcessor({
    RpcLogger? logger,
  }) : _logger = logger?.child('MessageProcessor') {
    _parser = RpcMessageParser(logger: _logger);
  }

  /// Обрабатывает входящее WebSocket сообщение
  List<RpcTransportMessage> processIncomingMessage(dynamic message) {
    try {
      _logger?.debug('Получено сообщение: ${message.runtimeType}');
      if (message is List<int>) {
        // Обрабатываем бинарные данные
        return _handleBinaryMessage(Uint8List.fromList(message));
      } else {
        _logger?.warning(
            'Получено сообщение неизвестного типа: ${message.runtimeType}, ожидался бинарный формат');
        return [];
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при обработке входящего сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Обрабатывает входящее бинарное сообщение
  List<RpcTransportMessage> _handleBinaryMessage(Uint8List binaryData) {
    try {
      _logger?.debug('Обработка бинарного сообщения длиной: ${binaryData.length} байт');

      // Пытаемся декодировать заголовок сообщения
      final header = RpcTransportFrame.decode(binaryData);

      if (header == null) {
        _logger?.warning('Невозможно декодировать заголовок транспортного сообщения');
        return [];
      }

      _logger?.debug(
          'Декодирован заголовок: streamId=${header.streamId}, type=${header.type}, endStream=${header.isEndOfStream}, path=${header.methodPath}');

      // Вычисляем размер заголовка
      final headerSize = RpcTransportFrame.size(header.methodPath);
      _logger?.debug('Размер заголовка: $headerSize байт');

      // Если сообщение меньше размера заголовка, это ошибка
      if (binaryData.length < headerSize) {
        _logger?.warning('Сообщение слишком короткое для заголовка');
        return [];
      }

      // Извлекаем полезную нагрузку (если есть)
      final Uint8List? payload =
          binaryData.length > headerSize ? binaryData.sublist(headerSize) : null;

      _logger?.debug('Размер payload: ${payload?.length} байт');

      // Обрабатываем сообщение в зависимости от типа
      if (header.type == RpcTransportFrame.typeMetadata) {
        // Метаданные
        return [_processMetadataMessage(header, payload)];
      } else if (header.type == RpcTransportFrame.typeData) {
        // Данные
        return _processDataMessage(header, payload);
      } else {
        _logger?.warning('Получен неизвестный тип сообщения: ${header.type}');
        return [];
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при обработке бинарного сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Обрабатывает сообщение с метаданными
  RpcTransportMessage _processMetadataMessage(RpcTransportFrame header, Uint8List? payload) {
    final streamId = header.streamId;

    _logger?.debug('Обработка метаданных для stream $streamId, path: ${header.methodPath}');

    // Если есть путь метода, сохраняем его
    if (header.methodPath != null) {
      _streamMethodPaths[streamId] = header.methodPath!;
    }

    // Парсим заголовки из payload, если они есть
    final List<RpcHeader> headers = [];
    if (payload != null && payload.isNotEmpty) {
      headers.addAll(_parseHeaders(payload));
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

    _logger?.debug('Создано транспортное сообщение с метаданными для stream $streamId');
    return transportMessage;
  }

  /// Обрабатывает сообщение с данными
  List<RpcTransportMessage> _processDataMessage(RpcTransportFrame header, Uint8List? payload) {
    final streamId = header.streamId;

    _logger?.debug('Обработка данных для stream $streamId');

    if (payload == null) {
      _logger?.warning('Получено сообщение данных без payload для stream $streamId');
      return [];
    }

    _logger?.debug('Получены данные размером: ${payload.length} байт для stream $streamId');

    // Используем парсер для обработки gRPC фреймов
    try {
      // Декодируем полезную нагрузку через RpcMessageParser
      final decodedPayloads = _parser(payload);
      _logger?.debug('Декодировано ${decodedPayloads.length} пакетов данных');

      return decodedPayloads.map((decodedPayload) {
        return RpcTransportMessage(
          streamId: streamId,
          payload: decodedPayload,
          isEndOfStream: header.isEndOfStream,
        );
      }).toList();
    } catch (e) {
      // Если парсер не смог обработать данные, передаем их как есть
      _logger?.warning('Невозможно декодировать gRPC фрейм, передаем данные как есть: $e');

      return [
        RpcTransportMessage(
          streamId: streamId,
          payload: payload,
          isEndOfStream: header.isEndOfStream,
        )
      ];
    }
  }

  /// Парсит заголовки из бинарных данных
  List<RpcHeader> _parseHeaders(Uint8List payload) {
    final List<RpcHeader> headers = [];

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
        String name = utf8.decode(payload.sublist(offset, offset + nameLength));
        offset += nameLength;

        // Читаем длину значения
        if (offset + 2 > payload.length) break;
        int valueLength = (payload[offset] << 8) | payload[offset + 1];
        offset += 2;

        // Читаем значение
        if (offset + valueLength > payload.length) break;
        String value = utf8.decode(payload.sublist(offset, offset + valueLength));
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

    return headers;
  }

  /// Получает сохраненный путь метода для потока
  String? getMethodPath(int streamId) {
    return _streamMethodPaths[streamId];
  }

  /// Сохраняет путь метода для потока
  void setMethodPath(int streamId, String methodPath) {
    _streamMethodPaths[streamId] = methodPath;
  }

  /// Удаляет путь метода для потока
  void removeMethodPath(int streamId) {
    _streamMethodPaths.remove(streamId);
  }

  /// Очищает все сохраненные пути методов
  void clear() {
    _streamMethodPaths.clear();
  }
}
