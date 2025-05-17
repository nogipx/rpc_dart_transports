// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:developer' as dev;

import 'package:rpc_dart/rpc_dart.dart';

/// Реализация транспорта для коммуникации между Isolate через порты
class IsolateTransport implements IRpcTransport {
  /// Таймаут для установки соединения между изолятами (мс)
  static const _connectionTimeout = Duration(seconds: 5);

  /// Идентификатор транспорта
  @override
  final String id;

  /// Порт для отправки сообщений
  final SendPort _sendPort;

  /// Порт для получения сообщений
  final ReceivePort _receivePort;

  /// Контроллер для публикации входящих сообщений
  final StreamController<Uint8List> _incomingController = StreamController<Uint8List>.broadcast();

  /// Контроллер для отслеживания состояния соединения
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();

  /// Флаг доступности транспорта
  bool _isAvailable = true;

  /// Флаг инициализации соединения
  bool _isInitialized = false;

  /// Флаг включения логирования
  final bool _logEnabled;

  /// Подписка на сообщения из ReceivePort
  StreamSubscription<dynamic>? _portSubscription;

  /// Таймаут по умолчанию для операций
  final Duration _defaultTimeout;

  /// Создает новый транспорт для коммуникации между изолятами
  ///
  /// [id] - уникальный идентификатор транспорта
  /// [_sendPort] - порт для отправки сообщений
  /// [receivePort] - порт для получения сообщений (по умолчанию создается новый)
  /// [logEnabled] - включить логирование
  /// [timeout] - таймаут по умолчанию для операций
  IsolateTransport({
    required this.id,
    required SendPort sendPort,
    ReceivePort? receivePort,
    bool logEnabled = false,
    Duration timeout = const Duration(seconds: 30),
  })  : _sendPort = sendPort,
        _receivePort = receivePort ?? ReceivePort(),
        _logEnabled = logEnabled,
        _defaultTimeout = timeout {
    _initialize();
  }

  /// Логирование сообщений
  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    if (_logEnabled) {
      dev.log(
        message,
        name: 'IsolateTransport',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Инициализирует транспорт
  void _initialize() {
    // Подписываемся на входящие сообщения
    _portSubscription = _receivePort.listen(_handleMessage);

    // Отправляем порт для получения сообщений другой стороне
    _sendPort.send({'type': 'port_init', 'id': id, 'port': _receivePort.sendPort});

    // Устанавливаем таймаут для инициализации
    Timer(_connectionTimeout, () {
      if (!_isInitialized) {
        _log('Timeout при установлении соединения для транспорта $id');
        _connectionStateController.add(false);
      }
    });
  }

  /// Обрабатывает входящее сообщение
  void _handleMessage(dynamic message) {
    try {
      if (message is Map) {
        final type = message['type'];

        if (type == 'data') {
          final data = message['data'];
          if (data is Uint8List) {
            _incomingController.add(data);
          } else {
            _log('Получены данные неверного типа: ${data.runtimeType}');
          }
        } else if (type == 'port_init') {
          // Инициализация порта с другой стороны
          final remoteId = message['id'];
          _isInitialized = true;
          _log('Установлена связь с транспортом: $remoteId');
          _connectionStateController.add(true);

          // Отправляем подтверждение
          _sendPort.send({
            'type': 'port_ack',
            'id': id,
            'target': remoteId,
          });
        } else if (type == 'port_ack') {
          // Подтверждение инициализации
          final remoteId = message['id'];
          final targetId = message['target'];

          if (targetId == id) {
            _isInitialized = true;
            _log('Получено подтверждение от транспорта: $remoteId');
            _connectionStateController.add(true);
          }
        } else if (type == 'ping') {
          // Пинг для проверки соединения
          _sendPort.send({'type': 'pong', 'id': id});
        } else if (type == 'pong') {
          // Ответ на пинг
          _log('Получен pong от ${message['id']}');
        }
      } else if (message is Uint8List) {
        // Прямое получение бинарных данных
        _incomingController.add(message);
      } else {
        _log('Получено сообщение неизвестного типа: ${message.runtimeType}');
      }
    } catch (e, stackTrace) {
      _log('Ошибка при обработке сообщения: $e', null, stackTrace);
    }
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data, {Duration? timeout}) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;

    if (!isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    if (!_isInitialized) {
      return RpcTransportActionStatus.transportNotInitialized;
    }

    try {
      // Отправляем данные через SendPort с таймаутом
      return await Future.sync(() {
        _sendPort.send({'type': 'data', 'data': data});
        return RpcTransportActionStatus.success;
      }).timeout(
        effectiveTimeout,
        onTimeout: () => RpcTransportActionStatus.timeoutError,
      );
    } catch (e) {
      if (e is TimeoutException) {
        return RpcTransportActionStatus.timeoutError;
      }
      _log('Ошибка при отправке данных: $e', e);
      return RpcTransportActionStatus.unknownError;
    }
  }

  /// Отправляет пинг для проверки соединения
  ///
  /// Возвращает Future который завершится успешно если соединение активно
  Future<void> ping() async {
    if (!isAvailable) {
      throw StateError('Транспорт недоступен для пинга');
    }

    final completer = Completer<void>();
    final subscription = connectionState.listen((isConnected) {
      if (isConnected && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      _sendPort.send({'type': 'ping', 'id': id});

      // Ждем ответа с таймаутом
      return await completer.future.timeout(_connectionTimeout, onTimeout: () {
        throw TimeoutException('Тайм-аут при ожидании ответа на пинг');
      });
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  /// Поток состояния соединения (true - соединение активно, false - неактивно)
  Stream<bool> get connectionState => _connectionStateController.stream;

  @override
  Future<RpcTransportActionStatus> close() async {
    _isAvailable = false;
    _isInitialized = false;

    try {
      await _portSubscription?.cancel();
      _receivePort.close();

      await _incomingController.close();
      await _connectionStateController.close();

      _log('Транспорт $id закрыт');
      return RpcTransportActionStatus.success;
    } catch (e) {
      _log('Ошибка при закрытии транспорта: $e', e);
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  bool get isAvailable => _isAvailable && _isInitialized;

  /// Создает пару связанных транспортов для main isolate и worker isolate
  ///
  /// Возвращает Future с картой, содержащей два транспорта:
  /// - 'main': транспорт для использования в основном изоляте
  /// - 'worker': данные для создания транспорта в рабочем изоляте
  static Future<Map<String, dynamic>> createIsolatePair(String mainId, String workerId) async {
    final mainReceivePort = ReceivePort();
    final completer = Completer<SendPort>();

    // Слушаем первый ответ, чтобы получить SendPort воркера
    mainReceivePort.listen((message) {
      if (message is SendPort && !completer.isCompleted) {
        completer.complete(message);
      }
    });

    // Ждем SendPort от worker с таймаутом
    final workerSendPort = await completer.future.timeout(
      _connectionTimeout,
      onTimeout: () {
        mainReceivePort.close();
        throw TimeoutException('Тайм-аут при ожидании SendPort от worker isolate');
      },
    );

    // Создаем main транспорт
    final mainTransport = IsolateTransport(
      id: mainId,
      sendPort: workerSendPort,
      receivePort: mainReceivePort,
    );

    return {
      'main': mainTransport,
      'worker': {'id': workerId, 'port': mainReceivePort.sendPort}
    };
  }

  /// Создает транспорт для worker isolate из данных, полученных от main isolate
  static IsolateTransport createWorkerTransportFromJson(
    Map<String, dynamic> initData,
  ) {
    final id = initData['id'] as String;
    final sendPort = initData['port'] as SendPort;
    return createWorkerTransport(id: id, sendPort: sendPort);
  }

  /// Создает транспорт для рабочего изолята
  ///
  /// [id] - уникальный идентификатор транспорта
  /// [sendPort] - порт для отправки сообщений в основной изолят
  ///
  /// Этот метод используется в рабочем изоляте для создания транспорта,
  /// который будет взаимодействовать с основным изолятом. Автоматически
  /// отправляет порт для получения сообщений основному изоляту.
  static IsolateTransport createWorkerTransport({
    required String id,
    required SendPort sendPort,
  }) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    return IsolateTransport(
      id: id,
      sendPort: sendPort,
      receivePort: receivePort,
    );
  }
}
