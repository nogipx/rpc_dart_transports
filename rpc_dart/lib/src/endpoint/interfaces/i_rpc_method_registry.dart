// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Интерфейс реестра методов RPC
/// Предоставляет методы для управления регистрацией и поиском сервисных контрактов и их методов
abstract interface class IRpcMethodRegistry {
  /// Возвращает зарегистрированный контракт сервиса по имени
  IRpcServiceContract<IRpcSerializableMessage>? getServiceContract(
    String serviceName,
  );

  /// Возвращает все зарегистрированные контракты
  Map<String, IRpcServiceContract<IRpcSerializableMessage>> getAllContracts();

  /// Регистрирует сервисный контракт и все его методы
  void registerContract(
    IRpcServiceContract<IRpcSerializableMessage> contract,
  );

  /// Регистрирует отдельный метод
  void registerMethod({
    required String serviceName,
    required String methodName,
    required dynamic handler,
    Function? argumentParser,
    RpcMethodType? methodType,
    Function? responseParser,
  });

  /// Регистрирует напрямую конкретный тип метода
  void registerDirectMethod<Req extends IRpcSerializableMessage,
      Resp extends IRpcSerializableMessage>({
    required String serviceName,
    required String methodName,
    required RpcMethodType methodType,
    required dynamic handler,
    required Req Function(dynamic) argumentParser,
    Resp Function(dynamic)? responseParser,
    RpcMethodContract<Req, Resp>? methodContract,
  });

  /// Находит информацию о методе по имени сервиса и методу
  MethodRegistration<IRpcSerializableMessage, IRpcSerializableMessage>?
      findMethod(
    String serviceName,
    String methodName,
  );

  /// Возвращает список всех зарегистрированных методов
  Iterable<MethodRegistration<IRpcSerializableMessage, IRpcSerializableMessage>>
      getAllMethods();

  /// Возвращает список методов для конкретного сервиса
  Iterable<MethodRegistration<IRpcSerializableMessage, IRpcSerializableMessage>>
      getMethodsForService(
    String serviceName,
  );

  /// Очищает весь реестр
  void clearMethodsRegistry();
}
