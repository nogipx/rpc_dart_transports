// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/io.dart';

/// Простой пример использования WebSocket транспорта
void main() async {
  // Устанавливаем уровень логирования DEBUG
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Запускаем сервер
  final server = await HttpServer.bind('localhost', 8080);
  print('Сервер запущен на http://localhost:8080');

  // Создаем контракт серверной стороны
  final serverContract = EchoResponderContract();

  // Обрабатываем соединения от клиентов
  server.listen((request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        // Преобразуем HTTP запрос в WebSocket
        final socket = await WebSocketTransformer.upgrade(request);
        print('Новое WebSocket соединение');

        // Создаем WebSocket канал из сокета
        final channel = IOWebSocketChannel(socket);

        // Создаем транспорт на основе канала
        final transport = RpcWebSocketResponderTransport(
          channel,
          logger: RpcLogger('ServerWebSocket'),
        );

        // Создаем серверный эндпоинт
        final endpoint = RpcResponderEndpoint(
            transport: transport, debugLabel: 'ServerEndpoint');

        // Регистрируем контракт
        endpoint.registerServiceContract(serverContract);

        // Запускаем эндпоинт
        endpoint.start();

        // Обрабатываем закрытие соединения
        socket.done.then((_) {
          print('WebSocket соединение закрыто');
          endpoint.close();
        });
      } catch (e) {
        print('Ошибка при обработке WebSocket подключения: $e');
      }
    }
  });

  // Запускаем клиент
  Timer(Duration(seconds: 1), () => runClient());
}

/// Запускает клиентскую часть примера
void runClient() async {
  print('\nЗапуск клиента...');

  // Создаем клиентский транспорт
  final transport = RpcWebSocketCallerTransport.connect(
    Uri.parse('ws://localhost:8080'),
    logger: RpcLogger('ClientWebSocket'),
  );

  // Создаем клиентский эндпоинт
  final endpoint = RpcCallerEndpoint(
    transport: transport,
    debugLabel: 'ClientEndpoint',
  );

  // Создаем контракт клиентской стороны
  final contract = EchoCallerContract(endpoint);

  // Отправляем унарный запрос
  print('\nОтправка унарного запроса...');
  final response = await contract.echo('Привет, WebSocket RPC!');
  print('Ответ от сервера: $response');

  // Тестируем стрим от сервера
  print('\nТестирование серверного стрима...');
  try {
    final serverStream = contract.countTo(5);
    await for (final number in serverStream) {
      print('Получено из серверного стрима: $number');
    }
  } catch (e) {
    print('Ошибка в серверном стриме: $e');
  }

  // Тестируем стрим от клиента
  print('\nТестирование клиентского стрима...');
  try {
    // Создаем асинхронный стрим с задержками, чтобы ClientStreamCaller успел подписаться
    final numbers =
        Stream.periodic(Duration(milliseconds: 100), (i) => i + 1).take(5);
    final sum = await contract.sum(numbers);
    print('Сумма: $sum');
  } catch (e) {
    print('Ошибка в клиентском стриме: $e');
  }

  // Тестируем двунаправленный стрим
  print('\nТестирование двунаправленного стрима...');
  try {
    final bidiStream = contract.echo2(
      Stream.periodic(Duration(milliseconds: 500), (i) => 'Сообщение $i')
          .take(5),
    );

    await for (final msg in bidiStream) {
      print('Получено из двунаправленного стрима: $msg');
    }
  } catch (e) {
    print('Ошибка в двунаправленном стриме: $e');
  }

  // Закрываем соединение
  print('\nЗавершение работы...');
  await endpoint.close();
  exit(0);
}

// --- Контракты для примера ---

/// Серверный контракт для примера
base class EchoResponderContract extends RpcResponderContract {
  EchoResponderContract() : super('echo') {
    // Унарный метод
    addUnaryMethod<StringMessage, StringMessage>(
      methodName: 'echo',
      requestCodec:
          RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
      responseCodec:
          RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
      handler: (request) async {
        print('Сервер получил запрос: ${request.value}');
        return StringMessage(request.value);
      },
    );

    // Серверный стрим
    addServerStreamMethod<IntMessage, IntMessage>(
      methodName: 'countTo',
      requestCodec: RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
      responseCodec: RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
      handler: (request) {
        final count = request.value;
        print('Сервер запускает стрим до $count');
        return Stream.periodic(
          Duration(milliseconds: 500),
          (i) => IntMessage(i + 1),
        ).take(count);
      },
    );

    // Клиентский стрим
    addClientStreamMethod<IntMessage, IntMessage>(
      methodName: 'sum',
      requestCodec: RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
      responseCodec: RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
      handler: (stream) async {
        print('Сервер получает стрим чисел');
        int sum = 0;
        await for (final msg in stream) {
          print('  Получено число: ${msg.value}');
          sum += msg.value;
        }
        return IntMessage(sum);
      },
    );

    // Двунаправленный стрим
    addBidirectionalMethod<StringMessage, StringMessage>(
      methodName: 'echo2',
      requestCodec:
          RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
      responseCodec:
          RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
      handler: (stream) {
        print('Сервер запускает двунаправленный стрим');
        return stream.map((message) {
          print('  Сервер получил: ${message.value}');
          return StringMessage('Эхо: ${message.value}');
        });
      },
    );
  }
}

/// Клиентский контракт для примера
base class EchoCallerContract extends RpcCallerContract {
  EchoCallerContract(RpcCallerEndpoint endpoint) : super('echo', endpoint);

  /// Унарный запрос
  Future<String> echo(String message) async {
    final response = await endpoint.unaryRequest<StringMessage, StringMessage>(
      serviceName: serviceName,
      methodName: 'echo',
      requestCodec:
          RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
      responseCodec:
          RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
      request: StringMessage(message),
    );
    return response.value;
  }

  /// Серверный стрим
  Stream<int> countTo(int count) {
    return endpoint
        .serverStream<IntMessage, IntMessage>(
          serviceName: serviceName,
          methodName: 'countTo',
          requestCodec:
              RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
          responseCodec:
              RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
          request: IntMessage(count),
        )
        .map((msg) => msg.value);
  }

  /// Клиентский стрим
  Future<int> sum(Stream<int> numbers) async {
    final numberMessages = numbers.map((n) => IntMessage(n));
    final finishSending = endpoint.clientStream<IntMessage, IntMessage>(
      serviceName: serviceName,
      methodName: 'sum',
      requestCodec: RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
      responseCodec: RpcCodec<IntMessage>((json) => IntMessage.fromJson(json)),
      requests: numberMessages,
    );

    final response = await finishSending();
    return response.value;
  }

  /// Двунаправленный стрим
  Stream<String> echo2(Stream<String> messages) {
    final messageStream = messages.map((m) => StringMessage(m));
    return endpoint
        .bidirectionalStream<StringMessage, StringMessage>(
          serviceName: serviceName,
          methodName: 'echo2',
          requestCodec:
              RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
          responseCodec:
              RpcCodec<StringMessage>((json) => StringMessage.fromJson(json)),
          requests: messageStream,
        )
        .map((msg) => msg.value);
  }
}

// --- Простые сообщения ---

/// Сообщение со строковым значением
class StringMessage implements IRpcSerializable {
  final String value;

  StringMessage(this.value);

  @override
  Map<String, dynamic> toJson() => {'value': value};

  factory StringMessage.fromJson(Map<String, dynamic> json) {
    return StringMessage(json['value'] as String);
  }
}

/// Сообщение с целочисленным значением
class IntMessage implements IRpcSerializable {
  final int value;

  IntMessage(this.value);

  @override
  Map<String, dynamic> toJson() => {'value': value};

  factory IntMessage.fromJson(Map<String, dynamic> json) {
    return IntMessage(json['value'] as int);
  }
}
