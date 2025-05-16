// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:rpc_dart/src/transport/_index.dart';

/// Обертка транспорта, которая добавляет шифрование к базовому транспорту
///
/// Этот класс шифрует исходящие сообщения и дешифрует входящие сообщения,
/// делегируя фактическую передачу данных базовому транспорту.
class EncryptedTransport implements RpcTransport {
  /// Базовый транспорт для передачи данных
  final RpcTransport _baseTransport;

  /// Сервис шифрования
  final RpcEncryptionService _encryptionService;

  /// Контроллер для потока дешифрованных сообщений
  final StreamController<Uint8List> _decryptedController =
      StreamController<Uint8List>.broadcast();

  /// Подписка на поток сообщений базового транспорта
  StreamSubscription<Uint8List>? _baseSubscription;

  /// Флаг отладки
  final bool _debug;

  @override
  String get id => _baseTransport.id;

  @override
  bool get isAvailable => _baseTransport.isAvailable;

  /// Создает новый экземпляр зашифрованного транспорта
  ///
  /// [baseTransport] - базовый транспорт для передачи данных
  /// [encryptionService] - сервис для шифрования/дешифрования данных
  /// [debug] - флаг отладки
  EncryptedTransport({
    required RpcTransport baseTransport,
    required RpcEncryptionService encryptionService,
    bool debug = false,
  })  : _baseTransport = baseTransport,
        _encryptionService = encryptionService,
        _debug = debug {
    _initialize();
  }

  /// Инициализирует транспорт
  void _initialize() {
    // Подписываемся на поток сообщений базового транспорта
    _baseSubscription = _baseTransport.receive().listen(
      _handleIncomingData,
      onError: (error) {
        _log('Ошибка в базовом транспорте: $error');
        _decryptedController.addError(error);
      },
      onDone: () {
        _log('Базовый транспорт закрыт');
        if (!_decryptedController.isClosed) {
          _decryptedController.close();
        }
      },
    );
  }

  /// Логирует сообщения, если включен режим отладки
  void _log(String message) {
    if (_debug) {
      print('[EncryptedTransport:$id] $message');
    }
  }

  /// Обрабатывает входящие данные от базового транспорта
  ///
  /// Дешифрует данные, если они зашифрованы, и передает их в поток сообщений
  void _handleIncomingData(Uint8List data) {
    _log('Получены данные размером ${data.length} байт');

    try {
      // Пытаемся определить, являются ли данные зашифрованными
      try {
        // Предполагаем, что в начале данных есть метаданные о шифровании
        final messageStr = utf8.decode(data);
        final message = json.decode(messageStr) as Map<String, dynamic>;

        // Проверяем, есть ли информация о шифровании
        if (message.containsKey('encryption_info')) {
          final encryptionInfo = RpcEncryptionInfo.fromJson(
              message['encryption_info'] as Map<String, dynamic>);

          if (encryptionInfo.isEncrypted) {
            _log(
                'Обнаружены зашифрованные данные, keySelector: ${encryptionInfo.keySelector}');

            // Извлекаем зашифрованные данные
            final encryptedData = base64Decode(message['data'] as String);

            // Дешифруем данные
            final decryptedData = _encryptionService.decrypt(
              encryptedData: encryptedData,
              keySelector: encryptionInfo.keySelector,
              metadata: encryptionInfo.metadata,
            );

            // Передаем дешифрованные данные в поток
            _decryptedController.add(Uint8List.fromList(decryptedData));
            return;
          }
        }

        // Если не обнаружены метаданные шифрования, просто передаем данные как есть
        _decryptedController.add(data);
      } catch (e) {
        // Если не удалось разобрать JSON, считаем, что данные не зашифрованы
        _log('Данные не зашифрованы или не удалось определить формат: $e');
        _decryptedController.add(data);
      }
    } catch (e, _) {
      _log('Ошибка при обработке входящих данных: $e');
      _decryptedController.addError(e);
    }
  }

  @override
  Stream<Uint8List> receive() {
    return _decryptedController.stream;
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data,
      {Duration? timeout}) async {
    if (!isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    try {
      _log('Отправка данных размером ${data.length} байт');

      try {
        // Пытаемся определить тип сообщения, чтобы решить, шифровать ли его
        final messageStr = utf8.decode(data);
        final message = json.decode(messageStr) as Map<String, dynamic>;

        // Получаем тип сообщения из метаданных или используем пустую строку
        final messageType =
            message.containsKey('type') ? message['type'] as String : '';

        // Проверяем, нужно ли шифровать это сообщение
        if (_encryptionService.supportsEncryption(
            messageType: messageType,
            metadata: message['metadata'] as Map<String, dynamic>?)) {
          _log('Шифрование сообщения типа $messageType');

          // Шифруем данные
          final encryptedData = _encryptionService.encrypt(
            data: data,
            keySelector: _encryptionService.currentKeySelector,
            metadata: message['metadata'] as Map<String, dynamic>?,
          );

          // Создаем обертку для зашифрованных данных
          final encryptionInfo = RpcEncryptionInfo(
            isEncrypted: true,
            keySelector: _encryptionService.currentKeySelector,
            metadata: _encryptionService.encryptionMetadata,
          );

          // Создаем новое сообщение, содержащее зашифрованные данные
          final encryptedMessage = {
            'encryption_info': encryptionInfo.toJson(),
            'data': base64Encode(encryptedData),
          };

          // Сериализуем и отправляем сообщение
          final serializedMessage = utf8.encode(json.encode(encryptedMessage));

          return await _baseTransport.send(
            Uint8List.fromList(serializedMessage),
            timeout: timeout,
          );
        }
      } catch (e) {
        _log(
            'Ошибка при определении типа сообщения, отправляем без шифрования: $e');
      }

      // Если сообщение не нужно шифровать или произошла ошибка,
      // отправляем данные как есть
      return await _baseTransport.send(data, timeout: timeout);
    } catch (e) {
      _log('Ошибка при отправке данных: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  Future<RpcTransportActionStatus> close() async {
    _log('Закрытие зашифрованного транспорта');

    // Отменяем подписку на базовый транспорт
    await _baseSubscription?.cancel();
    _baseSubscription = null;

    // Закрываем контроллер дешифрованных сообщений
    if (!_decryptedController.isClosed) {
      await _decryptedController.close();
    }

    // Закрываем базовый транспорт
    return await _baseTransport.close();
  }
}

/// Интерфейс сервиса шифрования для использования в [EncryptedTransport]
///
/// Разработчик должен реализовать этот интерфейс и предоставить реализацию
/// для шифрования и дешифрования данных.
abstract class RpcEncryptionService {
  /// Шифрует данные перед отправкой
  ///
  /// [data] - исходные данные для шифрования
  /// [keySelector] - опциональный селектор ключа (для выбора из нескольких ключей)
  /// [metadata] - дополнительные метаданные, которые могут быть использованы при шифровании
  ///
  /// Возвращает зашифрованные данные
  List<int> encrypt({
    required List<int> data,
    String? keySelector,
    Map<String, dynamic>? metadata,
  });

  /// Дешифрует полученные данные
  ///
  /// [encryptedData] - зашифрованные данные
  /// [keySelector] - опциональный селектор ключа (для выбора из нескольких ключей)
  /// [metadata] - дополнительные метаданные, которые могут быть использованы при дешифровании
  ///
  /// Возвращает расшифрованные данные
  List<int> decrypt({
    required List<int> encryptedData,
    String? keySelector,
    Map<String, dynamic>? metadata,
  });

  /// Проверяет, поддерживается ли шифрование для указанного типа данных/сообщения
  ///
  /// [messageType] - тип сообщения или данных
  /// [metadata] - дополнительные метаданные о сообщении
  ///
  /// Возвращает true, если шифрование поддерживается для данного типа сообщения
  bool supportsEncryption({
    required String messageType,
    Map<String, dynamic>? metadata,
  });

  /// Возвращает текущий селектор ключа
  String? get currentKeySelector;

  /// Метаданные шифрования, которые могут быть добавлены к сообщению
  /// ВАЖНО: Не включайте в метаданные информацию, которая может раскрыть
  /// детали реализации шифрования (алгоритм, размер ключа и т.д.)
  Map<String, dynamic>? get encryptionMetadata;
}

/// Модель для хранения информации о шифровании
class RpcEncryptionInfo {
  /// Флаг, указывающий, зашифрованы ли данные
  final bool isEncrypted;

  /// Селектор ключа для системы шифрования
  /// Используется безопасным образом для выбора подходящего ключа
  final String? keySelector;

  /// Дополнительные метаданные шифрования
  final Map<String, dynamic>? metadata;

  const RpcEncryptionInfo({
    required this.isEncrypted,
    this.keySelector,
    this.metadata,
  });

  /// Создание из JSON
  factory RpcEncryptionInfo.fromJson(Map<String, dynamic> json) {
    return RpcEncryptionInfo(
      isEncrypted: json['is_encrypted'] as bool,
      keySelector: json['key_selector'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {
      'is_encrypted': isEncrypted,
      if (keySelector != null) 'key_selector': keySelector,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
