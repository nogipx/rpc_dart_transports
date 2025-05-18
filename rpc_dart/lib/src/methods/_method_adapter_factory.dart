// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Фабрика для создания адаптеров методов
///
/// Предоставляет набор методов для создания адаптеров, преобразующих
/// методы для работы с [IRpcContext]
final class RpcMethodAdapterFactory {
  /// Создает адаптер для унарного обработчика
  ///
  /// Извлекает типизированный запрос из контекста и передает его обработчику
  ///
  /// [handler] - Обработчик унарного метода
  /// [argumentParser] - Функция для парсинга аргументов из JSON
  /// [debugLabel] - Метка для отладки (используется в сообщениях об ошибках)
  static Future<dynamic> Function(IRpcContext) createUnaryHandlerAdapter<
      Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>(
    RpcMethodUnaryHandler<Request, Response> handler,
    RpcMethodArgumentParser<Request> argumentParser,
    String debugLabel,
  ) {
    return (IRpcContext context) async {
      Request typedRequest;

      try {
        // Безопасное преобразование payload к типу Request
        if (context.payload is Request) {
          // Если payload уже имеет нужный тип - используем его напрямую
          typedRequest = context.payload as Request;
        } else if (context.payload is Map) {
          // Для Map используем парсер
          typedRequest =
              argumentParser(Map<String, dynamic>.from(context.payload as Map));
        } else if (context.payload == null) {
          // Для null создаем пустой Map и используем парсер
          typedRequest = argumentParser({});
        } else {
          // Для других случаев пытаемся использовать строковое представление
          typedRequest = argumentParser({'data': context.payload.toString()});
        }

        return handler(typedRequest);
      } catch (e, stackTrace) {
        throw RpcCustomException(
          customMessage:
              'Ошибка при обработке запроса: $e\nТип payload: ${context.payload.runtimeType}',
          debugLabel: debugLabel,
          error: e,
          stackTrace: stackTrace,
        );
      }
    };
  }

  /// Создает адаптер для обработчика серверного стрима
  ///
  /// Извлекает типизированный запрос из контекста и передает его обработчику стриминга
  ///
  /// [handler] - Обработчик серверного стрим-метода
  /// [argumentParser] - Функция для парсинга аргументов из JSON
  /// [debugLabel] - Метка для отладки (используется в сообщениях об ошибках)
  static Future<dynamic> Function(IRpcContext) createServerStreamHandlerAdapter<
      Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>(
    RpcMethodServerStreamHandler<Request, Response> handler,
    RpcMethodArgumentParser<Request> argumentParser,
    String debugLabel,
  ) {
    return (IRpcContext context) async {
      Request typedRequest;

      try {
        // Безопасное преобразование payload к типу Request
        if (context.payload is Request) {
          // Если payload уже имеет нужный тип - используем его напрямую
          typedRequest = context.payload as Request;
        } else if (context.payload is Map) {
          // Для Map используем парсер
          typedRequest =
              argumentParser(Map<String, dynamic>.from(context.payload as Map));
        } else if (context.payload == null) {
          // Для null создаем пустой Map и используем парсер
          typedRequest = argumentParser({});
        } else {
          // Для других случаев пытаемся использовать строковое представление
          typedRequest = argumentParser({'data': context.payload.toString()});
        }

        return handler(typedRequest);
      } catch (e, stackTrace) {
        throw RpcCustomException(
          customMessage:
              'Ошибка при обработке запроса: $e\nТип payload: ${context.payload.runtimeType}',
          debugLabel: debugLabel,
          error: e,
          stackTrace: stackTrace,
        );
      }
    };
  }

  /// Создает адаптер для обработчика клиентского стрима
  ///
  /// Для клиентского стрима не требуется запрос - просто вызываем обработчик
  ///
  /// [handler] - Обработчик клиентского стрим-метода
  static Future<dynamic> Function(IRpcContext) createClientStreamHandlerAdapter<
      Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>(
    RpcMethodClientStreamHandler<Request, Response> handler,
  ) {
    return (IRpcContext context) async {
      return handler();
    };
  }

  /// Создает адаптер для обработчика двунаправленного стрима
  ///
  /// Для двунаправленного стрима не требуется запрос - просто вызываем обработчик
  ///
  /// [handler] - Обработчик двунаправленного стрим-метода
  static Future<dynamic> Function(IRpcContext)
      createBidirectionalHandlerAdapter<Request extends IRpcSerializableMessage,
          Response extends IRpcSerializableMessage>(
    RpcMethodBidirectionalHandler<Request, Response> handler,
  ) {
    return (IRpcContext context) async {
      return handler();
    };
  }
}
