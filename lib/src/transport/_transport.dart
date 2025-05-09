// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:typed_data';

/// Результат операции транспорта
enum RpcTransportActionStatus {
  /// Операция выполнена успешно
  success,

  /// Транспорт недоступен
  transportUnavailable,

  /// Транспорт не инициализирован
  transportNotInitialized,

  /// Соединение закрыто
  connectionClosed,

  /// Соединение не установлено
  connectionNotEstablished,

  /// Неизвестная ошибка при выполнении операции
  unknownError;

  /// Проверяет, успешно ли выполнена операция
  bool get isSuccess => this == RpcTransportActionStatus.success;
}

/// Абстракция транспортного уровня для передачи данных
abstract interface class RpcTransport {
  /// Уникальный идентификатор транспорта
  String get id;

  /// Отправляет сообщение через транспорт
  ///
  /// [data] - данные для отправки
  /// Возвращает Future с результатом операции:
  /// - TransportOperationResult.success если отправка прошла успешно
  /// - другие значения enum в случае различных ошибок
  Future<RpcTransportActionStatus> send(Uint8List data);

  /// Получает поток сообщений из транспорта
  ///
  /// Возвращает Stream, в котором будут появляться входящие сообщения
  Stream<Uint8List> receive();

  /// Закрывает транспорт и освобождает ресурсы
  ///
  /// Возвращает Future с результатом операции:
  /// - TransportOperationResult.success если закрытие прошло успешно
  /// - другие значения enum в случае различных ошибок
  Future<RpcTransportActionStatus> close();

  /// Возвращает true, если транспорт доступен для отправки и получения сообщений
  bool get isAvailable;
}
