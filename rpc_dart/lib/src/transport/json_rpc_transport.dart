// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';

final RpcLogger _logger = RpcLogger('JsonRpcTransport');

/// Коды ошибок JSON-RPC 2.0
class JsonRpcErrorCode {
  /// Ошибка при разборе JSON
  static const int parseError = -32700;

  /// Неверный запрос
  static const int invalidRequest = -32600;

  /// Метод не найден
  static const int methodNotFound = -32601;

  /// Недопустимые параметры
  static const int invalidParams = -32602;

  /// Внутренняя ошибка
  static const int internalError = -32603;

  /// Серверные ошибки (зарезервировано)
  static const int serverErrorStart = -32000;
  static const int serverErrorEnd = -32099;
}

/// Реализация транспорта для JSON-RPC 2.0 (только для унарных методов)
class JsonRpcTransport implements IRpcTransport {
  @override
  final String id;

  /// Контроллер для публикации входящих сообщений (внутренний формат)
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  /// Базовый транспорт для передачи данных
  final IRpcTransport _baseTransport;

  /// Подписка на входящие сообщения базового транспорта
  StreamSubscription<Uint8List>? _baseSubscription;

  /// Флаг доступности транспорта
  bool _isAvailable = true;

  /// Флаг отладки
  final bool _debug;

  /// Создает новый экземпляр JSON-RPC транспорта
  ///
  /// [id] - идентификатор транспорта
  /// [baseTransport] - базовый транспорт для передачи данных
  /// [debug] - флаг вывода отладочной информации
  JsonRpcTransport(
    this.id,
    this._baseTransport, {
    bool debug = false,
  }) : _debug = debug {
    _initialize();
  }

  /// Логирует сообщения, если включен режим отладки
  void _log(String message) {
    if (_debug) {
      _logger.debug(message);
    }
  }

  /// Инициализирует транспорт
  void _initialize() {
    // Подписываемся на сообщения от базового транспорта
    _baseSubscription = _baseTransport.receive().listen(
      _handleIncomingData,
      onError: (error) {
        _log('Ошибка от базового транспорта: $error');
        // Перенаправляем ошибки в наш поток
        if (!_incomingController.isClosed) {
          _incomingController.addError(error);
        }
      },
      onDone: () {
        _log('Базовый транспорт закрыт');
        // Закрываем наш поток, если базовый закрылся
        if (!_incomingController.isClosed) {
          _incomingController.close();
        }
        _isAvailable = false;
      },
    );
    _log('Подписка на базовый транспорт создана');
  }

  /// Обрабатывает входящие данные в формате JSON-RPC
  void _handleIncomingData(Uint8List data) {
    if (!_isAvailable || _incomingController.isClosed) return;

    try {
      // Десериализуем JSON-RPC сообщение
      final String jsonString = utf8.decode(data);
      _log('Получено сообщение: $jsonString');

      final dynamic jsonData = json.decode(jsonString);

      // Проверяем, что это объект
      if (jsonData is! Map<String, dynamic>) {
        _log('Получен не объект: $jsonData');
        _sendErrorResponse(null, JsonRpcErrorCode.invalidRequest,
            'Invalid JSON-RPC request: not an object');
        return;
      }

      // Проверяем версию JSON-RPC
      final jsonrpc = jsonData['jsonrpc'];
      if (jsonrpc != '2.0') {
        _log('Неверная версия JSON-RPC: $jsonrpc');
        _sendErrorResponse(jsonData['id'], JsonRpcErrorCode.invalidRequest,
            'Invalid JSON-RPC version. Expected "2.0", got "$jsonrpc"');
        return;
      }

      // Получаем ID сообщения (может быть null для уведомлений)
      final id = jsonData['id'];

      // Проверяем тип сообщения - запрос или ответ
      if (jsonData.containsKey('method')) {
        // Это запрос или уведомление
        _handleRequestMessage(jsonData, id);
      } else if (jsonData.containsKey('result') ||
          jsonData.containsKey('error')) {
        // Это ответ
        _handleResponseMessage(jsonData, id);
      } else {
        _log('Неизвестный тип сообщения: $jsonData');
        _sendErrorResponse(id, JsonRpcErrorCode.invalidRequest,
            'Invalid JSON-RPC message format');
      }
    } catch (e, stackTrace) {
      _log('Ошибка обработки входящего сообщения: $e');
      // В случае ошибки отправляем JSON-RPC ошибку
      _sendErrorResponse(null, JsonRpcErrorCode.parseError,
          'Failed to parse JSON-RPC message: ${e.toString()}');

      // И логируем ошибку
      Zone.current.handleUncaughtError(
        Exception('Error processing JSON-RPC message: $e'),
        stackTrace,
      );
    }
  }

  /// Обрабатывает входящий запрос или уведомление
  void _handleRequestMessage(Map<String, dynamic> jsonData, dynamic id) {
    // Получаем метод
    final method = jsonData['method'];
    if (method is! String) {
      _log('Неверное поле method: $method');
      _sendErrorResponse(id, JsonRpcErrorCode.invalidRequest,
          'Invalid or missing "method" field');
      return;
    }

    // Получаем параметры (опционально)
    final params = jsonData['params'];

    // Разбираем имя сервиса/метода из строки метода
    final methodParts = method.split('.');
    String? serviceName;
    String methodName;

    if (methodParts.length > 1) {
      serviceName = methodParts[0];
      methodName = methodParts[1];
    } else {
      methodName = method;
    }

    // Создаем объект сообщения во внутреннем формате
    final message = RpcMessage(
      type: RpcMessageType.request,
      id: id?.toString() ??
          'notification-${DateTime.now().millisecondsSinceEpoch}',
      service: serviceName,
      method: methodName,
      payload: params,
    );

    _log('Создано внутреннее сообщение запроса: ${message.toString()}');

    // Сериализуем и отправляем во внутренний поток
    final serializedMessage = utf8.encode(json.encode(message.toJson()));
    _incomingController.add(Uint8List.fromList(serializedMessage));
    _log('Запрос передан во внутренний поток');
  }

  /// Обрабатывает входящий ответ
  void _handleResponseMessage(Map<String, dynamic> jsonData, dynamic id) {
    _log('Обработка ответа с id: $id');

    // Определяем, это успешный ответ или ошибка
    final bool isError = jsonData.containsKey('error');
    final payload = isError ? jsonData['error'] : jsonData['result'];

    // Создаем объект сообщения во внутреннем формате
    final message = RpcMessage(
      type: isError ? RpcMessageType.error : RpcMessageType.response,
      id: id?.toString() ?? 'unknown',
      payload: payload,
    );

    _log('Создано внутреннее сообщение ответа: ${message.toString()}');

    // Сериализуем и отправляем во внутренний поток
    final serializedMessage = utf8.encode(json.encode(message.toJson()));
    _incomingController.add(Uint8List.fromList(serializedMessage));
    _log('Ответ передан во внутренний поток');
  }

  /// Отправляет ответ с ошибкой в формате JSON-RPC
  void _sendErrorResponse(dynamic id, int code, String message) {
    final errorResponse = {
      'jsonrpc': '2.0',
      'error': {
        'code': code,
        'message': message,
      },
      'id': id,
    };

    _log('Отправка ответа с ошибкой: $errorResponse');
    final serializedResponse = utf8.encode(json.encode(errorResponse));
    _baseTransport.send(Uint8List.fromList(serializedResponse));
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data,
      {Duration? timeout}) async {
    if (!isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    try {
      // Десериализуем внутреннее сообщение
      final String jsonString = utf8.decode(data);
      _log('Отправка сообщения: $jsonString');

      final dynamic messageData = json.decode(jsonString);

      // Проверяем, что это объект
      if (messageData is! Map<String, dynamic>) {
        _log('Данные для отправки не являются объектом: $messageData');
        return RpcTransportActionStatus.unknownError;
      }

      // Создаем RpcMessage из JSON
      final rpcMessage = RpcMessage.fromJson(messageData);
      _log('Создано сообщение для отправки: ${rpcMessage.toString()}');

      // Преобразуем в формат JSON-RPC
      Map<String, dynamic> jsonRpcMessage;

      // Если это ответ, создаем структуру ответа
      if (rpcMessage.type == RpcMessageType.response) {
        jsonRpcMessage = {
          'jsonrpc': '2.0',
          'result': rpcMessage.payload,
          'id': rpcMessage.id,
        };
        _log('Преобразовано в ответ JSON-RPC: $jsonRpcMessage');
      }
      // Если это ошибка, создаем структуру ошибки
      else if (rpcMessage.type == RpcMessageType.error) {
        // Преобразуем наши ошибки в коды JSON-RPC
        final errorInfo = _mapErrorToJsonRpc(rpcMessage.payload);

        jsonRpcMessage = {
          'jsonrpc': '2.0',
          'error': {
            'code': errorInfo['code'],
            'message': errorInfo['message'],
            'data': errorInfo['data'],
          },
          'id': rpcMessage.id,
        };
        _log('Преобразовано в ошибку JSON-RPC: $jsonRpcMessage');
      }
      // Если это запрос, создаем структуру запроса
      else if (rpcMessage.type == RpcMessageType.request) {
        // Формируем имя метода (service.method или просто method)
        final methodName = rpcMessage.service != null
            ? '${rpcMessage.service}.${rpcMessage.method}'
            : rpcMessage.method;

        jsonRpcMessage = {
          'jsonrpc': '2.0',
          'method': methodName,
          'params': rpcMessage.payload,
          'id': rpcMessage.id,
        };
        _log('Преобразовано в запрос JSON-RPC: $jsonRpcMessage');
      }
      // Для остальных типов не поддерживаем JSON-RPC
      else {
        _log('Неподдерживаемый тип сообщения: ${rpcMessage.type}');
        return RpcTransportActionStatus.unknownError;
      }

      // Сериализуем и отправляем через базовый транспорт
      final serializedMessage = utf8.encode(json.encode(jsonRpcMessage));
      _log('Отправка через базовый транспорт');
      final result = await _baseTransport.send(
        Uint8List.fromList(serializedMessage),
        timeout: timeout,
      );

      _log('Результат отправки: $result');
      return result;
    } catch (e, stackTrace) {
      _log('Ошибка при отправке: $e');
      Zone.current.handleUncaughtError(
        Exception('Ошибка при отправке JSON-RPC: $e'),
        stackTrace,
      );
      return RpcTransportActionStatus.unknownError;
    }
  }

  /// Преобразует наши ошибки в формат JSON-RPC
  Map<String, dynamic> _mapErrorToJsonRpc(dynamic error) {
    // По умолчанию - внутренняя ошибка
    int code = JsonRpcErrorCode.internalError;
    String message = 'Internal error';
    dynamic data;

    // Если это наша ошибка RpcException
    if (error is Map<String, dynamic> &&
        error.containsKey('code') &&
        error.containsKey('message')) {
      // Преобразуем наши коды ошибок в JSON-RPC коды
      switch (error['code']) {
        case 'notFound':
          code = JsonRpcErrorCode.methodNotFound;
          break;
        case 'invalidArgument':
          code = JsonRpcErrorCode.invalidParams;
          break;
        case 'internal':
          code = JsonRpcErrorCode.internalError;
          break;
        default:
          code = JsonRpcErrorCode.serverErrorStart;
      }

      message = error['message'];
      data = error['details'];
    } else if (error is String) {
      message = error;
    } else if (error != null) {
      message = error.toString();
    }

    return {
      'code': code,
      'message': message,
      'data': data,
    };
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  @override
  Future<RpcTransportActionStatus> close() async {
    _isAvailable = false;

    // Отменяем подписку на базовый транспорт
    await _baseSubscription?.cancel();
    _baseSubscription = null;

    // Закрываем контроллер
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }

    // Закрываем базовый транспорт
    return await _baseTransport.close();
  }

  @override
  bool get isAvailable => _isAvailable && _baseTransport.isAvailable;
}
