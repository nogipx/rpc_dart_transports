// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';
import 'package:rpc_dart/src/message/exception.dart';

import '_serializer.dart';

/// Исключение при сериализации/десериализации
class RpcSerializationException extends RpcCustomException {
  RpcSerializationException({
    required super.customMessage,
    super.error,
    super.stackTrace,
  });
}

/// Реализация сериализатора, использующего JSON
class JsonSerializer implements IRpcSerializer {
  /// Создает новый экземпляр JSON сериализатора
  ///
  /// JSON сериализатор преобразует объекты Dart в JSON и обратно.
  /// Используется для сериализации сообщений RPC в удобочитаемый текстовый формат.
  /// Подходит для отладки и случаев, когда размер сообщений не критичен.
  const JsonSerializer();

  /// Стандартный кодек JSON
  static final JsonCodec _jsonCodec = const JsonCodec();

  /// Кодек для кодирования/декодирования UTF-8
  static final Utf8Codec _utf8Codec = const Utf8Codec();

  @override
  Uint8List serialize(dynamic message) {
    return _utf8Codec.encode(_jsonCodec.encode(message));
  }

  @override
  dynamic deserialize(Uint8List data) {
    try {
      final jsonString = _utf8Codec.decode(data);
      return _jsonCodec.decode(jsonString);
    } on FormatException catch (e, stackTrace) {
      throw RpcSerializationException(
        customMessage: 'Ошибка формата JSON при десериализации',
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      if (e.toString().contains('UTF-8')) {
        throw RpcSerializationException(
          customMessage: 'Ошибка декодирования UTF-8 при десериализации',
          error: e,
          stackTrace: stackTrace,
        );
      }
      throw RpcSerializationException(
        customMessage: 'Ошибка при десериализации из JSON',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  String get name => 'json';
}
