// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'processors/message_processor.dart';
import 'processors/message_encoder.dart';
import 'managers/stream_manager.dart';

/// Базовый класс для WebSocket транспорта
///
/// Содержит общую логику для клиентской и серверной реализаций.
/// Рефакторен для использования компонентной архитектуры.
abstract class RpcWebSocketTransportBase implements IRpcTransport {
  /// WebSocket канал для обмена сообщениями
  final WebSocketChannel _channel;

  /// Контроллер для управления потоком входящих сообщений
  final StreamController<RpcTransportMessage> _incomingController =
      StreamController<RpcTransportMessage>.broadcast();

  /// Флаг закрытия транспорта
  bool _closed = false;

  /// Менеджер потоков
  late final WebSocketStreamManager _streamManager;

  /// Обработчик входящих сообщений
  late final WebSocketMessageProcessor _messageProcessor;

  /// Кодировщик исходящих сообщений
  late final WebSocketMessageEncoder _messageEncoder;

  /// Логгер для отладки
  final RpcLogger? _logger;

  /// Создает новый базовый WebSocket транспорт
  ///
  /// [channel] WebSocket канал для коммуникации
  /// [logger] Опциональный логгер для отладки
  RpcWebSocketTransportBase(
    this._channel, {
    RpcLogger? logger,
  }) : _logger = logger {
    // Инициализируем компоненты
    _streamManager = WebSocketStreamManager(
      idManager: idManager,
      logger: _logger,
    );

    _messageProcessor = WebSocketMessageProcessor(
      logger: _logger,
    );

    _messageEncoder = WebSocketMessageEncoder(
      logger: _logger,
    );

    _setupListener();
  }

  /// Получает менеджер Stream ID (реализуется в подклассах)
  RpcStreamIdManager get idManager;

  /// Устанавливает слушатель для входящих WebSocket сообщений
  void _setupListener() {
    _logger?.debug('Устанавливаем слушатель WebSocket');
    _channel.stream.listen(
      _handleIncomingMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
    _logger?.debug('Слушатель WebSocket установлен');
  }

  /// Обрабатывает входящее WebSocket сообщение
  void _handleIncomingMessage(dynamic message) {
    try {
      final transportMessages = _messageProcessor.processIncomingMessage(message);

      for (final transportMessage in transportMessages) {
        // Обрабатываем завершение потока
        if (transportMessage.isEndOfStream) {
          _streamManager.handleEndOfStream(transportMessage.streamId);
        }

        // Добавляем в поток входящих сообщений
        _incomingController.add(transportMessage);
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при обработке входящего сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Обрабатывает ошибку WebSocket соединения
  void _handleError(Object error, StackTrace stackTrace) {
    _logger?.error(
      'Ошибка WebSocket соединения: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Обрабатывает закрытие WebSocket соединения
  void _handleDone() {
    _logger?.info('WebSocket соединение закрыто');
    close();
  }

  @override
  Stream<RpcTransportMessage> get incomingMessages => _incomingController.stream;

  @override
  Stream<RpcTransportMessage> getMessagesForStream(int streamId) {
    return incomingMessages.where((message) => message.streamId == streamId);
  }

  @override
  int createStream() {
    if (_closed) {
      throw StateError('WebSocket транспорт закрыт');
    }

    return _streamManager.createStream();
  }

  @override
  bool releaseStreamId(int streamId) {
    if (_closed) return false;

    return _streamManager.releaseStreamId(streamId);
  }

  @override
  Future<void> sendMetadata(
    int streamId,
    RpcMetadata metadata, {
    bool endStream = false,
  }) async {
    if (_closed) return;

    try {
      // Сохраняем путь метода в процессоре
      if (metadata.methodPath != null) {
        _messageProcessor.setMethodPath(streamId, metadata.methodPath!);
      }

      // Кодируем и отправляем метаданные
      final encodedMessage = _messageEncoder.encodeMetadata(
        streamId,
        metadata,
        endStream: endStream,
      );

      _channel.sink.add(encodedMessage);
      _logger?.debug(
          'Отправлены метаданные для stream $streamId, endStream: $endStream, path: ${metadata.methodPath}');

      if (endStream) {
        _streamManager.markStreamSendingFinished(streamId);
      }
    } catch (e, stackTrace) {
      _logger?.error('Ошибка при отправке метаданных: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> sendMessage(
    int streamId,
    Uint8List data, {
    bool endStream = false,
  }) async {
    if (_closed) {
      _logger?.warning('Попытка отправить данные после закрытия транспорта');
      return;
    }

    try {
      // Получаем путь метода из процессора
      final methodPath = _messageProcessor.getMethodPath(streamId);

      // Кодируем и отправляем данные
      final encodedMessage = _messageEncoder.encodeMessage(
        streamId,
        data,
        endStream: endStream,
        methodPath: methodPath,
      );

      _channel.sink.add(encodedMessage);
      _logger?.debug(
          'Отправлено бинарное сообщение для stream $streamId, размер: ${data.length} байт, endStream: $endStream');

      if (endStream) {
        _streamManager.markStreamSendingFinished(streamId);
        _streamManager.releaseStreamId(streamId);
      }
    } catch (e, stackTrace) {
      _logger?.error(
        'Ошибка при отправке сообщения: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> finishSending(int streamId) async {
    if (_closed) return;

    if (_streamManager.isStreamSendingFinished(streamId)) {
      _logger?.debug('Стрим $streamId уже завершен, пропускаем отправку флага завершения');
      return;
    }

    try {
      _logger?.debug('Отправка флага завершения потока для ID $streamId');

      // Получаем путь метода из процессора
      final methodPath = _messageProcessor.getMethodPath(streamId);

      // Кодируем и отправляем завершение потока
      final encodedMessage = _messageEncoder.encodeStreamEnd(
        streamId,
        methodPath: methodPath,
      );

      _channel.sink.add(encodedMessage);

      _streamManager.markStreamSendingFinished(streamId);
      _streamManager.releaseStreamId(streamId);
    } catch (e, stackTrace) {
      _logger?.error('Ошибка при завершении отправки: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;

    _closed = true;

    // Очищаем все компоненты
    _streamManager.clear();
    _messageProcessor.clear();

    try {
      await _channel.sink.close();
      _logger?.info('WebSocket транспорт закрыт');
    } catch (e) {
      _logger?.error('Ошибка при закрытии WebSocket: $e');
      rethrow;
    }
  }
}
