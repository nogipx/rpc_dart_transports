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
    final requestController = StreamController<Request>();

    // Если есть начальные запросы, перенаправляем их в контроллер
    if (initialRequests != null) {
      initialRequests.listen(
        (request) => requestController.add(request),
        onError: (error) => requestController.addError(error),
        onDone:
            () {}, // Не закрываем контроллер, так как через него можно будет отправлять запросы позже
      );
    }

    // Генерируем ответы с помощью переданного генератора
    final responseStream = _generator(requestController.stream);

    // Создаем BidiStream
    return BidiStream<Request, Response>(
      responseStream: responseStream,
      sendFunction: (request) {
        if (!requestController.isClosed) {
          requestController.add(request);
        }
      },
      finishTransferFunction: () async {
        // При завершении передачи данных не закрываем контроллер,
        // просто сигнализируем, что данных больше не будет
        // Специальный маркер завершения добавляется через sendFunction
        // в реализациях методов высокого уровня (например, ClientStreamingRpcMethod)
        if (!requestController.isClosed) {
          // Если нужно добавить специальный маркер завершения непосредственно здесь,
          // можно сделать это, но сейчас мы оставляем эту ответственность на более высоком уровне
        }
      },
      closeFunction: () async {
        if (!requestController.isClosed) {
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
    return ClientStreamingBidiStream<Request, Response>(create());
  }
}
