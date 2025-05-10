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
  /// Метаданные, которые будут добавлены к заголовкам запросов
  final Map<String, dynamic> _headerMetadata;

  /// Метаданные, которые будут добавлены к трейлерам ответов
  final Map<String, dynamic> _trailerMetadata;

  /// Создает middleware для работы с метаданными
  ///
  /// [headerMetadata] - метаданные для заголовков запросов
  /// [trailerMetadata] - метаданные для трейлеров ответов
  MetadataMiddleware({
    Map<String, dynamic>? headerMetadata,
    Map<String, dynamic>? trailerMetadata,
  })  : _headerMetadata = headerMetadata ?? {},
        _trailerMetadata = trailerMetadata ?? {};

  /// Добавляет метаданные к заголовкам запросов
  ///
  /// [key] - ключ метаданных
  /// [value] - значение метаданных
  void addHeaderMetadata(String key, dynamic value) {
    _headerMetadata[key] = value;
  }

  /// Добавляет метаданные к трейлерам ответов
  ///
  /// [key] - ключ метаданных
  /// [value] - значение метаданных
  void addTrailerMetadata(String key, dynamic value) {
    _trailerMetadata[key] = value;
  }

  @override
  Future<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    if (direction == RpcDataDirection.toRemote) {
      // Если у нас есть метаданные в контексте, добавляем к ним новые
      final metadata = Map<String, dynamic>.from(context.headerMetadata ?? {});

      // Добавляем метаданные запроса
      for (final entry in _headerMetadata.entries) {
        metadata[entry.key] = entry.value;
      }

      // Для мутабельного контекста обновляем метаданные
      if (context is MutableRpcMethodContext) {
        context.setHeaderMetadata(metadata);
      } else {
        try {
          // Пробуем получить мутабельную копию
          final mutable = context.toMutable();
          mutable.setHeaderMetadata(metadata);
        } catch (e) {
          // Если метода toMutable нет, просто игнорируем ошибку
        }
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
    if (direction == RpcDataDirection.toRemote) {
      // Для ответов, идущих к клиенту, добавляем трейлеры
      if (context is MutableRpcMethodContext) {
        final trailerMetadata =
            Map<String, dynamic>.from(context.trailerMetadata ?? {});

        // Добавляем наши трейлерные метаданные
        for (final entry in _trailerMetadata.entries) {
          trailerMetadata[entry.key] = entry.value;
        }

        context.setTrailerMetadata(trailerMetadata);
      } else {
        try {
          // Пробуем получить мутабельную копию
          final mutable = context.toMutable();
          final trailerMetadata =
              Map<String, dynamic>.from(mutable.trailerMetadata ?? {});

          // Добавляем наши трейлерные метаданные
          for (final entry in _trailerMetadata.entries) {
            trailerMetadata[entry.key] = entry.value;
          }

          mutable.setTrailerMetadata(trailerMetadata);
        } catch (e) {
          // Если метода toMutable нет, просто игнорируем ошибку
        }
      }
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
    // Для ошибок также можем добавить трейлеры (если направление к клиенту)
    if (direction == RpcDataDirection.toRemote &&
        context is MutableRpcMethodContext) {
      final trailerMetadata =
          Map<String, dynamic>.from(context.trailerMetadata ?? {});

      // Добавляем метаданные об ошибке
      trailerMetadata['error'] = true;
      trailerMetadata['error_type'] = error.runtimeType.toString();

      context.setTrailerMetadata(trailerMetadata);
    }

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
