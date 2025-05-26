// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Серверная часть серверного стриминга.
///
/// Получает один запрос и отправляет поток ответов.
/// Автоматически извлекает первый запрос из потока и вызывает
/// пользовательский обработчик, игнорируя все последующие запросы.
///
/// Пример использования:
/// ```dart
/// final server = ServerStreamServer<String, String>(
///   transport: serverTransport,
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
///   handler: (request, responder) {
///     // Обработка запроса
///     for (int i = 0; i < 5; i++) {
///       responder.sendResponse("Данные #$i");
///     }
///     responder.complete();
///   }
/// );
/// ```
final class ServerStreamResponder<TRequest, TResponse>
    implements IRpcResponder {
  late final RpcLogger? _logger;

  @override
  final int id;

  /// Внутренний сервер двунаправленного стрима
  late final BidirectionalStreamResponder<TRequest, TResponse> _innerServer;

  /// Подписка на входящие запросы
  StreamSubscription? _subscription;

  /// Создает сервер серверного стриминга
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "DataService")
  /// [methodName] Имя метода (например, "GetData")
  /// [requestCodec] Кодек для десериализации запроса
  /// [responseCodec] Кодек для сериализации ответов
  /// [handler] Функция-обработчик, вызываемая для обработки запроса
  /// [logger] Опциональный логгер
  ServerStreamResponder({
    this.id = 0,
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    required Stream<TResponse> Function(TRequest request) handler,
    RpcLogger? logger,
  }) {
    _logger = logger?.child('ServerResponder');
    _innerServer = BidirectionalStreamResponder<TRequest, TResponse>(
      id: id,
      transport: transport,
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
      logger: _logger,
    );
    unawaited(_setupRequestHandler(handler));
  }

  Future<void> _setupRequestHandler(
    Stream<TResponse> Function(TRequest request) handler,
  ) async {
    bool requestHandled = false;

    _subscription = _innerServer.requests.listen((request) async {
      if (!requestHandled) {
        requestHandled = true;

        try {
          // Оборачиваем вызов handler в try-catch для перехвата синхронных исключений
          final Stream<TResponse> handlerStream;
          try {
            handlerStream = handler(request);
          } catch (error, trace) {
            _logger?.error(
              'Синхронная ошибка при вызове обработчика',
              error: error,
              stackTrace: trace,
            );
            // Отправляем ошибку клиенту
            await _innerServer.sendError(RpcStatus.INTERNAL, error.toString());
            await close();
            return;
          }

          // Обрабатываем стрим ответов
          await for (final data in handlerStream) {
            await _innerServer.send(data);
          }

          // После завершения стрима, корректно закрываем соединение
          await _innerServer.finishReceiving();
        } on Object catch (error, trace) {
          _logger?.error(
            'Ошибка при обработке данных',
            error: error,
            stackTrace: trace,
          );
          // В случае асинхронной ошибки также отправляем ошибку клиенту
          await _innerServer.sendError(RpcStatus.INTERNAL, error.toString());
          await close();
        }
      }
      // Игнорируем все дополнительные запросы
    });
  }

  /// Закрывает стрим и освобождает ресурсы
  ///
  /// Полностью завершает стрим, освобождая все ресурсы.
  Future<void> close() async {
    await _subscription?.cancel();
    await _innerServer.close();
  }
}
