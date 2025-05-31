// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';
import 'package:rpc_dart/rpc_dart.dart';

/// Кодировщик исходящих WebSocket сообщений
///
/// Отвечает за кодирование метаданных и данных в бинарный формат для отправки.
/// Выделен из WebSocketTransportBase для улучшения читаемости.
class WebSocketMessageEncoder {
  final RpcLogger? _logger;

  WebSocketMessageEncoder({
    RpcLogger? logger,
  }) : _logger = logger?.child('MessageEncoder');

  /// Кодирует метаданные в бинарное сообщение
  Uint8List encodeMetadata(
    int streamId,
    RpcMetadata metadata, {
    bool endStream = false,
  }) {
    try {
      _logger?.debug(
          'Кодирование метаданных для stream $streamId: ${metadata.headers.length} заголовков, path: ${metadata.methodPath}');

      // Создаем заголовок транспортного сообщения
      final header = RpcTransportFrame(
        streamId: streamId,
        type: RpcTransportFrame.typeMetadata,
        isEndOfStream: endStream,
        methodPath: metadata.methodPath,
      );

      // Кодируем заголовки в бинарный формат
      final headersBytes = _encodeHeaders(metadata.headers);

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

      _logger
          ?.debug('Закодированы метаданные для stream $streamId, размер: ${message.length} байт');

      return message;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка при кодировании метаданных: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Кодирует данные в бинарное сообщение
  Uint8List encodeMessage(
    int streamId,
    Uint8List data, {
    bool endStream = false,
    String? methodPath,
  }) {
    try {
      _logger?.debug(
          'Кодирование данных для stream $streamId, размер: ${data.length} байт, endStream: $endStream');

      // Создаем заголовок транспортного сообщения
      final header = RpcTransportFrame(
        streamId: streamId,
        type: RpcTransportFrame.typeData,
        isEndOfStream: endStream,
        methodPath: methodPath,
      );

      // Кодируем данные с использованием gRPC формата
      final encodedData = RpcMessageFrame.encode(data);
      _logger?.debug('Размер закодированных данных: ${encodedData.length} байт');

      // Комбинируем заголовок и данные
      final headerBytes = header.encode();
      _logger?.debug('Размер заголовка фрейма: ${headerBytes.length} байт');

      final message = Uint8List(headerBytes.length + encodedData.length);

      // Копируем заголовок
      message.setRange(0, headerBytes.length, headerBytes);

      // Копируем данные
      message.setRange(headerBytes.length, message.length, encodedData);

      _logger?.debug('Закодированы данные для stream $streamId, размер: ${message.length} байт');

      return message;
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при кодировании сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Кодирует сообщение завершения потока
  Uint8List encodeStreamEnd(int streamId, {String? methodPath}) {
    try {
      _logger?.debug('Кодирование завершения потока для stream $streamId');

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
          'Закодировано завершение потока для stream $streamId, размер: ${message.length} байт');

      return message;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка при кодировании завершения потока: $e',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Кодирует заголовки в бинарный формат
  List<int> _encodeHeaders(List<RpcHeader> headers) {
    final List<int> headersBytes = [];

    for (final header in headers) {
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

      _logger?.debug('  Закодирован заголовок: ${header.name} = ${header.value}');
    }

    return headersBytes;
  }
}
