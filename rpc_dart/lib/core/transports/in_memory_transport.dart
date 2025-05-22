part of '../_index.dart';

/// Транспорт для обмена сообщениями в памяти без изолятов.
///
/// Реализация транспортного уровня, которая работает полностью в памяти
/// в пределах одного потока. Используется для тестирования и
/// демонстрации работы RPC без сетевого взаимодействия или изолятов.
class InMemoryTransport implements IRpcTransport {
  /// Контроллер для отправки сообщений партнерскому транспорту
  final StreamController<RpcTransportMessage<Uint8List>> _outgoingController;

  /// Контроллер для управления потоком входящих сообщений
  final StreamController<RpcTransportMessage<Uint8List>> _incomingController =
      StreamController<RpcTransportMessage<Uint8List>>();

  /// Флаг, указывающий, что отправка завершена
  bool _sendingFinished = false;

  /// Флаг, указывающий, что транспорт закрыт
  bool _closed = false;

  /// Создает новый транспорт для обмена сообщениями в памяти
  ///
  /// [_outgoingController] Контроллер для отправки сообщений партнеру
  InMemoryTransport(this._outgoingController) {
    // Проверяем, что контроллер еще открыт
    if (_outgoingController.isClosed) {
      throw StateError('Контроллер для отправки сообщений закрыт');
    }
  }

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages =>
      _incomingController.stream;

  /// Добавляет входящее сообщение в поток (вызывается партнерским транспортом)
  void addIncomingMessage(RpcTransportMessage<Uint8List> message) {
    if (!_incomingController.isClosed) {
      _incomingController.add(message);

      // Если это сообщение завершающее, закрываем контроллер
      if (message.isEndOfStream) {
        _incomingController.close();
      }
    }
  }

  @override
  Future<void> sendMetadata(RpcMetadata metadata,
      {bool endStream = false}) async {
    if (_sendingFinished || _closed) return;

    _outgoingController.add(RpcTransportMessage<Uint8List>(
      metadata: metadata,
      isEndOfStream: endStream,
    ));

    if (endStream) {
      _sendingFinished = true;
      await finishSending();
    }
  }

  @override
  Future<void> sendMessage(Uint8List data, {bool endStream = false}) async {
    if (_sendingFinished || _closed) return;

    _outgoingController.add(RpcTransportMessage<Uint8List>(
      payload: data,
      isEndOfStream: endStream,
    ));

    if (endStream) {
      _sendingFinished = true;
      await finishSending();
    }
  }

  @override
  Future<void> finishSending() async {
    if (_sendingFinished || _closed) return;

    _sendingFinished = true;
  }

  @override
  Future<void> close() async {
    if (_closed) return;

    _closed = true;
    _sendingFinished = true;

    if (!_outgoingController.isClosed) {
      await _outgoingController.close();
    }

    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
  }
}

/// Фабрика для создания пары связанных транспортов в памяти.
///
/// Создает два соединенных транспорта для двустороннего обмена
/// сообщениями в памяти. Полезно для тестирования и примеров.
class InMemoryTransportPair {
  /// Создает пару соединенных транспортов для обмена данными
  ///
  /// Возвращает кортеж (первый транспорт, второй транспорт)
  static (InMemoryTransport, InMemoryTransport) create() {
    // Создаем контроллеры для обмена сообщениями в обоих направлениях
    final firstToSecondController =
        StreamController<RpcTransportMessage<Uint8List>>();
    final secondToFirstController =
        StreamController<RpcTransportMessage<Uint8List>>();

    // Создаем транспорты
    final firstTransport = InMemoryTransport(firstToSecondController);
    final secondTransport = InMemoryTransport(secondToFirstController);

    // Подписываемся на сообщения для передачи между транспортами
    firstToSecondController.stream.listen(
      secondTransport.addIncomingMessage,
      onDone: () {
        if (!secondTransport._incomingController.isClosed) {
          secondTransport._incomingController.close();
        }
      },
    );

    secondToFirstController.stream.listen(
      firstTransport.addIncomingMessage,
      onDone: () {
        if (!firstTransport._incomingController.isClosed) {
          firstTransport._incomingController.close();
        }
      },
    );

    return (firstTransport, secondTransport);
  }
}
