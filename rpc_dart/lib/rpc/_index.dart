import 'dart:async';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:rpc_dart/rpc/_example/isolate_example.dart';
import 'package:rpc_dart/rpc_dart.dart';

part 'core/rpc.dart';
part 'core/message.dart';
part 'core/parser.dart';
part 'core/transport.dart';

part 'transports/isolate_transport.dart';
part 'transports/in_memory_transport.dart';

part '_example/in_memory_example.dart';

part 'streams/bidirectional_stream.dart';

/// Фабрика для создания обработчиков двунаправленных стримов.
///
/// Абстрактный интерфейс, который должны реализовать обработчики
/// бизнес-логики для преобразования потока запросов в поток ответов.
/// Это основной контракт для обработки двунаправленных стримов на сервере.
abstract class BidirectionalStreamHandlerFactory<TRequest, TResponse> {
  /// Обрабатывает поток запросов и создает поток ответов.
  ///
  /// Преобразует входящий поток запросов в исходящий поток ответов
  /// в соответствии с бизнес-логикой. Реализации могут обрабатывать
  /// запросы как последовательно, так и асинхронно.
  ///
  /// [requests] Входящий поток запросов от клиента
  /// Возвращает поток ответов для отправки клиенту
  Stream<TResponse> handle(Stream<TRequest> requests);
}

/// Сервер gRPC для обработки RPC вызовов.
///
/// Абстрактный интерфейс сервера gRPC, реализации которого должны
/// обеспечивать прослушивание TCP-порта, обработку HTTP/2 соединений
/// и маршрутизацию вызовов к соответствующим обработчикам сервисов.
abstract class GrpcServer {
  /// Запускает сервер на указанном порту.
  ///
  /// Начинает прослушивание входящих соединений на указанном TCP-порту
  /// и обработку gRPC запросов.
  ///
  /// [port] Порт для прослушивания
  /// Возвращает Future, который завершается при успешном запуске
  Future<void> start(int port);

  /// Регистрирует сервис с обработчиком.
  ///
  /// Добавляет обработчик для указанного метода сервиса,
  /// чтобы сервер мог маршрутизировать входящие запросы
  /// к соответствующей бизнес-логике.
  ///
  /// [serviceName] Имя сервиса (часть пути RPC)
  /// [methodName] Имя метода (часть пути RPC)
  /// [handlerFactory] Фабрика для создания обработчиков запросов
  /// [requestCodec] Кодек для десериализации запросов
  /// [responseCodec] Кодек для сериализации ответов
  void registerService<TRequest, TResponse>(
      String serviceName,
      String methodName,
      BidirectionalStreamHandlerFactory<TRequest, TResponse> handlerFactory,
      IRpcSerializer<TRequest> requestCodec,
      IRpcSerializer<TResponse> responseCodec);

  /// Останавливает сервер.
  ///
  /// Прекращает прослушивание входящих соединений и
  /// завершает все активные соединения. Освобождает ресурсы.
  ///
  /// Возвращает Future, который завершается при успешной остановке
  Future<void> stop();
}
