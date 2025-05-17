// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Абстрактный базовый класс для RPC-конечных точек
///
/// Этот класс определяет общий публичный интерфейс для всех RPC-конечных точек.
/// Для типизированной реализации используйте [RpcEndpoint].
abstract interface class IRpcEngine {
  /// Транспорт для отправки/получения сообщений
  IRpcTransport get transport;

  /// Сериализатор для преобразования сообщений
  IRpcSerializer get serializer;

  /// Реестр методов
  IRpcMethodRegistry get registry;

  /// Добавляет middleware для обработки запросов и ответов
  void addMiddleware(IRpcMiddleware middleware);

  /// Регистрирует отдельный метод
  void registerMethod({
    required String serviceName,
    required String methodName,
    required RpcMethodType methodType,
    required dynamic handler,
    required Function argumentParser,
    Function? responseParser,
  });

  /// Вызывает удаленный метод и возвращает результат
  Future<dynamic> invoke({
    required String serviceName,
    required String methodName,
    required dynamic request,
    Duration? timeout,
    Map<String, dynamic>? metadata,
  });

  /// Открывает поток данных от удаленной стороны
  Stream<dynamic> openStream({
    required String serviceName,
    required String methodName,
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  });

  /// Отправляет данные в поток
  Future<void> sendStreamData({
    required String streamId,
    required dynamic data,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Отправляет сигнал об ошибке в поток
  Future<void> sendStreamError({
    required String streamId,
    required String errorMessage,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Отправляет маркер завершения потока в клиентском стриминге
  /// Это специальный метод, который избегает проблем с приведением типов
  Future<void> sendClientStreamEnd({
    required String streamId,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  });

  /// Закрывает поток
  Future<void> closeStream({
    required String streamId,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Проверяет, активна ли конечная точка
  bool get isActive;

  /// Закрывает конечную точку
  Future<void> close();

  /// Генерирует уникальный ID
  String generateUniqueId([String? prefix]);

  /// Отправляет ping-сообщение для проверки соединения
  /// Возвращает Future, который завершится когда придет ответ или произойдет таймаут
  Future<Duration> sendPing({Duration? timeout});

  /// Отправляет любой служебный маркер
  /// Унифицированный метод для отправки любых типов маркеров
  ///
  /// [streamId] - ID потока или соединения
  /// [marker] - служебный маркер для отправки
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  /// [metadata] - дополнительные метаданные
  Future<void> sendServiceMarker({
    required String streamId,
    required RpcServiceMarker marker,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  });

  /// Отправляет маркер статуса операции
  ///
  /// [requestId] - ID запроса или операции
  /// [statusCode] - код статуса операции
  /// [message] - описание статуса или ошибки
  /// [details] - дополнительные детали (опционально)
  /// [metadata] - дополнительные метаданные (опционально)
  Future<void> sendStatus({
    required String requestId,
    required RpcStatusCode statusCode,
    required String message,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Устанавливает deadline для операции
  ///
  /// [requestId] - ID запроса или операции
  /// [timeout] - таймаут для операции
  /// [metadata] - дополнительные метаданные (опционально)
  Future<void> setDeadline({
    required String requestId,
    required Duration timeout,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Отменяет операцию
  ///
  /// [operationId] - ID операции для отмены
  /// [reason] - причина отмены (опционально)
  /// [details] - дополнительные детали (опционально)
  Future<void> cancelOperation({
    required String operationId,
    String? reason,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });
}
