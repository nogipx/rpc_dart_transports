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

  /// Регистрирует реализацию метода (для внутреннего использования)
  void registerMethodImplementation({
    required String serviceName,
    required String methodName,
    required RpcMethodImplementation implementation,
  });

  /// Находит информацию о методе по имени сервиса и методу
  MethodRegistration? findMethod(
    String serviceName,
    String methodName,
  );

  /// Возвращает список всех зарегистрированных методов
  Iterable<MethodRegistration> getAllMethods();

  /// Возвращает список методов для конкретного сервиса
  Iterable<MethodRegistration> getMethodsForService(
    String serviceName,
  );

  /// Очищает весь реестр
  void clearMethodsRegistry();
}
