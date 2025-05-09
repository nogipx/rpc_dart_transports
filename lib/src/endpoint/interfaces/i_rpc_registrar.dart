// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Публичный интерфейс для клиентской стороны RPC.
/// Предоставляет методы для вызова удаленных процедур.
abstract interface class IRpcRegistrar<T extends IRpcSerializableMessage> {
  /// Регистрирует контракт сервиса
  ///
  /// [contract] - объект, реализующий интерфейс IRpcServiceContract
  void registerServiceContract(IRpcServiceContract<T> contract);

  /// Регистрирует обработчик метода
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [handler] - функция обработки запроса, которая принимает контекст вызова
  void registerMethod(
    String serviceName,
    String methodName,
    Future<dynamic> Function(RpcMethodContext) handler,
  );

  /// Регистрирует реализацию метода (для внутреннего использования)
  void registerMethodImplementation(
    String serviceName,
    String methodName,
    RpcMethodImplementation implementation,
  );
}
