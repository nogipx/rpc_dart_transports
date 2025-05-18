// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'package:rpc_dart/diagnostics/models/rpc_client_identity.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '_contract.dart';

/// Демонстрационный сервер
///
/// Обрабатывает RPC-запросы от клиентов и отправляет диагностические данные
/// в сервис диагностики.
void main() async {
  // Парсим аргументы
  final host = '0.0.0.0';
  final port = 31000;
  final diagnosticUrl = 'ws://192.168.1.118:30000';

  // Создаем клиент диагностики
  final clientId = 'demo_server';
  final traceId = '${clientId}_${DateTime.now().millisecondsSinceEpoch}';

  // Настраиваем логирование
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
  final logger = DefaultRpcLogger(
    'DemoServer',
    coloredLoggingEnabled: true,
    logColors: RpcLoggerColors(
      debug: AnsiColor.cyan,
      info: AnsiColor.brightGreen,
      warning: AnsiColor.brightYellow,
      error: AnsiColor.brightRed,
      critical: AnsiColor.magenta,
    ),
  );

  logger.info('Запуск демонстрационного сервера...');
  logger.info('Настройка сервера на $host:$port');

  // Создаем сервер WebSocket для RPC
  final serverTransport = await ServerWebSocketTransport.create(
    host: host,
    port: port,
    id: 'demo_server',
    onClientConnected: (clientId, socket) {
      logger.info('Клиент подключен: $clientId');
    },
    onClientDisconnected: (clientId) {
      logger.info('Клиент отключен: $clientId');
    },
  );

  // Создаем RPC эндпоинт
  final rpcEndpoint = RpcEndpoint(
    transport: serverTransport,
    debugLabel: 'demo_server',
  );

  // Создаем сервер и регистрируем его методы
  final demoServer = DemoServer();
  rpcEndpoint.registerServiceContract(demoServer);

  logger.info('Сервер запущен и ожидает подключений на ws://$host:$port');
  logger.info('Диагностические данные отправляются на $diagnosticUrl');

  try {
    // Устанавливаем диагностический клиент в логгер для автоматической отправки логов
    final diagnosticClient = await factoryDiagnosticClient(
      diagnosticUrl: Uri.parse(diagnosticUrl),
      clientIdentity: RpcClientIdentity(
        clientId: clientId,
        traceId: traceId,
      ),
    );

    RpcLoggerSettings.setDiagnostic(diagnosticClient);
    logger.info('Диагностический клиент успешно инициализирован и подключен');
  } catch (e) {
    logger.error('Ошибка при инициализации диагностического клиента: $e');
  }

  // Обрабатываем сигналы завершения
  ProcessSignal.sigint.watch().listen((signal) async {
    logger.info('Получен сигнал завершения, закрываем сервер...');

    // Закрываем все соединения
    await rpcEndpoint.close();

    logger.info('Сервер остановлен');
    exit(0);
  });
}

final class DemoServer extends DemoServiceContract {
  DemoServer();

  @override
  Future<RpcString> echo(RpcString request) async {
    return RpcString(request.value);
  }

  @override
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count) {
    // Создаем генератор с функцией, которая принимает стрим запросов и возвращает стрим ответов
    final generator = BidiStreamGenerator<RpcInt, RpcString>((requests) async* {
      for (int i = 1; i <= count.value; i++) {
        await Future.delayed(Duration(milliseconds: 500));
        yield RpcString('Число $i');
      }
    });

    // Создаем и возвращаем стрим для сервера
    return generator.createServerStreaming(initialRequest: count);
  }

  @override
  ClientStreamingBidiStream<RpcString, RpcInt> countWords() {
    // Создаем генератор для клиентского стрима
    final generator = BidiStreamGenerator<RpcString, RpcInt>((requests) async* {
      int totalWords = 0;

      await for (final request in requests) {
        final words = request.value.split(' ').where((word) => word.isNotEmpty).length;
        totalWords += words;
      }

      // После обработки всех входящих запросов, отправляем результат
      yield RpcInt(totalWords);
    });

    // Создаем и возвращаем стрим для клиента
    return generator.createClientStreaming();
  }

  @override
  BidiStream<RpcString, RpcString> chat() {
    // Создаем генератор для двунаправленного стрима
    final generator = BidiStreamGenerator<RpcString, RpcString>((requests) async* {
      // Обрабатываем все сообщения
      await for (final request in requests) {
        yield RpcString('Сервер получил: ${request.value}');
      }
    });

    // Создаем и возвращаем двунаправленный стрим
    return generator.create();
  }
}
