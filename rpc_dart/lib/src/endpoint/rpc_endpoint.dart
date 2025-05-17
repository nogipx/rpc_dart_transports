// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Типизированный RPC эндпоинт
base class RpcEndpoint extends _RpcEndpointRegistryImpl
    implements IRpcEndpoint {
  /// Создаёт новый типизированный RPC эндпоинт
  ///
  /// [transport] - транспорт для обмена сообщениями
  /// [serializer] - сериализатор для преобразования сообщений
  /// [debugLabel] - опциональная метка для отладки и логирования
  /// [uniqueIdGenerator] - генератор уникальных ID, по умолчанию используется [_defaultUniqueIdGenerator]
  /// [methodRegistry] - регистратор методов, по умолчанию используется [RpcMethodRegistry]
  RpcEndpoint({
    required super.transport,
    super.serializer = const MsgPackSerializer(),
    super.debugLabel,
    super.uniqueIdGenerator,
    IRpcMethodRegistry? methodRegistry,
  }) : super(methodRegistry: methodRegistry ?? RpcMethodRegistry());

  @override
  String toString() => 'RpcEndpoint[${debugLabel ?? ''}]';
}
