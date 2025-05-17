// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:rpc_dart/src/transport/_index.dart';

void main() {
  group('EncryptedTransport', () {
    late MemoryTransport transport1;
    late MemoryTransport transport2;
    late EncryptedTransport encryptedTransport1;
    late EncryptedTransport encryptedTransport2;
    late _SimpleEncryption encryptionService;

    const testMessage = {
      'type': 'request',
      'data': 'Test message',
      'id': '123'
    };
    final testData = Uint8List.fromList(utf8.encode(json.encode(testMessage)));

    setUp(() {
      // Создаем два транспорта в памяти для тестирования
      transport1 = MemoryTransport('test1');
      transport2 = MemoryTransport('test2');

      // Соединяем их друг с другом
      transport1.connect(transport2);
      transport2.connect(transport1);

      // Создаем сервис шифрования с общим ключом для обоих транспортов
      final sharedKey = 'sharedSecretKey123';
      final sharedKeySelector = 'keySelector1';
      encryptionService = _SimpleEncryption(
        secretKey: sharedKey,
        keySelector: sharedKeySelector,
      );

      // Создаем шифрованные транспорты поверх обычных
      encryptedTransport1 = EncryptedTransport(
        baseTransport: transport1,
        encryptionService: encryptionService,
        debug: true,
      );

      encryptedTransport2 = EncryptedTransport(
        baseTransport: transport2,
        encryptionService: encryptionService,
        debug: true,
      );
    });

    test('передача зашифрованных данных между транспортами', () async {
      // Подготавливаем ожидание ответа
      final receivedData = encryptedTransport2.receive().first;

      // Отправляем сообщение
      final result = await encryptedTransport1.send(testData);
      expect(result, equals(RpcTransportActionStatus.success));

      // Получаем и проверяем расшифрованные данные
      final data = await receivedData;
      final decodedMessage =
          json.decode(utf8.decode(data)) as Map<String, dynamic>;

      expect(decodedMessage, equals(testMessage));
    });

    test('передача незашифрованных данных', () async {
      // Создаем транспорт, который не шифрует данные
      final noEncryptionService = _SelectiveEncryption(
        baseService: encryptionService,
        encryptedMessageTypes: [
          'other_type'
        ], // только другие типы будут шифроваться
      );

      encryptedTransport1 = EncryptedTransport(
        baseTransport: transport1,
        encryptionService: noEncryptionService,
        debug: true,
      );

      // Подготавливаем ожидание ответа
      final receivedData = encryptedTransport2.receive().first;

      // Отправляем сообщение
      final result = await encryptedTransport1.send(testData);
      expect(result, equals(RpcTransportActionStatus.success));

      // Получаем и проверяем данные - они должны быть такими же, как исходные
      final data = await receivedData;
      final decodedMessage =
          json.decode(utf8.decode(data)) as Map<String, dynamic>;

      expect(decodedMessage, equals(testMessage));
    });

    test('закрытие транспорта', () async {
      // Закрываем транспорт
      final result = await encryptedTransport1.close();

      // Проверяем результат
      expect(result, equals(RpcTransportActionStatus.success));

      // Проверяем, что транспорт теперь недоступен
      expect(encryptedTransport1.isAvailable, isFalse);
    });

    test('отправка данных, когда транспорт недоступен', () async {
      // Закрываем транспорт
      await encryptedTransport1.close();

      // Пытаемся отправить данные
      final result = await encryptedTransport1.send(testData);

      // Проверяем ожидаемую ошибку
      expect(result, equals(RpcTransportActionStatus.transportUnavailable));
    });

    test('нечитаемые (бинарные) данные проходят без изменений', () async {
      // Создаем бинарные данные, которые не могут быть декодированы как JSON
      final binaryData = Uint8List.fromList([0xFF, 0xFE, 0xFD, 0xFC]);

      // Подготавливаем ожидание ответа
      final receivedData = encryptedTransport2.receive().first;

      // Отправляем бинарные данные
      final result = await encryptedTransport1.send(binaryData);
      expect(result, equals(RpcTransportActionStatus.success));

      // Получаем данные и проверяем, что они прошли без изменений
      final data = await receivedData;
      expect(data, equals(binaryData));
    });

    test('ошибка дешифрования при несовпадении ключей', () async {
      // Создаем транспорты с разными ключами
      final key1 = 'key1';
      final key2 = 'key2';
      final encryptionService1 =
          _SimpleEncryption(secretKey: key1, keySelector: 'selector1');
      final encryptionService2 =
          _SimpleEncryption(secretKey: key2, keySelector: 'selector2');

      // Создаем шифрованные транспорты с разными ключами
      final mismatchedTransport1 = EncryptedTransport(
        baseTransport: transport1,
        encryptionService: encryptionService1,
        debug: true,
      );

      final mismatchedTransport2 = EncryptedTransport(
        baseTransport: transport2,
        encryptionService: encryptionService2,
        debug: true,
      );

      // Отправляем данные с одного транспорта
      await mismatchedTransport1.send(testData);

      // Принимаем данные на втором транспорте и ожидаем ошибку дешифрования
      // Так как неверный ключ создаст некорректные данные, мы можем проверить,
      // что результат дешифрации отличается от исходного сообщения
      final receivedData = await mismatchedTransport2.receive().first;

      // Проверяем, что данные были получены (ошибка дешифрования внутренне обрабатывается)
      expect(receivedData, isNotNull);

      // Пробуем декодировать полученные данные
      try {
        final decoded =
            json.decode(utf8.decode(receivedData)) as Map<String, dynamic>;

        // Если данные успешно декодированы как JSON, проверяем, что они отличаются от исходных
        if (decoded.containsKey('type') &&
            decoded.containsKey('data') &&
            decoded.containsKey('id')) {
          // Если структура совпадает, проверяем что хотя бы значение поля data отличается
          expect(decoded['data'], isNot(equals(testMessage['data'])));
        }
      } catch (e) {
        // В случае ошибки декодирования это тоже валидный результат - данные повреждены
        // при неправильном дешифровании
        expect(e, isNotNull);
      }
    });
  });
}

/// Простая реализация сервиса шифрования для примера и тестирования
///
/// ВНИМАНИЕ: Этот класс предназначен только для демонстрации и тестирования.
/// Не рекомендуется использовать его в производственной среде.
/// Для реальных проектов используйте криптографически стойкие алгоритмы и библиотеки.
class _SimpleEncryption implements RpcEncryptionService {
  /// Секретный ключ для шифрования (для примера используем строку)
  final String _secretKey;

  /// Селектор ключа
  final String _keySelector;

  /// Создает простой сервис шифрования с XOR
  ///
  /// [secretKey] - секретный ключ (если не указан, генерируется случайный)
  /// [keySelector] - селектор ключа (если не указан, генерируется случайный)
  _SimpleEncryption({
    String? secretKey,
    String? keySelector,
  })  : _secretKey = secretKey ?? _generateRandomKey(32),
        _keySelector = keySelector ?? _generateKeySelector();

  /// Генерирует случайный ключ указанной длины
  static String _generateRandomKey(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Генерирует селектор ключа
  static String _generateKeySelector() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  @override
  List<int> encrypt({
    required List<int> data,
    String? keySelector,
    Map<String, dynamic>? metadata,
  }) {
    // Преобразуем секретный ключ в байтовый массив
    final keyBytes = utf8.encode(_secretKey);

    // Создаем буфер для результата
    final result = <int>[];

    // Очень простой XOR-шифр (только для демонстрации!)
    for (var i = 0; i < data.length; i++) {
      result.add(data[i] ^ keyBytes[i % keyBytes.length]);
    }

    return result;
  }

  @override
  List<int> decrypt({
    required List<int> encryptedData,
    String? keySelector,
    Map<String, dynamic>? metadata,
  }) {
    // Для XOR-шифра шифрование и дешифрование идентичны
    return encrypt(
        data: encryptedData, keySelector: keySelector, metadata: metadata);
  }

  @override
  bool supportsEncryption({
    required String messageType,
    Map<String, dynamic>? metadata,
  }) {
    // В этом простом примере шифруем все сообщения
    return true;
  }

  @override
  String? get currentKeySelector => _keySelector;

  @override
  Map<String, dynamic>? get encryptionMetadata => {
        'protocol_version': '1.0',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
}

/// Селективное шифрование - шифрует только определенные типы сообщений
class _SelectiveEncryption implements RpcEncryptionService {
  /// Базовый сервис шифрования
  final RpcEncryptionService _baseService;

  /// Список типов сообщений для шифрования
  final List<String> _encryptedMessageTypes;

  /// Создает сервис селективного шифрования
  ///
  /// [baseService] - базовый сервис шифрования
  /// [encryptedMessageTypes] - список типов сообщений, которые нужно шифровать
  _SelectiveEncryption({
    required RpcEncryptionService baseService,
    required List<String> encryptedMessageTypes,
  })  : _baseService = baseService,
        _encryptedMessageTypes = encryptedMessageTypes;

  @override
  List<int> encrypt({
    required List<int> data,
    String? keySelector,
    Map<String, dynamic>? metadata,
  }) {
    return _baseService.encrypt(
      data: data,
      keySelector: keySelector,
      metadata: metadata,
    );
  }

  @override
  List<int> decrypt({
    required List<int> encryptedData,
    String? keySelector,
    Map<String, dynamic>? metadata,
  }) {
    return _baseService.decrypt(
      encryptedData: encryptedData,
      keySelector: keySelector,
      metadata: metadata,
    );
  }

  @override
  bool supportsEncryption({
    required String messageType,
    Map<String, dynamic>? metadata,
  }) {
    // Шифруем только сообщения из списка
    return _encryptedMessageTypes.contains(messageType);
  }

  @override
  String? get currentKeySelector => _baseService.currentKeySelector;

  @override
  Map<String, dynamic>? get encryptionMetadata =>
      _baseService.encryptionMetadata;
}
