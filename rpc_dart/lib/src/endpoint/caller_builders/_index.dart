import 'dart:async';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';

part 'rpc_bidirectional_stream_builder.dart';
part 'rpc_client_stream_builder.dart';
part 'rpc_server_stream_builder.dart';
part 'rpc_unary_request_builder.dart';

/// Сериализатор, который просто передает данные как есть без преобразования
class PassthroughSerializer<T> implements IRpcSerializer<T> {
  const PassthroughSerializer();

  T fromBytes(Uint8List bytes) => utf8.decode(bytes) as T;

  Uint8List toBytes(T data) => utf8.encode(data.toString());

  @override
  T deserialize(Uint8List data) => fromBytes(data);

  @override
  Uint8List serialize(T data) => toBytes(data);
}

/// Функция парсинга сообщений RPC
List<Uint8List> parseRpcMessageFrame(Uint8List data, {RpcLogger? logger}) {
  if (data.isEmpty) {
    logger?.warning('Пустые данные для парсинга');
    return [];
  }

  try {
    // Размер префикса gRPC сообщения - 5 байт (1 байт флаг + 4 байта длина)
    if (data.length < 5) {
      logger?.warning(
          'Сообщение слишком короткое для парсинга: ${data.length} байт');
      return [];
    }

    // Чтение длины сообщения из префикса (big-endian)
    final length = (data[1] << 24) | (data[2] << 16) | (data[3] << 8) | data[4];

    // Проверка размера сообщения
    if (length <= 0 || data.length < length + 5) {
      logger?.warning(
          'Неверная длина сообщения: $length, доступно: ${data.length - 5}');
      return [];
    }

    // Извлечение полезной нагрузки без префикса
    final payload = data.sublist(5, 5 + length);
    logger?.debug('Успешно извлечено сообщение длиной $length байт');

    return [payload];
  } catch (e) {
    logger?.error('Ошибка при парсинге сообщения: $e');
    return [];
  }
}
