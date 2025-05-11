// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import '_index.dart';

typedef ProxyTransportSendFunction = Future<void> Function(Uint8List data);

/// Транспорт-прокси для перенаправления сообщений через произвольные потоки
class ProxyTransport implements RpcTransport {
  /// Идентификатор транспорта
  @override
  final String id;

  @override
  bool get isAvailable => _isAvailable;

  /// Контроллер потока входящих сообщений
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  /// Подписка на входящие сообщения
  StreamSubscription<dynamic>? _incomingSubscription;

  /// Функция для отправки данных
  final ProxyTransportSendFunction _sendFunction;

  /// Таймаут операций по умолчанию
  final Duration _defaultTimeout;

  /// Флаг, указывающий на доступность транспорта
  bool _isAvailable = false;

  /// Создает новый прокси-транспорт
  ///
  /// [id] - идентификатор транспорта
  /// [incomingStream] - поток входящих сообщений
  /// [sendFunction] - функция для отправки исходящих сообщений
  /// [timeout] - таймаут для операций (по умолчанию 30 секунд)
  ProxyTransport({
    required this.id,
    required Stream<dynamic> incomingStream,
    required ProxyTransportSendFunction sendFunction,
    Duration timeout = const Duration(seconds: 30),
  })  : _defaultTimeout = timeout,
        _sendFunction = sendFunction {
    _subscribeToIncomingStream(incomingStream);
    _isAvailable = true;
  }

  /// Подписывается на входящие сообщения из источника
  void _subscribeToIncomingStream(Stream<dynamic> incomingStream) {
    _incomingSubscription = incomingStream.listen(
      (dynamic data) {
        if (!_incomingController.isClosed) {
          if (data is String) {
            _incomingController.add(Uint8List.fromList(utf8.encode(data)));
          } else if (data is List<int>) {
            _incomingController.add(Uint8List.fromList(data));
          } else if (data is Uint8List) {
            _incomingController.add(data);
          }
        }
      },
      onError: (error) {
        if (!_incomingController.isClosed) {
          _incomingController.addError(error);
        }
      },
      onDone: () {
        _isAvailable = false;
        if (!_incomingController.isClosed) {
          _incomingController.close();
        }
      },
    );
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  @override
  Future<RpcTransportActionStatus> send(
    Uint8List data, {
    Duration? timeout,
  }) async {
    if (!isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    final effectiveTimeout = timeout ?? _defaultTimeout;

    try {
      await _sendFunction(data).timeout(
        effectiveTimeout,
        onTimeout: () => throw TimeoutException(
          'Истекло время ожидания отправки данных',
          effectiveTimeout,
        ),
      );

      return RpcTransportActionStatus.success;
    } on TimeoutException {
      return RpcTransportActionStatus.timeoutError;
    } catch (e) {
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  Future<RpcTransportActionStatus> close() async {
    _isAvailable = false;

    try {
      // Отменяем подписки
      await _incomingSubscription?.cancel();
      _incomingSubscription = null;

      // Закрываем контроллер
      if (!_incomingController.isClosed) {
        await _incomingController.close();
      }

      return RpcTransportActionStatus.success;
    } catch (e) {
      Zone.current.handleUncaughtError(
        Exception('Ошибка при закрытии прокси-транспорта: $e'),
        StackTrace.current,
      );
      return RpcTransportActionStatus.unknownError;
    }
  }
}
