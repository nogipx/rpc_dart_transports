// ignore_for_file: annotate_overrides
part of '../_index.dart';

/// Типы сообщений между изолятами
enum _IsolateMessageType {
  init,
  metadata,
  data,
  finish,
  close,
}

/// Сообщение для обмена между изолятами
class _IsolateMessage {
  final _IsolateMessageType type;
  final dynamic data;
  final bool isEndOfStream;

  _IsolateMessage({
    required this.type,
    this.data,
    this.isEndOfStream = false,
  });
}

typedef RpcIsolateEntrypoint = void Function(
  IRpcTransport transport,
  Map<String, dynamic> customParams,
);

/// Фабрика для создания транспортов изолята
/// Позволяет создавать пары хост-воркер транспортов с различными настройками
class RpcIsolateTransport {
  /// Запускает изолят с пользовательской entrypoint функцией и возвращает хост-транспорт
  static Future<({IRpcTransport transport, void Function() kill})> spawn({
    required RpcIsolateEntrypoint entrypoint,
    Map<String, dynamic>? customParams,
    String isolateId = 'default',
    String? debugName,
  }) async {
    final name = debugName ?? 'rpc-isolate-$isolateId';

    // Обертка для вызова пользовательской функции после настройки транспорта
    void entrypointWrapper(List<dynamic> args) {
      // Извлекаем параметры
      final hostSendPort = args[0] as SendPort;
      final isolateId = args[1] as String;
      final customParams = args[2] as Map<String, dynamic>;
      final userEntrypoint = args[3] as RpcIsolateEntrypoint;

      print('ИЗОЛЯТ: Запущен с ID $isolateId');

      // Создаем порт для получения сообщений
      final receivePort = ReceivePort();

      // Создаем контроллер для широковещательного доступа к сообщениям
      final messageController = StreamController<dynamic>.broadcast();

      // Перенаправляем сообщения из receivePort в контроллер
      receivePort.listen((message) {
        messageController.add(message);
      });

      // Отправляем SendPort обратно в основной поток
      hostSendPort.send(receivePort.sendPort);

      // Ожидаем SendPort для основной коммуникации
      messageController.stream.listen((message) {
        if (message is _IsolateMessage &&
            message.type == _IsolateMessageType.init) {
          // Получаем SendPort для основной коммуникации
          final mainHostSendPort = message.data as SendPort;

          // Создаем транспорт воркера
          final transport = _IsolateWorkerTransport(
            hostSendPort: mainHostSendPort,
            messageStream: messageController.stream,
          );

          // Вызываем пользовательскую функцию, передавая транспорт
          userEntrypoint(transport, customParams);
        }
      });
    }

    // Канал для начальной инициализации
    final initPort = ReceivePort();

    // Создаем и запускаем изолят с нашей оберткой
    final isolate = await Isolate.spawn(
      entrypointWrapper,
      [
        initPort.sendPort,
        isolateId,
        customParams ?? {},
        entrypoint, // Передаем пользовательскую функцию в изолят
      ],
      debugName: name,
    );

    // Ожидаем SendPort от изолята
    final workerSendPort = await initPort.first as SendPort;

    // Создаем порт для основной коммуникации
    final hostReceivePort = ReceivePort();

    // Отправляем порт для основной коммуникации в изолят
    workerSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.init,
      data: hostReceivePort.sendPort,
    ));

    // Создаем хост-транспорт
    final hostTransport = _IsolateHostTransport(
      workerSendPort: workerSendPort,
      receivePort: hostReceivePort,
    );

    // Функция для завершения изолята
    void killIsolate() {
      hostTransport.close();
      isolate.kill(priority: Isolate.immediate);
    }

    return (transport: hostTransport, kill: killIsolate);
  }
}

/// Транспорт на стороне хоста (основной поток)
class _IsolateHostTransport implements IRpcTransport {
  final SendPort _workerSendPort;
  final ReceivePort _receivePort;

  final StreamController<RpcTransportMessage<Uint8List>> _messageController =
      StreamController<RpcTransportMessage<Uint8List>>.broadcast();

  bool _isClosed = false;

  _IsolateHostTransport({
    required SendPort workerSendPort,
    required ReceivePort receivePort,
  })  : _workerSendPort = workerSendPort,
        _receivePort = receivePort {
    // Настраиваем обработку входящих сообщений
    _receivePort.listen(_handleMessage, onDone: () {
      if (!_messageController.isClosed) {
        _messageController.close();
      }
    });
  }

  void _handleMessage(dynamic message) {
    if (message is! _IsolateMessage) return;

    switch (message.type) {
      case _IsolateMessageType.metadata:
        final metadata = message.data as RpcMetadata;
        _messageController.add(RpcTransportMessage<Uint8List>(
          metadata: metadata,
          isEndOfStream: message.isEndOfStream,
        ));
        break;

      case _IsolateMessageType.data:
        final data = message.data as Uint8List;
        _messageController.add(RpcTransportMessage<Uint8List>(
          payload: data,
          isEndOfStream: message.isEndOfStream,
        ));
        break;

      case _IsolateMessageType.finish:
        _messageController.add(RpcTransportMessage<Uint8List>(
          isEndOfStream: true,
        ));
        break;

      default:
        // Игнорируем другие типы сообщений
        break;
    }
  }

  @override
  Future<void> sendMetadata(RpcMetadata metadata,
      {bool endStream = false}) async {
    if (_isClosed) return;

    _workerSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.metadata,
      data: metadata,
      isEndOfStream: endStream,
    ));
  }

  @override
  Future<void> sendMessage(Uint8List data, {bool endStream = false}) async {
    if (_isClosed) return;

    _workerSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.data,
      data: data,
      isEndOfStream: endStream,
    ));
  }

  @override
  Future<void> finishSending() async {
    if (_isClosed) return;

    _workerSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.finish,
    ));
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    _workerSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.close,
    ));

    _receivePort.close();

    if (!_messageController.isClosed) {
      await _messageController.close();
    }
  }

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages =>
      _messageController.stream;
}

/// Транспорт на стороне воркера (изолят)
class _IsolateWorkerTransport implements IRpcTransport {
  final SendPort _hostSendPort;
  final Stream<dynamic> _messageStream;

  final StreamController<RpcTransportMessage<Uint8List>> _messageController =
      StreamController<RpcTransportMessage<Uint8List>>.broadcast();

  bool _isClosed = false;
  StreamSubscription? _subscription;

  _IsolateWorkerTransport({
    required SendPort hostSendPort,
    required Stream<dynamic> messageStream,
  })  : _hostSendPort = hostSendPort,
        _messageStream = messageStream {
    // Подписываемся на получение сообщений через переданный стрим
    _subscription = _messageStream.listen(_handleMessage);
  }

  void _handleMessage(dynamic message) {
    if (message is! _IsolateMessage) return;

    switch (message.type) {
      case _IsolateMessageType.metadata:
        final metadata = message.data as RpcMetadata;
        _messageController.add(RpcTransportMessage<Uint8List>(
          metadata: metadata,
          isEndOfStream: message.isEndOfStream,
        ));
        break;

      case _IsolateMessageType.data:
        final data = message.data as Uint8List;
        _messageController.add(RpcTransportMessage<Uint8List>(
          payload: data,
          isEndOfStream: message.isEndOfStream,
        ));
        break;

      case _IsolateMessageType.finish:
        _messageController.add(RpcTransportMessage<Uint8List>(
          isEndOfStream: true,
        ));
        break;

      case _IsolateMessageType.close:
        close();
        break;

      default:
        // Игнорируем другие типы сообщений
        break;
    }
  }

  @override
  Future<void> sendMetadata(RpcMetadata metadata,
      {bool endStream = false}) async {
    if (_isClosed) return;

    _hostSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.metadata,
      data: metadata,
      isEndOfStream: endStream,
    ));
  }

  @override
  Future<void> sendMessage(Uint8List data, {bool endStream = false}) async {
    if (_isClosed) return;

    _hostSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.data,
      data: data,
      isEndOfStream: endStream,
    ));
  }

  @override
  Future<void> finishSending() async {
    if (_isClosed) return;

    _hostSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.finish,
    ));
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    _hostSendPort.send(_IsolateMessage(
      type: _IsolateMessageType.close,
    ));

    _subscription?.cancel();

    if (!_messageController.isClosed) {
      await _messageController.close();
    }
  }

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages =>
      _messageController.stream;
}
