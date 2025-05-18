// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Менеджер потоков для хранения и управления активными потоками данных
final class _StreamManager {
  /// Контроллеры потоков данных
  final Map<String, StreamController<dynamic>> _streamControllers = {};

  /// Создает или возвращает существующий поток по ID
  Stream<dynamic> getOrCreateStream(String streamId) {
    // Если поток с таким ID уже существует, возвращаем его
    if (_streamControllers.containsKey(streamId)) {
      return _streamControllers[streamId]!.stream;
    }

    // Иначе создаем новый контроллер потока
    final controller = StreamController<dynamic>.broadcast();
    _streamControllers[streamId] = controller;
    return controller.stream;
  }

  /// Получает контроллер потока по ID
  StreamController<dynamic>? getStreamController(String streamId) {
    return _streamControllers[streamId];
  }

  /// Получает и удаляет контроллер потока по ID
  StreamController<dynamic>? removeStreamController(String streamId) {
    return _streamControllers.remove(streamId);
  }

  /// Добавляет данные в поток по его ID
  void addDataToStream(String streamId, dynamic data) {
    final controller = _streamControllers[streamId];
    if (controller != null && !controller.isClosed) {
      controller.add(data);
    }
  }

  /// Добавляет ошибку в поток по его ID
  void addErrorToStream(String streamId, dynamic error) {
    final controller = _streamControllers[streamId];
    if (controller != null && !controller.isClosed) {
      controller.addError(error);
    }
  }

  /// Закрывает поток по его ID
  void closeStream(String streamId) {
    final controller = _streamControllers.remove(streamId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  /// Закрывает все активные потоки
  void closeAllStreams() {
    for (final controller in _streamControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streamControllers.clear();
  }

  /// Добавляет ошибку во все потоки и закрывает их
  void closeAllStreamsWithError(String errorMessage) {
    for (final controller in _streamControllers.values) {
      if (!controller.isClosed) {
        controller.addError(errorMessage);
        controller.close();
      }
    }
    _streamControllers.clear();
  }

  /// Проверяет, существует ли поток с указанным ID
  bool hasStream(String streamId) {
    return _streamControllers.containsKey(streamId);
  }

  /// Возвращает количество активных потоков
  int get activeStreamCount => _streamControllers.length;
}
