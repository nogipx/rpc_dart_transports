// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../models/example_models.dart';

/// Пример использования композитного контракта
void useCompositeContract() {
  // Создаем транспорт для примера
  final transport = MemoryTransport('example_transport');

  // Создаем основной контракт
  final rootContract = RpcCompositeContract<ExampleMessage>('AppService');

  // Создаем подконтракты для разных модулей приложения
  final userContract = RpcCompositeContract<ExampleMessage>('UserService');
  final authContract = RpcCompositeContract<ExampleMessage>('AuthService');
  final contentContract = RpcCompositeContract<ExampleMessage>(
    'ContentService',
  );

  // Настраиваем контракты
  _setupUserContract(userContract);
  _setupAuthContract(authContract);
  _setupContentContract(contentContract);

  // Добавляем подконтракты в корневой контракт
  rootContract.addSubContract(userContract);
  rootContract.addSubContract(authContract);
  rootContract.addSubContract(contentContract);

  // Теперь rootContract содержит все методы из подконтрактов
  // и может быть зарегистрирован в RPC эндпоинте
  final endpoint = RpcEndpoint<ExampleMessage>(transport: transport);
  endpoint.registerServiceContract(rootContract);
}

/// Создание веб-модулей с использованием только композитных контрактов
void useModularApproach() {
  // Создаем транспорт для примера
  final transport = MemoryTransport('example_transport');

  // Создаем основной контракт
  final rootContract = RpcCompositeContract<ExampleMessage>('AppService');

  // Создаем модуль пользователей (напрямую)
  _addUserModule(rootContract, prefix: 'user');

  // Или создаем и добавляем отдельный контракт для аутентификации
  final authContract = RpcCompositeContract<ExampleMessage>('AuthService');
  _setupAuthContract(authContract);
  rootContract.addSubContract(authContract);

  // Регистрируем контракт в эндпоинте
  final endpoint = RpcEndpoint<ExampleMessage>(transport: transport);
  endpoint.registerServiceContract(rootContract);
}

// Добавляет методы для пользователей напрямую в контракт с префиксом
void _addUserModule(
  RpcCompositeContract<ExampleMessage> contract, {
  String? prefix,
}) {
  final methodPrefix = prefix != null ? '$prefix.' : '';

  contract.addUnaryRequestMethod<UserRequest, UserResponse>(
    methodName: '${methodPrefix}getUser',
    handler: (req) async => UserResponse(),
    argumentParser: (json) => UserRequest.fromJson(json),
    responseParser: (json) => UserResponse.fromJson(json),
  );

  contract.addServerStreamingMethod<UserRequest, UserResponse>(
    methodName: '${methodPrefix}getUserUpdates',
    handler: (request) {
      // Создаем контроллер для отправки данных клиенту
      final stream = StreamController<UserResponse>();

      // Имитация отправки данных
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (timer.tick > 5 || stream.isClosed) {
          timer.cancel();
          stream.close();
          return;
        }
        stream.add(UserResponse(userName: 'User ${timer.tick}'));
      });

      // Создаем ServerStreamingBidiStream
      return ServerStreamingBidiStream<UserRequest, UserResponse>(
        stream: stream.stream,
        sendFunction: (_) {}, // Не используется в серверном стриме
        closeFunction: () async {
          await stream.close();
        },
      );
    },
    argumentParser: (json) => UserRequest.fromJson(json),
    responseParser: (json) => UserResponse.fromJson(json),
  );
}

// Вспомогательные методы для настройки контрактов
void _setupUserContract(RpcCompositeContract<ExampleMessage> contract) {
  contract.addUnaryRequestMethod<UserRequest, UserResponse>(
    methodName: 'getUser',
    handler: (req) async => UserResponse(),
    argumentParser: (json) => UserRequest.fromJson(json),
    responseParser: (json) => UserResponse.fromJson(json),
  );

  contract.addServerStreamingMethod<UserRequest, UserResponse>(
    methodName: 'getUserUpdates',
    handler: (request) {
      // Создаем контроллер для отправки данных клиенту
      final stream = StreamController<UserResponse>();

      // Имитация отправки данных
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (timer.tick > 5 || stream.isClosed) {
          timer.cancel();
          stream.close();
          return;
        }
        stream.add(UserResponse(userName: 'User ${timer.tick}'));
      });

      // Создаем ServerStreamingBidiStream
      return ServerStreamingBidiStream<UserRequest, UserResponse>(
        stream: stream.stream,
        sendFunction: (_) {}, // Не используется в серверном стриме
        closeFunction: () async {
          await stream.close();
        },
      );
    },
    argumentParser: (json) => UserRequest.fromJson(json),
    responseParser: (json) => UserResponse.fromJson(json),
  );
}

void _setupAuthContract(RpcCompositeContract<ExampleMessage> contract) {
  contract.addUnaryRequestMethod<AuthRequest, AuthResponse>(
    methodName: 'login',
    handler: (req) async => AuthResponse(),
    argumentParser: (json) => AuthRequest.fromJson(json),
    responseParser: (json) => AuthResponse.fromJson(json),
  );

  contract.addUnaryRequestMethod<AuthRequest, AuthResponse>(
    methodName: 'logout',
    handler: (req) async => AuthResponse(),
    argumentParser: (json) => AuthRequest.fromJson(json),
    responseParser: (json) => AuthResponse.fromJson(json),
  );
}

void _setupContentContract(RpcCompositeContract<ExampleMessage> contract) {
  contract.addServerStreamingMethod<ContentRequest, ContentResponse>(
    methodName: 'getContent',
    handler: (request) {
      // Создаем контроллер для отправки данных клиенту
      final stream = StreamController<ContentResponse>();

      // Имитация отправки данных контента
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (timer.tick > 3 || stream.isClosed) {
          timer.cancel();
          stream.close();
          return;
        }
        stream.add(
          ContentResponse(
            title: 'Content ${timer.tick}',
            content: 'Lorem ipsum ${request.contentId} - ${timer.tick}',
          ),
        );
      });

      // Создаем ServerStreamingBidiStream
      return ServerStreamingBidiStream<ContentRequest, ContentResponse>(
        stream: stream.stream,
        sendFunction: (_) {}, // Не используется в серверном стриме
        closeFunction: () async {
          await stream.close();
        },
      );
    },
    argumentParser: (json) => ContentRequest.fromJson(json),
    responseParser: (json) => ContentResponse.fromJson(json),
  );
}
