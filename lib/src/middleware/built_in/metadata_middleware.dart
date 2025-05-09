// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart'
    show
        MutableRpcMethodContext,
        RpcMethodContext,
        SimpleRpcMiddleware,
        RpcDataDirection;

/// Middleware для добавления метаданных к запросам и ответам
class MetadataMiddleware implements SimpleRpcMiddleware {
  /// Метаданные, которые будут добавлены к исходящим запросам
  final Map<String, dynamic> _requestMetadata;

  /// Метаданные, которые будут добавлены к ответам
  final Map<String, dynamic> _responseMetadata;

  /// Создает middleware для работы с метаданными
  ///
  /// [requestMetadata] - метаданные для исходящих запросов
  /// [responseMetadata] - метаданные для ответов
  MetadataMiddleware({
    Map<String, dynamic>? requestMetadata,
    Map<String, dynamic>? responseMetadata,
  })  : _requestMetadata = requestMetadata ?? {},
        _responseMetadata = responseMetadata ?? {};

  /// Добавляет метаданные к запросу
  ///
  /// [key] - ключ метаданных
  /// [value] - значение метаданных
  void addRequestMetadata(String key, dynamic value) {
    _requestMetadata[key] = value;
  }

  /// Добавляет метаданные к ответу
  ///
  /// [key] - ключ метаданных
  /// [value] - значение метаданных
  void addResponseMetadata(String key, dynamic value) {
    _responseMetadata[key] = value;
  }

  @override
  Future<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    // Если у нас есть метаданные в контексте, добавляем к ним новые
    final metadata = context.metadata ?? {};

    // Добавляем метаданные запроса
    for (final entry in _requestMetadata.entries) {
      metadata[entry.key] = entry.value;
    }

    // Для мутабельного контекста пытаемся обновить метаданные
    // Здесь используем проверку на наличие метода toMutable()
    // Если он есть и возвращает мутабельный контекст, используем его
    if (context is MutableRpcMethodContext) {
      // Если контекст уже мутабельный, работаем с ним напрямую
      context.updateMetadata(metadata);
    } else {
      try {
        // Пробуем получить мутабельную копию и работать с ней
        // Но это уже вторичный сценарий, который может не сработать
        final mutable = context.toMutable();
        mutable.updateMetadata(metadata);
      } catch (e) {
        // Если метода toMutable нет, просто игнорируем ошибку
        // Метаданные не будут обновлены
      }
    }

    return Future.value(payload);
  }

  @override
  Future<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    // Для responses метаданные можно добавить только к объектам, которые
    // их поддерживают (например, RpcMessage)
    if (response is Map<String, dynamic>) {
      // Если ответ - это Map, добавляем метаданные
      final metadata = (response['metadata'] as Map<String, dynamic>?) ?? {};

      for (final entry in _responseMetadata.entries) {
        metadata[entry.key] = entry.value;
      }

      response['metadata'] = metadata;
    }

    return Future.value(response);
  }

  @override
  Future<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    // Для ошибок не добавляем метаданные
    return Future.value(error);
  }

  @override
  Future<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  ) {
    // Для стрим-данных не добавляем метаданные
    return Future.value(data);
  }

  @override
  Future<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    // Для завершения стрима не требуется специальных действий
    return Future.value();
  }
}
