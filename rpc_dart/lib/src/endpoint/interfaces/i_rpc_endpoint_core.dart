// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Публичный интерфейс для управления потоками данных в RPC.
/// Предоставляет методы для отправки данных в поток и закрытия потока.
abstract interface class IRpcEndpointCore {
  /// Вызывает удаленный унарный метод
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - данные запроса
  /// [timeout] - таймаут ожидания ответа
  /// [metadata] - дополнительные метаданные
  Future<dynamic> invoke({
    required String serviceName,
    required String methodName,
    required dynamic request,
    Duration? timeout,
    Map<String, dynamic>? metadata,
  });

  /// Открывает поток данных от удаленной стороны
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - начальный запрос (опционально)
  /// [metadata] - дополнительные метаданные
  /// [streamId] - опциональный ID для потока
  Stream<dynamic> openStream({
    required String serviceName,
    required String methodName,
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  });

  /// Отправляет данные в открытый поток
  ///
  /// [streamId] - идентификатор потока
  /// [data] - данные для отправки
  /// [metadata] - дополнительные метаданные
  /// [serviceName] - имя сервиса (опционально)
  /// [methodName] - имя метода (опционально)
  Future<void> sendStreamData({
    required String streamId,
    required dynamic data,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Отправляет ошибку в поток
  ///
  /// [streamId] - идентификатор потока
  /// [errorMessage] - сообщение об ошибке
  /// [metadata] - дополнительные метаданные
  Future<void> sendStreamError({
    required String streamId,
    required String errorMessage,
    Map<String, dynamic>? metadata,
  });

  /// Закрывает поток данных
  ///
  /// [streamId] - идентификатор потока
  /// [metadata] - дополнительные метаданные
  /// [serviceName] - имя сервиса (опционально)
  /// [methodName] - имя метода (опционально)
  Future<void> closeStream({
    required String streamId,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });
}
