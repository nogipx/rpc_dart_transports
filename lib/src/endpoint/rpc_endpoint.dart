// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Публичный интерфейс для RPC эндпоинта, объединяющий функциональность
// /// клиента, сервера и управления потоками.
// abstract interface class IRpcEndpoint<T extends RpcSerializableMessage>
//     implements IRpcEndpointCore<T>, IRpcRegistrar<T>, IRpcStreamController {}

/// Типизированный RPC эндпоинт
class RpcEndpoint<T extends IRpcSerializableMessage> extends _RpcEndpointImpl<T>
    implements IRpcEndpoint<T>, IRpcEndpointCore, IRpcRegistrar<T> {
  /// Создаёт новый типизированный RPC эндпоинт
  ///
  /// [transport] - транспорт для обмена сообщениями
  /// [serializer] - сериализатор для преобразования сообщений
  /// [debugLabel] - опциональная метка для отладки и логирования
  RpcEndpoint({
    required super.transport,
    required super.serializer,
    super.debugLabel,
  });

  @override
  String toString() =>
      'RpcEndpoint${debugLabel != null ? "($debugLabel)" : ""}';
}
