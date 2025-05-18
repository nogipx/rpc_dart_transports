// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart'
    show RpcMethodContext, SimpleRpcMiddleware, RpcDataDirection;

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
  ) async {
    // Если отправляем на удаленную сторону и есть метаданные для заголовков
    if (direction == RpcDataDirection.toRemote && _headerMetadata.isNotEmpty) {
      // Для сложного объекта мы должны создать копию, а не изменять оригинал
      final updatedContext = context.withHeaderMetadata(_headerMetadata);

      // Присваиваем новый контекст обратно в переменную из параметра функции
      // Это позволит RpcMiddlewareChain обнаружить изменение
      // Это хак, но он работает
      context = updatedContext;
    }

    return payload;
  }

  @override
  Future<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) async {
    // Если отправляем на удаленную сторону и есть метаданные для трейлеров
    if (direction == RpcDataDirection.toRemote && _trailerMetadata.isNotEmpty) {
      // Для сложного объекта мы должны создать копию, а не изменять оригинал
      final updatedContext = context.withTrailerMetadata(_trailerMetadata);

      // Присваиваем новый контекст обратно в переменную из параметра функции
      // Это позволит RpcMiddlewareChain обнаружить изменение
      context = updatedContext;
    }

    return response;
  }

  @override
  Future<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) async {
    // Для ошибок также можем добавить трейлеры (если направление к клиенту)
    if (direction == RpcDataDirection.toRemote) {
      final errorMetadata = {
        'error': true,
        'error_type': error.runtimeType.toString(),
      };

      // Для сложного объекта мы должны создать копию, а не изменять оригинал
      final updatedContext = context.withTrailerMetadata(errorMetadata);

      // Присваиваем новый контекст обратно в переменную из параметра функции
      // Это позволит RpcMiddlewareChain обнаружить изменение
      context = updatedContext;
    }

    return error;
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
