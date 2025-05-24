// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Минимальный пример для демонстрации логирования в RPC библиотеке
void main() async {
  // Настройка логгера
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
  final mainLogger = RpcLogger('Main');

  mainLogger.info('=== Минимальный пример RPC с диагностикой ===');

  try {
    // Создаем транспорты
    final clientTransport = MemoryTransport('client');
    final serverTransport = MemoryTransport('server');

    // Соединяем транспорты
    clientTransport.connect(serverTransport);
    serverTransport.connect(clientTransport);

    // Создаем эндпоинты
    final client = RpcEndpoint(transport: clientTransport);
    final server = RpcEndpoint(transport: serverTransport);

    // Создаем и регистрируем контракт сервиса на сервере
    final serverEchoService = ServerEchoService(mainLogger);
    server.registerServiceContract(serverEchoService);

    // Создаем и регистрируем контракт сервиса на клиенте
    final clientEchoService = ClientEchoService(client);
    client.registerServiceContract(clientEchoService);

    // Отправляем запрос
    mainLogger.info('Клиент отправляет запрос');

    final response = await clientEchoService.echo(
      EchoRequest(
        message: 'Hello from client',
        timestamp: DateTime.now().toIso8601String(),
      ),
    );

    mainLogger.info('Клиент получил ответ: ${response.message}');
    mainLogger.debug('Полный ответ:', data: response.toJson());

    // Закрываем соединения
    await client.close();
    await server.close();
  } catch (e, stack) {
    mainLogger.error('Произошла ошибка', error: e, stackTrace: stack);
  }

  mainLogger.info('=== Пример завершен ===');
}

/// Базовый контракт эхо-сервиса
abstract class EchoServiceContract extends OldRpcServiceContract {
  static const String echoMethodName = 'echo';

  EchoServiceContract() : super('EchoService');

  @override
  void setup() {
    super.setup();

    addUnaryRequestMethod<EchoRequest, EchoResponse>(
      methodName: echoMethodName,
      handler: echo,
      argumentParser: EchoRequest.fromJson,
      responseParser: EchoResponse.fromJson,
    );
  }

  /// Обработчик эхо-запроса
  Future<EchoResponse> echo(EchoRequest request);
}

/// Серверная реализация эхо-сервиса
class ServerEchoService extends EchoServiceContract {
  final RpcLogger logger;

  ServerEchoService(this.logger) : super();

  @override
  Future<EchoResponse> echo(EchoRequest request) async {
    logger.info('Сервер получил запрос: ${request.message}');

    // Имитация задержки
    await Future.delayed(Duration(milliseconds: 100));

    // Логируем обработку и исходящий ответ
    logger.debug(
      'Сервер обрабатывает запрос',
      data: {'message': request.message},
    );

    // Создаем ответ с дополнительными данными
    final response = EchoResponse(
      message: request.message,
      serverTimestamp: DateTime.now().toIso8601String(),
      processed: true,
    );

    logger.info('Сервер отправляет ответ: ${response.message}');
    return response;
  }
}

/// Клиентская реализация эхо-сервиса
class ClientEchoService extends EchoServiceContract {
  final RpcEndpoint endpoint;

  ClientEchoService(this.endpoint) : super();

  @override
  Future<EchoResponse> echo(EchoRequest request) async {
    return await endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: EchoServiceContract.echoMethodName,
        )
        .call<EchoRequest, EchoResponse>(
          request: request,
          responseParser: EchoResponse.fromJson,
        );
  }
}

/// Запрос для эхо-сервиса
class EchoRequest extends IRpcSerializableMessage {
  final String message;
  final String timestamp;

  EchoRequest({required this.message, required this.timestamp});

  @override
  Map<String, dynamic> toJson() => {'message': message, 'timestamp': timestamp};

  static EchoRequest fromJson(Map<String, dynamic> json) {
    return EchoRequest(
      message: json['message'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}

/// Ответ от эхо-сервиса
class EchoResponse extends IRpcSerializableMessage {
  final String message;
  final String serverTimestamp;
  final bool processed;

  EchoResponse({
    required this.message,
    required this.serverTimestamp,
    required this.processed,
  });

  @override
  Map<String, dynamic> toJson() => {
        'message': message,
        'server_timestamp': serverTimestamp,
        'processed': processed,
      };

  static EchoResponse fromJson(Map<String, dynamic> json) {
    return EchoResponse(
      message: json['message'] as String,
      serverTimestamp: json['server_timestamp'] as String,
      processed: json['processed'] as bool,
    );
  }
}
