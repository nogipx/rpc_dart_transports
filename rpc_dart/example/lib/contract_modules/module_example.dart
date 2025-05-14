// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

import '../models/example_models.dart';

/// Пример использования композитного контракта
void useCompositeContract() {
  // Создаем основной контракт
  final rootContract = RpcCompositeContract<ExampleMessage>('AppService');

  // Создаем подконтракты для разных модулей приложения
  final userContract = SimpleRpcServiceContract('UserService');
  final authContract = SimpleRpcServiceContract('AuthService');
  final contentContract = SimpleRpcServiceContract('ContentService');

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
  final endpoint = RpcEndpoint.create<ExampleMessage>();
  endpoint.registerServiceContract(rootContract);
}

/// Пример использования модулей контрактов
void useContractModules() {
  // Создаем основной контракт
  final rootContract = SimpleRpcServiceContract('AppService');

  // Создаем модули и регистрируем их в корневом контракте
  final userModule = UserModule(rootContract, methodPrefix: 'user');
  final authModule = AuthModule(rootContract, methodPrefix: 'auth');
  final contentModule = ContentModule(rootContract);

  // Настраиваем модули (вызывает их setup())
  userModule.setup();
  authModule.setup();
  contentModule.setup();

  // Регистрируем основной контракт в эндпоинте
  final endpoint = RpcEndpoint.create<ExampleMessage>();
  endpoint.registerServiceContract(rootContract);
}

// Вспомогательные методы для настройки контрактов
void _setupUserContract(RpcServiceContract<ExampleMessage> contract) {
  contract.addUnaryRequestMethod<UserRequest, UserResponse>(
    methodName: 'getUser',
    handler: (req) async => UserResponse(),
    argumentParser: (json) => UserRequest.fromJson(json),
    responseParser: (json) => UserResponse.fromJson(json),
  );

  contract.addServerStreamingMethod<UserRequest, UserResponse>(
    methodName: 'getUserUpdates',
    handler: () {
      final controller = ServerStreamingBidiStream<UserRequest, UserResponse>();
      // Логика обработки
      return controller;
    },
    argumentParser: (json) => UserRequest.fromJson(json),
    responseParser: (json) => UserResponse.fromJson(json),
  );
}

void _setupAuthContract(RpcServiceContract<ExampleMessage> contract) {
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

void _setupContentContract(RpcServiceContract<ExampleMessage> contract) {
  contract.addServerStreamingMethod<ContentRequest, ContentResponse>(
    methodName: 'getContent',
    handler: () {
      final controller =
          ServerStreamingBidiStream<ContentRequest, ContentResponse>();
      // Логика обработки
      return controller;
    },
    argumentParser: (json) => ContentRequest.fromJson(json),
    responseParser: (json) => ContentResponse.fromJson(json),
  );
}

// Примеры модулей контрактов

class UserModule extends RpcContractModule<ExampleMessage> {
  UserModule(super.parentContract, {super.methodPrefix});

  @override
  void configureModuleMethods() {
    addUnaryRequestMethod<UserRequest, UserResponse>(
      methodName: 'getUser',
      handler: (req) async => UserResponse(),
      argumentParser: (json) => UserRequest.fromJson(json),
      responseParser: (json) => UserResponse.fromJson(json),
    );

    addServerStreamingMethod<UserRequest, UserResponse>(
      methodName: 'getUserUpdates',
      handler: () {
        final controller =
            ServerStreamingBidiStream<UserRequest, UserResponse>();
        // Логика обработки
        return controller;
      },
      argumentParser: (json) => UserRequest.fromJson(json),
      responseParser: (json) => UserResponse.fromJson(json),
    );
  }
}

class AuthModule extends RpcContractModule<ExampleMessage> {
  AuthModule(super.parentContract, {super.methodPrefix});

  @override
  void configureModuleMethods() {
    addUnaryRequestMethod<AuthRequest, AuthResponse>(
      methodName: 'login',
      handler: (req) async => AuthResponse(),
      argumentParser: (json) => AuthRequest.fromJson(json),
      responseParser: (json) => AuthResponse.fromJson(json),
    );

    addUnaryRequestMethod<AuthRequest, AuthResponse>(
      methodName: 'logout',
      handler: (req) async => AuthResponse(),
      argumentParser: (json) => AuthRequest.fromJson(json),
      responseParser: (json) => AuthResponse.fromJson(json),
    );
  }
}

class ContentModule extends RpcContractModule<ExampleMessage> {
  ContentModule(super.parentContract, {super.methodPrefix});

  @override
  void configureModuleMethods() {
    addServerStreamingMethod<ContentRequest, ContentResponse>(
      methodName: 'getContent',
      handler: () {
        final controller =
            ServerStreamingBidiStream<ContentRequest, ContentResponse>();
        // Логика обработки
        return controller;
      },
      argumentParser: (json) => ContentRequest.fromJson(json),
      responseParser: (json) => ContentResponse.fromJson(json),
    );
  }
}
