// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

/// {@template stream_broadcaster}
/// Утилита для создания множества дочерних потоков из одного родительского.
///
/// Позволяет при подключении новых клиентов предоставлять им
/// отдельный поток данных, при этом все дочерние потоки
/// получают одинаковые данные из родительского потока.
///
/// Пример использования:
/// ```dart
/// // Создаем broadcaster для входящего потока сообщений
/// final broadcaster = StreamBroadcaster<String>(originalStream);
///
/// // Создаем отдельные потоки для разных клиентов
/// final clientStream1 = broadcaster.createStream();
/// final clientStream2 = broadcaster.createStream();
///
/// // Или с использованием callable синтаксиса:
/// final clientStream1 = broadcaster();
/// final clientStream2 = broadcaster();
///
/// // Все клиенты получат одинаковые данные
/// clientStream1.listen((data) => print('Client 1: $data'));
/// clientStream2.listen((data) => print('Client 2: $data'));
///
/// // При необходимости можно закрыть broadcaster
/// await broadcaster.close();
/// ```
/// {@endtemplate}
class StreamBroadcaster<T> {
  /// Исходный поток данных
  final Stream<T> _source;

  /// Контроллер для широковещательной трансляции
  final StreamController<T> _controller;

  /// Подписка на исходный поток
  StreamSubscription<T>? _subscription;

  /// Счетчик активных дочерних потоков
  int _activeStreamsCount = 0;

  /// Список активных контроллеров для точного отслеживания и закрытия
  final Set<StreamController<T>> _activeControllers = {};

  /// Список активных подписок для точного отслеживания
  final Set<StreamSubscription> _activeSubscriptions = {};

  /// Флаг закрытия broadcaster
  bool _isClosed = false;

  /// Логгер для отладки
  late final RpcLogger? _logger;

  /// {@macro stream_broadcaster}
  StreamBroadcaster(
    this._source, {
    RpcLogger? logger,
    bool autoStart = true,
  }) : _controller = StreamController<T>.broadcast() {
    _logger = logger?.child('StreamBroadcaster');
    if (autoStart) {
      _subscribe();
    }
  }

  /// Создает подписку на исходный поток, если её еще нет
  void _subscribe() {
    if (_subscription != null || _isClosed) return;

    _logger?.debug('Подписка на исходный поток');

    _subscription = _source.listen(
      (data) {
        if (!_controller.isClosed) {
          _controller.add(data);
        }
      },
      onError: (error, stackTrace) {
        _logger?.error(
          'Ошибка в исходном потоке',
          error: error,
          stackTrace: stackTrace,
        );
        if (!_controller.isClosed) {
          _controller.addError(error, stackTrace);
        }
      },
      onDone: () {
        _logger?.debug('Исходный поток завершен, закрываем broadcaster');
        close();
      },
    );
  }

  /// Создает новый дочерний поток, подключенный к родительскому
  ///
  /// Возвращает поток, который будет получать все данные из исходного потока.
  /// Если broadcaster закрыт, возвращает пустой поток, который сразу завершается.
  Stream<T> createStream() {
    if (_isClosed) {
      _logger?.warning(
        'Попытка создать поток после закрытия',
      );
      return Stream<T>.empty();
    }

    if (_subscription == null) {
      _subscribe();
    } else if (_activeStreamsCount == 0) {
      // Если это первый слушатель после паузы, возобновляем подписку
      _resumeSubscription();
    }

    // Создаем контроллер для отдельного потока, чтобы контролировать его жизненный цикл
    final controller = StreamController<T>();
    _activeControllers.add(controller);

    // Подписываемся на широковещательный поток и передаем данные в индивидуальный контроллер
    final subscription = _controller.stream.listen(
      (data) {
        if (!controller.isClosed) {
          controller.add(data);
        }
      },
      onError: (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    // Отслеживаем активные подписки
    _activeStreamsCount++;
    _activeSubscriptions.add(subscription);
    _logger?.debug(
      'Создан новый дочерний поток (активно: $_activeStreamsCount)',
    );

    // Обрабатываем закрытие контроллера для корректного подсчета активных потоков
    controller.onCancel = () async {
      _logger?.debug('Запрос на отмену дочернего потока');

      // Удаляем контроллер из списка активных
      _activeControllers.remove(controller);

      // Отменяем подписку
      await subscription.cancel();

      // Обновляем счетчик и список активных подписок
      _activeSubscriptions.remove(subscription);
      _activeStreamsCount = _activeSubscriptions.length;

      _logger?.debug(
        'Дочерний поток отписался (осталось: $_activeStreamsCount)',
      );

      // Если больше нет активных потоков, можно приостановить подписку
      if (_activeStreamsCount == 0 && !_isClosed) {
        _pauseSubscription();
      }
    };

    return controller.stream;
  }

  /// Вызывает [createStream] для использования класса как callable.
  ///
  /// Это позволяет использовать более короткий синтаксис:
  /// ```dart
  /// final childStream = broadcaster();
  /// ```
  Stream<T> call() {
    return createStream();
  }

  /// Приостанавливает подписку на исходный поток
  void _pauseSubscription() {
    _subscription?.pause();
    _logger?.debug(
      'Подписка приостановлена (нет активных потоков)',
    );
  }

  /// Возобновляет подписку на исходный поток
  void _resumeSubscription() {
    _subscription?.resume();
    _logger?.debug('Подписка возобновлена');
  }

  /// Закрывает broadcaster и освобождает ресурсы
  ///
  /// После вызова этого метода создание новых дочерних потоков невозможно,
  /// а все существующие потоки получат сигнал завершения.
  Future<void> close() async {
    if (_isClosed) return;

    _isClosed = true;
    _logger?.debug('Закрытие broadcaster начато');

    // Сначала закрываем все контроллеры, чтобы отправить событие onDone подписчикам
    final controllersToClose = List.from(_activeControllers);
    for (final controller in controllersToClose) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _activeControllers.clear();

    // Отменяем все подписки на broadcast-контроллер
    final subscriptionsToCancel = List.from(_activeSubscriptions);
    for (final subscription in subscriptionsToCancel) {
      await subscription.cancel();
    }
    _activeSubscriptions.clear();
    _activeStreamsCount = 0;

    // Отменяем подписку на исходный поток
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }

    // Закрываем основной контроллер, если он еще не закрыт
    if (!_controller.isClosed) {
      await _controller.close();
    }

    _logger?.debug('Broadcaster закрыт');
  }

  /// Общее количество созданных дочерних потоков
  int get streamCount => _activeStreamsCount;

  /// Возвращает true, если broadcaster закрыт
  bool get isClosed => _isClosed;
}
