// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import '_index.dart'
    show
        RpcMethodContract,
        RpcMethodType,
        IRpcServiceContract,
        IRpcSerializableMessage,
        RpcServiceContract;
import 'typedefs.dart';

/// Модуль контракта - класс для организации контрактов по модулям
///
/// Модуль контракта - это обычный контракт с дополнительной информацией о модуле.
/// Каждый модуль относится к определенному сервису и может быть зарегистрирован
/// в этом сервисе.
abstract base class RpcContractModule<T extends IRpcSerializableMessage>
    extends RpcServiceContract<T> {
  /// Родительский контракт, в который будет добавлен этот модуль
  final IRpcServiceContract<T> parentContract;

  /// Префикс для методов этого модуля (опционально)
  final String? methodPrefix;

  RpcContractModule(this.parentContract, {this.methodPrefix});

  @override
  String get serviceName => parentContract.serviceName;

  /// Инициализирует и регистрирует методы в родительском контракте
  @override
  void setup() {
    configureModuleMethods();
    _registerMethodsInParent();
  }

  /// Метод для конфигурации методов модуля
  /// Должен быть переопределен в дочерних классах
  void configureModuleMethods();

  /// Регистрирует все методы модуля в родительском контракте
  void _registerMethodsInParent() {
    if (parentContract is! RpcServiceContract) {
      throw UnsupportedError(
        'Родительский контракт должен быть экземпляром RpcServiceContract',
      );
    }

    for (final method in methods) {
      // Добавляем префикс к имени метода, если он указан
      final String fullMethodName = methodPrefix != null
          ? '$methodPrefix.${method.methodName}'
          : method.methodName;

      final argParser = getMethodArgumentParser(method.methodName);
      final respParser = getMethodResponseParser(method.methodName);
      final handler = getMethodHandler(method.methodName);

      if (argParser == null || respParser == null || handler == null) {
        throw StateError(
          'Не удалось получить парсеры или обработчик для метода ${method.methodName}',
        );
      }

      switch (method.methodType) {
        case RpcMethodType.unary:
          parentContract.addUnaryRequestMethod(
            methodName: fullMethodName,
            handler: handler,
            argumentParser: argParser,
            responseParser: respParser,
          );
          break;
        case RpcMethodType.serverStreaming:
          parentContract.addServerStreamingMethod(
            methodName: fullMethodName,
            handler: handler,
            argumentParser: argParser,
            responseParser: respParser,
          );
          break;
        case RpcMethodType.clientStreaming:
          parentContract.addClientStreamingMethod(
            methodName: fullMethodName,
            handler: handler,
            argumentParser: argParser,
            responseParser: respParser,
          );
          break;
        case RpcMethodType.bidirectional:
          parentContract.addBidirectionalStreamingMethod(
            methodName: fullMethodName,
            handler: handler,
            argumentParser: argParser,
            responseParser: respParser,
          );
          break;
      }
    }
  }
}
