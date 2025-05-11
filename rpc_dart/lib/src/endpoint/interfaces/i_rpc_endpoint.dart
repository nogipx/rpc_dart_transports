// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Публичный интерфейс для клиентской стороны RPC.
/// Предоставляет методы для вызова удаленных процедур.
abstract interface class IRpcEndpoint<T extends IRpcSerializableMessage> {
  /// Транспорт, используемый для отправки и получения сообщений
  RpcTransport get transport;

  /// Сериализатор для преобразования сообщений
  RpcSerializer get serializer;

  /// Флаг, указывающий активность эндпоинта
  bool get isActive;

  /// Метка для отладки, используется для идентификации эндпоинта в логах
  String? get debugLabel;

  /// Создает объект унарного метода
  UnaryRequestRpcMethod<T> unaryRequest({
    required String serviceName,
    required String methodName,
  });

  /// Создает объект метода с серверным стримингом
  ServerStreamingRpcMethod<T> serverStreaming({
    required String serviceName,
    required String methodName,
  });

  /// Создает объект метода с клиентским стримингом
  ClientStreamingRpcMethod<T> clientStreaming({
    required String serviceName,
    required String methodName,
  });

  /// Создает объект метода с двунаправленным стримингом
  BidirectionalStreamingRpcMethod<T> bidirectionalStreaming({
    required String serviceName,
    required String methodName,
  });

  /// Добавляет middleware для обработки запросов и ответов
  ///
  /// [middleware] - объект, реализующий интерфейс RpcMiddleware
  void addMiddleware(IRpcMiddleware middleware);

  /// Закрывает клиентский эндпоинт и освобождает ресурсы
  Future<void> close();

  /// Получает контракт сервиса по имени
  IRpcServiceContract<T>? getServiceContract(String serviceName);

  /// Генерирует уникальный ID
  String generateUniqueId([String? prefix]);
}
