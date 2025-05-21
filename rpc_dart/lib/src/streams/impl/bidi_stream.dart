// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Основной класс двунаправленного потока данных
/// Это простая обёртка над потоком, которая поддерживает:
/// - Отправку сообщений (send)
/// - Получение сообщений (as Stream)
/// - Завершение передачи данных (finishTransfer)
/// - Закрытие потока (close)
class BidiStream<Request extends IRpcSerializableMessage,
        Response extends IRpcSerializableMessage>
    extends RpcStream<Request, Response> {
  /// Функция отправки данных
  final void Function(Request data) _sendFunction;

  /// Функция завершения передачи данных (но не закрытия потока)
  final Future<void> Function()? _finishTransferFunction;

  /// Состояние - завершена ли передача данных
  bool _isTransferFinished = false;

  /// Создает двунаправленный поток
  BidiStream({
    required Stream<Response> responseStream,
    required void Function(Request data) sendFunction,
    Future<void> Function()? finishTransferFunction,
    required Future<void> Function() closeFunction,
  })  : _sendFunction = sendFunction,
        _finishTransferFunction = finishTransferFunction,
        super(
          responseStream: responseStream,
          closeFunction: closeFunction,
        );

  /// Отправляет сообщение в поток
  void send(Request data) {
    if (isClosed || _isTransferFinished) {
      throw StateError(
          'Нельзя отправлять сообщения в закрытый поток или после завершения передачи');
    }
    _sendFunction(data);
  }

  /// Сигнализирует о завершении передачи данных, но не закрывает поток
  Future<void> finishTransfer() async {
    if (isClosed || _isTransferFinished) {
      return;
    }

    _isTransferFinished = true;

    if (_finishTransferFunction != null) {
      await _finishTransferFunction!();
    } else {
      await close();
    }
  }

  /// Возвращает, завершена ли передача данных
  bool get isTransferFinished => _isTransferFinished;

  /// Закрывает поток (переопределяет метод базового класса)
  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    // Если передача данных еще не завершена, завершаем её
    if (!_isTransferFinished && _finishTransferFunction != null) {
      await finishTransfer();
    }

    // Вызываем метод базового класса для завершения закрытия
    await super.close();
  }
}

/// Декоратор для создания двунаправленных стримов на основе async* генераторов
final class BidiStreamGenerator<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  /// Функция-генератор, которая принимает стрим запросов и возвращает стрим ответов
  final Stream<Response> Function(Stream<Request>) _generator;

  /// Создает новый декоратор с указанной функцией-генератором
  BidiStreamGenerator(this._generator);

  /// Создает BidiStream из текущего генератора и начального стрима запросов
  BidiStream<Request, Response> create([Stream<Request>? initialRequests]) {
    // Создаем контроллер для запросов
    final requestController = StreamController<Request>.broadcast();
    final logger = RpcLogger('BidiStreamGenerator');

    logger.debug(
        'ДИАГНОСТИКА: создание BidiStream, initialRequests: ${initialRequests != null}');

    // Если есть начальные запросы, перенаправляем их в контроллер
    if (initialRequests != null) {
      logger.debug('ДИАГНОСТИКА: подписка на initialRequests');
      initialRequests.listen(
        (request) {
          logger.debug('ДИАГНОСТИКА: получен initialRequest: $request');
          requestController.add(request);
        },
        onError: (error) {
          logger.error('ДИАГНОСТИКА: ошибка в initialRequests: $error');
          requestController.addError(error);
        },
        onDone: () {
          logger.debug(
              'ДИАГНОСТИКА: initialRequests завершен, но контроллер остается открытым');
        },
      );
    }

    // Перехватываем сообщения от клиента для логирования
    // и обеспечиваем правильное преобразование типов
    final trackedStream = requestController.stream
        .asBroadcastStream()
        .asyncMap<Request>((dynamic request) async {
      logger.debug(
          'ДИАГНОСТИКА: получен запрос: $request, тип: ${request.runtimeType}');

      // Если у нас карта, нужно ее преобразовать в запрос
      if (request is Map<String, dynamic>) {
        logger.debug('ДИАГНОСТИКА: преобразование Map в Request: $request');
        try {
          // Предполагаем, что генерик Request имеет метод fromJson
          // либо преобразование типа
          if (request.containsKey('v') && Request == RpcString) {
            logger.debug('ДИАГНОСТИКА: создание RpcString из ${request['v']}');
            return RpcString(request['v']) as Request;
          }
          final typedRequest = request as Request;
          logger.debug('ДИАГНОСТИКА: преобразовано в Request: $typedRequest');
          return typedRequest;
        } catch (e, stackTrace) {
          logger.error('ДИАГНОСТИКА: ошибка преобразования запроса: $e',
              error: e, stackTrace: stackTrace);
          // Если не удалось преобразовать, возвращаем как есть
          return request as Request;
        }
      }

      return request as Request;
    });

    // Генерируем ответы с помощью переданного генератора
    logger.debug('ДИАГНОСТИКА: запуск функции-генератора с trackedStream');
    final responseStream = _generator(trackedStream).asyncMap((response) {
      logger.debug(
          'ДИАГНОСТИКА: ПОЛУЧЕН ОТВЕТ ОТ ГЕНЕРАТОРА: $response, тип: ${response.runtimeType}');
      return response;
    });
    logger.debug(
        'ДИАГНОСТИКА: функция-генератор запущена, получен responseStream');

    // Создаем BidiStream
    logger
        .debug('ДИАГНОСТИКА: создание экземпляра BidiStream с responseStream');
    return BidiStream<Request, Response>(
      responseStream: responseStream,
      sendFunction: (request) {
        if (!requestController.isClosed) {
          logger.debug(
              'ДИАГНОСТИКА: отправка запроса через BidiStream: $request');
          requestController.add(request);
        } else {
          logger.error(
              'ДИАГНОСТИКА: попытка отправить запрос в закрытый контроллер: $request');
        }
      },
      finishTransferFunction: () async {
        // При завершении передачи данных просто закрываем контроллер,
        // так как прямая отправка маркера завершения через контроллер невозможна
        // из-за строгой типизации (мы не можем преобразовать Map<String, bool> к Request)
        if (!requestController.isClosed) {
          try {
            // Нельзя отправить маркер завершения через типизированный контроллер,
            // это должно быть реализовано на уровне выше (в ClientStreamingRpcMethod)

            // Просто закрываем контроллер
            logger.debug(
                'ДИАГНОСТИКА: закрытие контроллера в finishTransferFunction');
            await requestController.close();

            // Логируем для отладки
            logger.debug(
                'ДИАГНОСТИКА: контроллер запросов закрыт в finishTransferFunction');
          } catch (e, stackTrace) {
            // Если произошла ошибка при закрытии, логируем ее
            logger.error(
              'ДИАГНОСТИКА: ошибка при завершении потока передачи: $e',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
      },
      closeFunction: () async {
        if (!requestController.isClosed) {
          logger.debug('ДИАГНОСТИКА: закрытие контроллера в closeFunction');
          await requestController.close();
        }
      },
    );
  }

  /// Создает ServerStreamingBidiStream напрямую из генератора
  ///
  /// [initialRequest] - начальный запрос, который будет отправлен сразу после создания стрима
  ServerStreamingBidiStream<Request, Response> createServerStreaming({
    Request? initialRequest,
  }) {
    // Сначала создаем обычный BidiStream
    final bidiStream = create();

    // Оборачиваем его в ServerStreamingBidiStream
    final serverStreamBidi = ServerStreamingBidiStream<Request, Response>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );

    // Если был передан начальный запрос, отправляем его
    if (initialRequest != null) {
      serverStreamBidi.sendRequest(initialRequest);
    }

    return serverStreamBidi;
  }

  /// Создает ClientStreamingBidiStream напрямую из генератора
  ///
  /// [initialRequests] - начальный поток запросов (опционально)
  ClientStreamingBidiStream<Request, Response> createClientStreaming([
    Stream<Request>? initialRequests,
  ]) {
    final bidiStream = create(initialRequests);

    return ClientStreamingBidiStream<Request, Response>(bidiStream);
  }
}
