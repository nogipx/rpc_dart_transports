// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:http2/http2.dart' as http2;
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Мощная демонстрация всех типов RPC с настоящим HTTP/2 транспортом! 🚀
Future<void> main() async {
  // Настраиваем красивое логирование для отладки
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  print('🚀 === ДЕМОНСТРАЦИЯ ВСЕХ ТИПОВ RPC С HTTP/2 ТРАНСПОРТОМ === 🚀\n');
  print('📱 Покажем Unary, Server Streaming, Client Streaming и Bidirectional!\n');

  // Запускаем HTTP/2 сервер с настоящим RPC обработчиком
  print('📡 Запуск HTTP/2 сервера с RPC обработчиком...');
  final serverPort = 8765;
  final rpcServer = await _startFullHttp2RpcServer(serverPort);

  try {
    // Даем серверу время на запуск
    await Future.delayed(Duration(milliseconds: 500));

    // Создаем HTTP/2 клиента
    print('🔌 Подключение HTTP/2 клиента...');
    final transport = await Http2ClientTransport.connect(
      host: 'localhost',
      port: serverPort,
      logger: RpcLogger('Http2Client'),
    );

    try {
      // Создаем клиентский endpoint
      final callerEndpoint = RpcCallerEndpoint(
        transport: transport,
        debugLabel: 'HttpClientEndpoint',
      );

      print('\n🎯 === ДЕМОНСТРАЦИЯ ВСЕХ ТИПОВ RPC === 🎯\n');

      // 1. Unary RPC - один запрос, один ответ
      await _demonstrateUnaryRpc(callerEndpoint);

      // 2. Server Streaming RPC - один запрос, множество ответов
      await _demonstrateServerStreamingRpc(callerEndpoint);

      // 3. Client Streaming RPC - множество запросов, один ответ
      await _demonstrateClientStreamingRpc(callerEndpoint);

      // 4. Bidirectional Streaming RPC - множество запросов, множество ответов
      await _demonstrateBidirectionalRpc(callerEndpoint);

      print('\n🎉 === ВСЕ ТИПЫ RPC РАБОТАЮТ ОТЛИЧНО! === 🎉');
      print('🔥 HTTP/2 транспорт показал себя на все 100%!');
    } finally {
      await transport.close();
      print('\n🔌 HTTP/2 клиент закрыт');
    }
  } finally {
    await rpcServer.stop();
    print('📡 HTTP/2 сервер остановлен');
  }
}

/// 1. Демонстрация Unary RPC (один запрос -> один ответ)
Future<void> _demonstrateUnaryRpc(RpcCallerEndpoint endpoint) async {
  print('🎯 1. UNARY RPC - Echo сервис');
  print('   Отправляем: "Hello, HTTP/2 Unary World!"');

  try {
    final response = await endpoint.unaryRequest<RpcString, RpcString>(
      serviceName: 'DemoService',
      methodName: 'Echo',
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      request: RpcString('Hello, HTTP/2 Unary World!'),
    );

    print('   ✅ Получили: "${response.value}"');
  } catch (e) {
    print('   ❌ Ошибка: $e');
  }
  print('');
}

/// 2. Демонстрация Server Streaming RPC (один запрос -> поток ответов)
Future<void> _demonstrateServerStreamingRpc(RpcCallerEndpoint endpoint) async {
  print('🎯 2. SERVER STREAMING RPC - поток данных от сервера');
  print('   Запрашиваем: поток из 5 сообщений');

  try {
    final responseStream = endpoint.serverStream<RpcString, RpcString>(
      serviceName: 'DemoService',
      methodName: 'GetStream',
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      request: RpcString('Дайте мне HTTP/2 поток!'),
    );

    int count = 0;
    await for (final response in responseStream) {
      count++;
      print('   📨 Сообщение $count: "${response.value}"');
    }
    print('   ✅ Получили $count сообщений от HTTP/2 сервера');
  } catch (e) {
    print('   ❌ Ошибка: $e');
  }
  print('');
}

/// 3. Демонстрация Client Streaming RPC (поток запросов -> один ответ)
Future<void> _demonstrateClientStreamingRpc(RpcCallerEndpoint endpoint) async {
  print('🎯 3. CLIENT STREAMING RPC - отправляем поток HTTP/2 серверу');
  print('   Отправляем: 4 сообщения серверу');

  try {
    final messages = [
      RpcString('HTTP/2 сообщение #1'),
      RpcString('HTTP/2 сообщение #2'),
      RpcString('HTTP/2 сообщение #3'),
      RpcString('HTTP/2 сообщение #4'),
    ];

    // Создаем Stream заново каждый раз, чтобы избежать "already listened to"
    Stream<RpcString> createRequestStream() {
      return Stream.fromIterable(messages).asyncMap((msg) async {
        print('   📤 Отправляем: "${msg.value}"');
        await Future.delayed(Duration(milliseconds: 200));
        return msg;
      });
    }

    final getResponse = endpoint.clientStream<RpcString, RpcString>(
      serviceName: 'DemoService',
      methodName: 'AccumulateMessages',
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      requests: createRequestStream(),
    );

    final response = await getResponse();
    print('   ✅ Итоговый ответ: "${response.value}"');
  } catch (e) {
    print('   ❌ Ошибка: $e');
  }
  print('');
}

/// 4. Демонстрация Bidirectional Streaming RPC (поток запросов <-> поток ответов)
Future<void> _demonstrateBidirectionalRpc(RpcCallerEndpoint endpoint) async {
  print('🎯 4. BIDIRECTIONAL STREAMING RPC - HTTP/2 чат в реальном времени');
  print('   Устанавливаем двустороннюю HTTP/2 связь');

  try {
    final messages = [
      RpcString('Привет, HTTP/2 сервер!'),
      RpcString('Как дела с мультиплексированием?'),
      RpcString('HTTP/2 рулит!'),
    ];

    final requestStream = Stream.fromIterable(messages).asyncMap((msg) async {
      await Future.delayed(Duration(milliseconds: 300));
      print('   📤 Отправляем: "${msg.value}"');
      return msg;
    });

    final responseStream = endpoint.bidirectionalStream<RpcString, RpcString>(
      serviceName: 'DemoService',
      methodName: 'Chat',
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      requests: requestStream,
    );

    int count = 0;
    await for (final response in responseStream) {
      count++;
      print('   📨 Ответ $count: "${response.value}"');
    }
    print('   ✅ HTTP/2 чат завершен! Обменялись $count сообщениями');
  } catch (e) {
    print('   ❌ Ошибка: $e');
  }
  print('');
}

/// Запускает полноценный HTTP/2 RPC сервер
Future<_Http2RpcServer> _startFullHttp2RpcServer(int port) async {
  final logger = RpcLogger('Http2Server');

  // Создаем настоящий HTTP/2 сервер
  final serverSocket = await ServerSocket.bind('localhost', port);
  logger.debug('HTTP/2 сервер запущен на порту $port');

  final server = _Http2RpcServer(serverSocket, logger);
  await server.start();

  return server;
}

/// Полноценный HTTP/2 RPC сервер
class _Http2RpcServer {
  final ServerSocket _serverSocket;
  final RpcLogger _logger;
  final List<StreamSubscription> _subscriptions = [];
  final List<RpcResponderEndpoint> _responderEndpoints = [];
  bool _isRunning = false;

  _Http2RpcServer(this._serverSocket, this._logger);

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    _logger.debug('Запуск HTTP/2 RPC сервера');

    final subscription = _serverSocket.listen((socket) {
      _handleConnection(socket);
    });

    _subscriptions.add(subscription);
    print('🚀 HTTP/2 RPC сервер готов принимать соединения');
  }

  void _handleConnection(Socket socket) {
    print('📞 Новое HTTP/2 подключение от ${socket.remoteAddress}:${socket.remotePort}');

    try {
      // Создаем HTTP/2 соединение и серверный транспорт
      final connection = http2.ServerTransportConnection.viaSocket(socket);
      final serverTransport = Http2ServerTransport.create(
        connection: connection,
        logger: _logger,
      );

      // Создаем RpcResponderEndpoint с HTTP/2 транспортом
      final responderEndpoint = RpcResponderEndpoint(
        transport: serverTransport,
        debugLabel: 'Http2ServerEndpoint',
      );
      _responderEndpoints.add(responderEndpoint);

      // Регистрируем демо-сервис
      _registerDemoService(responderEndpoint);

      // Запускаем endpoint
      responderEndpoint.start();

      print('✅ RPC endpoint запущен для подключения ${socket.remoteAddress}');
    } catch (e) {
      print('❌ Ошибка при создании HTTP/2 RPC соединения: $e');
      socket.destroy();
    }
  }

  void _registerDemoService(RpcResponderEndpoint endpoint) {
    final contract = _DemoServiceContract();
    endpoint.registerServiceContract(contract);
    print('📋 Зарегистрирован DemoService с ${contract.methods.length} методами');
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    _logger.debug('Остановка HTTP/2 RPC сервера');

    // Закрываем все подписки
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // Закрываем все RPC endpoints
    for (final endpoint in _responderEndpoints) {
      await endpoint.close();
    }
    _responderEndpoints.clear();

    // Закрываем серверный сокет
    await _serverSocket.close();

    print('🛑 HTTP/2 RPC сервер остановлен');
  }
}

/// Контракт демонстрационного RPC сервиса для HTTP/2
final class _DemoServiceContract extends RpcResponderContract {
  _DemoServiceContract() : super('DemoService');

  @override
  void setup() {
    // 1. Unary RPC - Echo метод
    addUnaryMethod<RpcString, RpcString>(
      methodName: 'Echo',
      handler: (request) async {
        final message = request.value;
        print('🔄 HTTP/2 Echo: получен "$message"');
        return RpcString('HTTP/2 Echo: $message');
      },
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      description: 'Возвращает то же сообщение с HTTP/2 префиксом Echo',
    );

    // 2. Server Streaming RPC - поток данных
    addServerStreamMethod<RpcString, RpcString>(
      methodName: 'GetStream',
      handler: (request) async* {
        final message = request.value;
        print('🔄 HTTP/2 GetStream: запрос "$message"');

        for (int i = 1; i <= 5; i++) {
          await Future.delayed(Duration(milliseconds: 200));
          yield RpcString('HTTP/2 поток #$i из 5: ответ на "$message"');
        }
        print('🔄 HTTP/2 GetStream: завершен');
      },
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      description: 'Отправляет поток из 5 HTTP/2 сообщений',
    );

    // 3. Client Streaming RPC - накопление сообщений
    addClientStreamMethod<RpcString, RpcString>(
      methodName: 'AccumulateMessages',
      handler: (requestStream) async {
        print('🔄 HTTP/2 AccumulateMessages: начат');

        final messages = <String>[];
        await for (final request in requestStream) {
          messages.add(request.value);
          print('🔄 HTTP/2 AccumulateMessages: получено "${request.value}"');
        }

        final result = 'HTTP/2 накоплено ${messages.length} сообщений: ${messages.join(", ")}';
        print('🔄 HTTP/2 AccumulateMessages: завершен с результатом');
        return RpcString(result);
      },
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      description: 'Накапливает все HTTP/2 сообщения и возвращает сводку',
    );

    // 4. Bidirectional Streaming RPC - чат
    addBidirectionalMethod<RpcString, RpcString>(
      methodName: 'Chat',
      handler: (requestStream) async* {
        print('🔄 HTTP/2 Chat: начат');

        await for (final request in requestStream) {
          final message = request.value;
          print('🔄 HTTP/2 Chat: получено "$message"');

          // Отвечаем с небольшой задержкой для реалистичности
          await Future.delayed(Duration(milliseconds: 100));
          yield RpcString('HTTP/2 сервер отвечает на: $message');
        }

        print('🔄 HTTP/2 Chat: завершен');
      },
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
      description: 'Интерактивный HTTP/2 чат с эхо-ответами',
    );
  }
}
