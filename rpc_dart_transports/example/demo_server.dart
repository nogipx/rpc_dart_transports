// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '_contract.dart';

/// Демонстрационный сервер
///
/// Обрабатывает RPC-запросы от клиентов и отправляет диагностические данные
/// в сервис диагностики.
///
/// Аргументы запуска:
/// --host=0.0.0.0 - хост для RPC-сервера (по умолчанию localhost)
/// --port=8888 - порт для RPC-сервера (по умолчанию 8888)
/// --diagnostic-url=ws://localhost:8080 - URL сервиса диагностики (по умолчанию ws://localhost:8080)
void main(List<String> args) async {
  // Парсим аргументы
  final host = _parseArg(args, 'host', 'localhost');
  final port = int.tryParse(_parseArg(args, 'port', '8888')) ?? 8888;
  final diagnosticUrl = _parseArg(args, 'diagnostic-url', 'ws://localhost:8080');

  // Создаем клиент диагностики
  final clientId = 'demo_server';
  final traceId = '${clientId}_${DateTime.now().millisecondsSinceEpoch}';

  // Устанавливаем диагностический клиент в логгер для автоматической отправки логов
  RpcLoggerSettings.setDiagnostic(factoryDiagnosticClient(
    serverUrl: Uri.parse(diagnosticUrl),
    clientId: clientId,
    traceId: traceId,
  ));

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
  final demoServer = DemoServer(logger);
  rpcEndpoint.registerServiceContract(demoServer);

  logger.info('Сервер запущен и ожидает подключений на ws://$host:$port');
  logger.info('Диагностические данные отправляются на $diagnosticUrl');

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
  final RpcLogger _logger;

  DemoServer(this._logger);

  @override
  Future<RpcString> echo(RpcString request) async {
    _logger.debug('Получен echo запрос: ${request.value}');
    return RpcString(request.value);
  }

  @override
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count) {
    _logger.debug('Запрошена генерация ${count.value} чисел');

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
    _logger.debug('Запущен метод подсчета слов');

    // Создаем генератор для клиентского стрима
    final generator = BidiStreamGenerator<RpcString, RpcInt>((requests) async* {
      int totalWords = 0;

      await for (final request in requests) {
        final words = request.value.split(' ').where((word) => word.isNotEmpty).length;
        totalWords += words;
        _logger.debug('Получено слов: $words, всего: $totalWords');
      }

      // После обработки всех входящих запросов, отправляем результат
      yield RpcInt(totalWords);
    });

    // Создаем и возвращаем стрим для клиента
    return generator.createClientStreaming();
  }

  @override
  BidiStream<RpcString, RpcString> chat() {
    _logger.debug('Запущен метод чата');

    // Создаем генератор для двунаправленного стрима
    final generator = BidiStreamGenerator<RpcString, RpcString>((requests) async* {
      // Обрабатываем все сообщения
      await for (final request in requests) {
        _logger.debug('Получено сообщение в чате: ${request.value}');
        yield RpcString('Сервер получил: ${request.value}');
      }
    });

    // Создаем и возвращаем двунаправленный стрим
    return generator.create();
  }
}

/// Вспомогательный класс для возврата информации о клиентском стриминге
class ClientStreamingInfo<T extends IRpcSerializableMessage, R extends IRpcSerializableMessage> {
  final StreamSink<T> stream;
  final Future<R> result;

  ClientStreamingInfo({
    required this.stream,
    required this.result,
  });
}

/// Парсит аргумент из командной строки
String _parseArg(List<String> args, String name, String defaultValue) {
  for (final arg in args) {
    if (arg.startsWith('--$name=')) {
      return arg.substring(arg.indexOf('=') + 1);
    }
  }
  return defaultValue;
}
