// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Типы сообщений, используемые в gRPC-подобном протоколе
enum RpcMessageType {
  /// Неизвестный тип сообщения
  unknown,

  /// Контракт с описанием возможностей
  contract,

  /// Запрос вызова метода
  request,

  /// Ответ на запрос
  response,

  /// Данные, передаваемые в потоке
  streamData,

  /// Сигнал о завершении потока
  streamEnd,

  /// Сообщение об ошибке
  error,

  /// Запрос проверки соединения
  ping,

  /// Ответ на запрос проверки соединения
  pong,
  ;

  static RpcMessageType fromString(String? type) {
    if (type == null) {
      return RpcMessageType.unknown;
    }
    return RpcMessageType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => RpcMessageType.unknown,
    );
  }
}
