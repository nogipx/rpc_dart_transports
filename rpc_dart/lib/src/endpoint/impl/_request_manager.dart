// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Менеджер запросов для хранения и управления запросами, ожидающими ответа
final class _RequestManager {
  /// Обработчики ожидающих ответов
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  /// Регистрирует новый запрос и возвращает Completer для его обработки
  Completer<dynamic> registerRequest(String requestId) {
    final completer = Completer<dynamic>();
    _pendingRequests[requestId] = completer;
    return completer;
  }

  /// Получает Completer для запроса по ID
  Completer<dynamic>? getRequest(String requestId) {
    return _pendingRequests[requestId];
  }

  /// Получает и удаляет Completer для запроса по ID
  Completer<dynamic>? getAndRemoveRequest(String requestId) {
    return _pendingRequests.remove(requestId);
  }

  /// Завершает запрос с результатом
  void completeRequest(String requestId, dynamic result) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  /// Завершает запрос с ошибкой
  void completeRequestWithError(String requestId, dynamic error) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  /// Завершает все ожидающие запросы с ошибкой
  void completeAllWithError(String errorMessage) {
    for (final entry in _pendingRequests.entries) {
      final completer = entry.value;
      if (!completer.isCompleted) {
        completer.completeError(errorMessage);
      }
    }
    _pendingRequests.clear();
  }

  /// Проверяет, существует ли запрос с указанным ID
  bool hasRequest(String requestId) {
    return _pendingRequests.containsKey(requestId);
  }

  /// Возвращает количество ожидающих запросов
  int get pendingRequestCount => _pendingRequests.length;
}
