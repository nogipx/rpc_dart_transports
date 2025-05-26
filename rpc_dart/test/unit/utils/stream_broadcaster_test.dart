// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('StreamBroadcaster', () {
    test('создает дочерние потоки, получающие данные из исходного', () async {
      // Arrange
      final sourceController = StreamController<int>();
      final broadcaster = StreamBroadcaster<int>(sourceController.stream);

      final childEvents1 = <int>[];
      final childEvents2 = <int>[];

      // Act
      final childStream1 = broadcaster.createStream();
      final childStream2 = broadcaster.createStream();

      final subscription1 = childStream1.listen(childEvents1.add);
      final subscription2 = childStream2.listen(childEvents2.add);

      // Отправляем данные в исходный поток
      sourceController.add(1);
      sourceController.add(2);
      sourceController.add(3);

      // Закрываем исходный контроллер для завершения потока
      await sourceController.close();

      // Ждем небольшую паузу для завершения обработки
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Assert
      expect(childEvents1, equals([1, 2, 3]));
      expect(childEvents2, equals([1, 2, 3]));

      // Cleanup
      await subscription1.cancel();
      await subscription2.cancel();
      await broadcaster.close();
    });

    test('можно использовать как функцию через call()', () async {
      // Arrange
      final sourceController = StreamController<String>();
      final broadcaster = StreamBroadcaster<String>(sourceController.stream);

      // Act
      final childStream = broadcaster();
      final receivedEvents = <String>[];

      final subscription = childStream.listen(receivedEvents.add);

      sourceController.add('test');

      // Закрываем исходный контроллер для завершения потока
      await sourceController.close();

      // Ждем небольшую паузу для завершения обработки
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Assert
      expect(receivedEvents, equals(['test']));

      // Cleanup
      await subscription.cancel();
      await broadcaster.close();
    });

    test('передает ошибки из исходного потока в дочерние', () async {
      // Arrange
      final sourceController = StreamController<int>();
      final broadcaster = StreamBroadcaster<int>(sourceController.stream);

      final receivedErrors = <Object>[];

      // Act
      final childStream = broadcaster.createStream();
      final subscription = childStream.listen(
        (_) {},
        onError: receivedErrors.add,
      );

      // Отправляем ошибку в исходный поток
      sourceController.addError(Exception('test error'));

      // Закрываем исходный контроллер для завершения потока
      await sourceController.close();

      // Ждем небольшую паузу для завершения обработки
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Assert
      expect(receivedErrors.length, equals(1));
      expect(receivedErrors.first, isA<Exception>());
      expect(receivedErrors.first.toString(), contains('test error'));

      // Cleanup
      await subscription.cancel();
      await broadcaster.close();
    });

    test('close() завершает все дочерние потоки', () async {
      // Arrange
      final sourceController = StreamController<int>();
      final broadcaster = StreamBroadcaster<int>(sourceController.stream);

      var done1 = false;
      var done2 = false;

      // Act
      final childStream1 = broadcaster.createStream();
      final childStream2 = broadcaster.createStream();

      childStream1.listen(
        (_) {},
        onDone: () => done1 = true,
      );

      childStream2.listen(
        (_) {},
        onDone: () => done2 = true,
      );

      // Закрываем broadcaster
      await broadcaster.close();

      // Ждем небольшую паузу для обработки закрытия
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(broadcaster.isClosed, isTrue);
      expect(done1, isTrue);
      expect(done2, isTrue);

      // Cleanup
      await sourceController.close();
    });

    test('close() предотвращает создание новых дочерних потоков', () async {
      // Arrange
      final sourceController = StreamController<int>();
      final broadcaster = StreamBroadcaster<int>(sourceController.stream);

      // Act
      await broadcaster.close();

      final childStream = broadcaster.createStream();

      // Создаем подписку, чтобы убедиться что поток пустой
      var isDone = false;
      final subscription = childStream.listen(
        (_) {},
        onDone: () => isDone = true,
      );

      // Ждем небольшую паузу для обработки закрытия
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(isDone, isTrue);

      // Cleanup
      await subscription.cancel();
      await sourceController.close();
    });

    test('закрытие исходного потока автоматически закрывает broadcaster',
        () async {
      // Arrange
      final sourceController = StreamController<int>();
      final broadcaster = StreamBroadcaster<int>(sourceController.stream);

      var isDone = false;

      // Act
      final childStream = broadcaster.createStream();

      childStream.listen(
        (_) {},
        onDone: () => isDone = true,
      );

      // Закрываем исходный поток
      await sourceController.close();

      // Ждем значительную паузу для обработки закрытия
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(isDone, isTrue,
          reason:
              'Дочерний поток должен завершиться при закрытии исходного потока');
      expect(broadcaster.isClosed, isTrue,
          reason: 'Broadcaster должен закрыться при закрытии исходного потока');
    });
  });
}
