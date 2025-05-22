part of '../_index.dart';

/// Сообщение, передаваемое между изолятами.
///
/// Структура данных для передачи сообщений между основным
/// изолятом и рабочим изолятом. Может содержать метаданные,
/// полезную нагрузку и служебные флаги.
class IsolateMessage {
  /// Тип сообщения: 'metadata', 'message' или 'control'
  final String type;

  /// Метаданные (заголовки) если тип 'metadata'
  final List<Map<String, String>>? metadataEntries;

  /// Полезная нагрузка (данные) если тип 'message'
  final Uint8List? payload;

  /// Флаг конца потока
  final bool isEndOfStream;

  /// Управляющие команды для транспорта
  final String? command;

  /// Создает сообщение для передачи через изолят
  IsolateMessage({
    required this.type,
    this.metadataEntries,
    this.payload,
    this.isEndOfStream = false,
    this.command,
  });

  /// Фабричный метод для создания сообщения с метаданными
  static IsolateMessage metadata(List<RpcHeader> headers,
      {bool isEndOfStream = false}) {
    return IsolateMessage(
      type: 'metadata',
      metadataEntries:
          headers.map((h) => {'name': h.name, 'value': h.value}).toList(),
      isEndOfStream: isEndOfStream,
    );
  }

  /// Фабричный метод для создания сообщения с данными
  static IsolateMessage message(Uint8List data, {bool isEndOfStream = false}) {
    return IsolateMessage(
      type: 'message',
      payload: data,
      isEndOfStream: isEndOfStream,
    );
  }

  /// Фабричный метод для создания управляющего сообщения
  static IsolateMessage control(String command) {
    return IsolateMessage(
      type: 'control',
      command: command,
    );
  }

  /// Фабричный метод для создания инициализационного сообщения
  static IsolateMessage init(SendPort replyPort) {
    final portData =
        Uint8List.fromList(replyPort.hashCode.toString().codeUnits);

    return IsolateMessage(
      type: 'control',
      command: 'init',
      payload: portData,
    );
  }
}

/// Транспорт для взаимодействия между изолятами.
///
/// Реализация транспортного уровня, использующая Dart Isolates
/// для передачи gRPC сообщений между изолятами. Позволяет организовать
/// RPC-взаимодействие между частями приложения, работающими в разных потоках.
class IsolateTransport implements IRpcTransport {
  /// Порт для отправки сообщений в другой изолят
  final SendPort _sendPort;

  /// Порт для приема сообщений из другого изолята
  final ReceivePort _receivePort;

  /// Контроллер для потока входящих сообщений
  final StreamController<RpcTransportMessage<Uint8List>> _messageController =
      StreamController<RpcTransportMessage<Uint8List>>();

  /// Флаг, указывающий, что отправка завершена
  bool _sendingFinished = false;

  /// Создает новый транспорт для взаимодействия через изоляты
  ///
  /// [_sendPort] Порт для отправки сообщений в целевой изолят
  IsolateTransport(this._sendPort) : _receivePort = ReceivePort() {
    // Отправляем порт для получения ответов
    _sendPort.send(IsolateMessage.init(_receivePort.sendPort));

    // Настраиваем обработку входящих сообщений
    _receivePort.listen(_handleIncomingMessage);
  }

  /// Обработчик входящих сообщений от другого изолята
  void _handleIncomingMessage(dynamic data) {
    if (data is! Map) return;

    try {
      final type = data['type'] as String?;
      final isEndOfStream = data['isEndOfStream'] as bool? ?? false;

      if (type == 'metadata') {
        final metadataEntries = (data['metadataEntries'] as List?)
            ?.map((entry) => RpcHeader(entry['name'], entry['value']))
            .toList();

        if (metadataEntries != null) {
          _messageController.add(RpcTransportMessage<Uint8List>(
            metadata: RpcMetadata(metadataEntries),
            isEndOfStream: isEndOfStream,
          ));
        }
      } else if (type == 'message') {
        final payload = data['payload'] as Uint8List?;
        if (payload != null) {
          _messageController.add(RpcTransportMessage<Uint8List>(
            payload: payload,
            isEndOfStream: isEndOfStream,
          ));
        }
      } else if (type == 'control' && data['command'] == 'close') {
        _messageController.close();
        _receivePort.close();
      }
    } catch (e) {
      _messageController.addError(e);
    }
  }

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages =>
      _messageController.stream;

  @override
  Future<void> sendMetadata(RpcMetadata metadata,
      {bool endStream = false}) async {
    if (_sendingFinished) return;

    _sendPort.send(IsolateMessage.metadata(
      metadata.headers,
      isEndOfStream: endStream,
    ));

    if (endStream) {
      _sendingFinished = true;
    }
  }

  @override
  Future<void> sendMessage(Uint8List data, {bool endStream = false}) async {
    if (_sendingFinished) return;

    _sendPort.send(IsolateMessage.message(
      data,
      isEndOfStream: endStream,
    ));

    if (endStream) {
      _sendingFinished = true;
    }
  }

  @override
  Future<void> finishSending() async {
    _sendingFinished = true;
    _sendPort.send(IsolateMessage.control('finish'));
  }

  @override
  Future<void> close() async {
    _sendingFinished = true;
    _sendPort.send(IsolateMessage.control('close'));
    _receivePort.close();

    if (!_messageController.isClosed) {
      await _messageController.close();
    }
  }
}

/// Фабрика для создания пары транспортов, соединенных между собой.
///
/// Позволяет создать два связанных транспорта для двустороннего
/// обмена данными между изолятами. Используется для настройки
/// двунаправленной связи между клиентской и серверной частями.
class IsolateTransportPair {
  /// Создает пару связанных транспортов для изолятов
  ///
  /// Возвращает кортеж (firstTransport, secondTransport),
  /// где транспорты соединены друг с другом для двусторонней связи.
  static (IsolateTransport, IsolateTransport) create() {
    final firstReceivePort = ReceivePort();
    final secondReceivePort = ReceivePort();

    final firstTransport = IsolateTransport(secondReceivePort.sendPort);
    final secondTransport = IsolateTransport(firstReceivePort.sendPort);

    return (firstTransport, secondTransport);
  }
}
