import 'dart:typed_data';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryTransport', () {
    late MemoryTransport transport1;
    late MemoryTransport transport2;

    setUp(() {
      transport1 = MemoryTransport('transport1');
      transport2 = MemoryTransport('transport2');

      // Соединяем транспорты
      transport1.connect(transport2);
      transport2.connect(transport1);
    });

    test('should have correct initial state', () {
      // Assert
      expect(transport1.id, equals('transport1'));
      expect(transport2.id, equals('transport2'));
      expect(transport1.isAvailable, isTrue);
      expect(transport2.isAvailable, isTrue);
    });

    test('should send and receive data', () async {
      // Arrange
      final receivedData = <Uint8List>[];
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Подписываемся на получение данных
      final subscription = transport2.receive().listen((data) {
        receivedData.add(data);
      });

      // Act
      await transport1.send(testData);

      // Ждем выполнения асинхронных операций
      await Future.delayed(Duration(milliseconds: 10));

      // Assert
      expect(receivedData.length, equals(1));
      expect(receivedData[0], equals(testData));

      // Очистка
      await subscription.cancel();
    });

    test('should support bidirectional communication', () async {
      // Arrange
      final receivedByTransport1 = <Uint8List>[];
      final receivedByTransport2 = <Uint8List>[];

      final dataToTransport1 = Uint8List.fromList([10, 20, 30]);
      final dataToTransport2 = Uint8List.fromList([40, 50, 60]);

      // Подписываемся на получение данных
      final subscription1 = transport1.receive().listen((data) {
        receivedByTransport1.add(data);
      });

      final subscription2 = transport2.receive().listen((data) {
        receivedByTransport2.add(data);
      });

      // Act
      await transport1.send(dataToTransport2);
      await transport2.send(dataToTransport1);

      // Ждем выполнения асинхронных операций
      await Future.delayed(Duration(milliseconds: 10));

      // Assert
      expect(receivedByTransport1.length, equals(1));
      expect(receivedByTransport1[0], equals(dataToTransport1));

      expect(receivedByTransport2.length, equals(1));
      expect(receivedByTransport2[0], equals(dataToTransport2));

      // Очистка
      await subscription1.cancel();
      await subscription2.cancel();
    });

    test('should throw error when sending without destination', () async {
      // Arrange
      final transportWithoutDestination = MemoryTransport('noDestination');
      final testData = Uint8List.fromList([1, 2, 3]);

      // Act & Assert
      expect(
          () => transportWithoutDestination.send(testData), throwsStateError);
    });

    test('should throw error when sending after close', () async {
      // Arrange
      final testData = Uint8List.fromList([1, 2, 3]);

      // Act
      await transport1.close();

      // Assert
      expect(transport1.isAvailable, isFalse);
      expect(() => transport1.send(testData), throwsStateError);
    });

    test('should not receive data after close', () async {
      // Arrange
      bool dataReceived = false;
      final testData = Uint8List.fromList([1, 2, 3]);

      final subscription = transport2.receive().listen((_) {
        dataReceived = true;
      });

      // Act
      await transport2.close();

      // Ignore the error, we just want to make sure transport2 doesn't receive anything
      try {
        await transport1.send(testData);
      } catch (_) {}

      // Ждем выполнения асинхронных операций
      await Future.delayed(Duration(milliseconds: 10));

      // Assert
      expect(dataReceived, isFalse);

      // Очистка
      await subscription.cancel();
    });
  });
}
