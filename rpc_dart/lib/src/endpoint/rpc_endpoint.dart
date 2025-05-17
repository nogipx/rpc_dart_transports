// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Типизированный RPC эндпоинт
class RpcEndpoint<T extends IRpcSerializableMessage> extends _RpcEndpointImpl<T>
    implements IRpcEndpoint<T>, IRpcEndpointCore, IRpcRegistrar<T> {
  /// Создаёт новый типизированный RPC эндпоинт
  ///
  /// [transport] - транспорт для обмена сообщениями
  /// [serializer] - сериализатор для преобразования сообщений
  /// [debugLabel] - опциональная метка для отладки и логирования
  /// [uniqueIdGenerator] - генератор уникальных ID, по умолчанию используется [_defaultUniqueIdGenerator]
  RpcEndpoint({
    required super.transport,
    super.serializer = const MsgPackSerializer(),
    super.debugLabel,
    super.uniqueIdGenerator,
  });

  @override
  String toString() => 'RpcEndpoint[${debugLabel ?? ''}]';
}
