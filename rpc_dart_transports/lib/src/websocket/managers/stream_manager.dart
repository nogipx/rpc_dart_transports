// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

/// Менеджер потоков WebSocket транспорта
///
/// Отвечает за управление состоянием потоков и их жизненным циклом.
/// Выделен из WebSocketTransportBase для улучшения читаемости.
class WebSocketStreamManager {
  final RpcStreamIdManager _idManager;
  final RpcLogger? _logger;

  /// Активные потоки и их состояние отправки
  final Map<int, bool> _streamSendingFinished = <int, bool>{};

  WebSocketStreamManager({
    required RpcStreamIdManager idManager,
    RpcLogger? logger,
  })  : _idManager = idManager,
        _logger = logger?.child('StreamManager');

  /// Получает менеджер Stream ID
  RpcStreamIdManager get idManager => _idManager;

  /// Создает новый поток
  int createStream() {
    final streamId = _idManager.generateId();
    _streamSendingFinished[streamId] = false;
    _logger?.debug('Создан stream $streamId');
    return streamId;
  }

  /// Освобождает ID потока
  bool releaseStreamId(int streamId) {
    _streamSendingFinished.remove(streamId);

    final released = _idManager.releaseId(streamId);
    if (released) {
      _logger?.debug('Освобожден ID $streamId, активных потоков: ${_idManager.activeCount}');
    } else {
      _logger?.debug('ID уже был освобожден или никогда не использовался [streamId: $streamId]');
    }

    return released;
  }

  /// Проверяет, завершена ли отправка для потока
  bool isStreamSendingFinished(int streamId) {
    return _streamSendingFinished[streamId] ?? false;
  }

  /// Помечает поток как завершенный для отправки
  void markStreamSendingFinished(int streamId) {
    _streamSendingFinished[streamId] = true;
    _logger?.debug('Поток $streamId помечен как завершенный для отправки');
  }

  /// Обрабатывает завершение потока при получении END_STREAM
  void handleEndOfStream(int streamId) {
    _logger?.debug('Получен END_STREAM для stream $streamId');

    if (_idManager.isActive(streamId)) {
      _idManager.releaseId(streamId);
      _logger?.debug('Освобожден ID $streamId, активных потоков: ${_idManager.activeCount}');
    }

    // Также удаляем из состояния отправки
    _streamSendingFinished.remove(streamId);
  }

  /// Проверяет, активен ли поток
  bool isStreamActive(int streamId) {
    return _idManager.isActive(streamId);
  }

  /// Получает количество активных потоков
  int get activeCount => _idManager.activeCount;

  /// Получает список всех активных потоков
  List<int> get activeStreamIds => _streamSendingFinished.keys.toList();

  /// Очищает все потоки
  void clear() {
    _streamSendingFinished.clear();
    _idManager.reset();
    _logger?.debug('Все потоки очищены');
  }

  /// Получает отладочную информацию о состоянии потоков
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeStreams': _idManager.activeCount,
      'streamIds': _streamSendingFinished.keys.toList(),
      'sendingFinished': _streamSendingFinished.keys.toList(),
    };
  }
}
