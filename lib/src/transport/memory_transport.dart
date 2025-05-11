// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import '_index.dart';

/// Реализация транспорта, работающая в памяти
///
/// Используется для тестирования и для коммуникации
/// между компонентами в рамках одного процесса
class MemoryTransport implements RpcTransport {
  /// Идентификатор транспорта
  @override
  final String id;

  /// Контроллер для публикации входящих сообщений
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  /// Пункт назначения сообщений
  MemoryTransport? _destination;

  /// Флаг доступности транспорта
  bool _isAvailable = true;

  /// Таймаут операций по умолчанию
  final Duration _defaultTimeout;

  /// Создает новый экземпляр в памяти
  ///
  /// [id] - уникальный идентификатор транспорта
  /// [timeout] - таймаут операций по умолчанию
  MemoryTransport(
    this.id, {
    Duration timeout = const Duration(seconds: 30),
  }) : _defaultTimeout = timeout;

  /// Соединяет текущий транспорт с другим транспортом
  ///
  /// [destination] - транспорт-получатель сообщений
  /// Возвращает destination для создания цепочек
  MemoryTransport connect(MemoryTransport destination) {
    _destination = destination;
    return destination;
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data,
      {Duration? timeout}) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;

    if (!isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    if (_destination == null) {
      return RpcTransportActionStatus.connectionNotEstablished;
    }

    try {
      // Имитируем небольшую задержку при отправке сообщения
      await Future.delayed(const Duration(milliseconds: 1)).timeout(
        effectiveTimeout,
        onTimeout: () => throw TimeoutException(
          'Истекло время ожидания отправки данных',
          effectiveTimeout,
        ),
      );

      // Отправляем данные в пункт назначения
      final destination = _destination;
      if (destination != null && destination._isAvailable) {
        destination._receiveData(data);
        return RpcTransportActionStatus.success;
      } else {
        return RpcTransportActionStatus.connectionClosed;
      }
    } on TimeoutException {
      return RpcTransportActionStatus.timeoutError;
    } catch (e) {
      Zone.current.handleUncaughtError(
        Exception('Ошибка при отправке данных: $e'),
        StackTrace.current,
      );
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  /// Обрабатывает входящие данные
  void _receiveData(Uint8List data) {
    if (!_isAvailable) return;

    if (!_incomingController.isClosed) {
      _incomingController.add(data);
    }
  }

  @override
  Future<RpcTransportActionStatus> close() async {
    _isAvailable = false;
    try {
      if (!_incomingController.isClosed) {
        await _incomingController.close();
      }
      return RpcTransportActionStatus.success;
    } catch (e) {
      Zone.current.handleUncaughtError(
        Exception('Ошибка при закрытии транспорта: $e'),
        StackTrace.current,
      );
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  bool get isAvailable => _isAvailable;
}
