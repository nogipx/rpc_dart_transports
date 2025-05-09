import 'dart:async';
import 'dart:typed_data';
import '_index.dart';

/// Реализация транспорта, работающая в памяти
///
/// Используется для тестирования и для коммуникации
/// между компонентами в рамках одного процесса
class MemoryTransport implements RpcTransport {
  /// Идентификатор транспорта
  @override
  final String id;

  /// Контроллер для публикации входящих сообщений
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  /// Пункт назначения сообщений
  MemoryTransport? _destination;

  /// Флаг доступности транспорта
  bool _isAvailable = true;

  /// Создает новый экземпляр в памяти
  ///
  /// [id] - уникальный идентификатор транспорта
  MemoryTransport(this.id);

  /// Соединяет текущий транспорт с другим транспортом
  ///
  /// [destination] - транспорт-получатель сообщений
  /// Возвращает destination для создания цепочек
  MemoryTransport connect(MemoryTransport destination) {
    _destination = destination;
    return destination;
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data) async {
    if (!isAvailable) {
      print('Transport is not available: $id');
      return RpcTransportActionStatus.transportUnavailable;
    }

    if (_destination == null) {
      print('Destination is null: $id');
      return RpcTransportActionStatus.connectionNotEstablished;
    }

    try {
      // Имитируем небольшую задержку при отправке сообщения
      await Future.delayed(const Duration(milliseconds: 1));

      // Отправляем данные в пункт назначения
      _destination!._receiveData(data);
      return RpcTransportActionStatus.success;
    } catch (e) {
      print('Ошибка при отправке данных: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  /// Обрабатывает входящие данные
  void _receiveData(Uint8List data) {
    if (!_isAvailable) return;

    _incomingController.add(data);
  }

  @override
  Future<RpcTransportActionStatus> close() async {
    _isAvailable = false;
    try {
      await _incomingController.close();
      return RpcTransportActionStatus.success;
    } catch (e) {
      print('Ошибка при закрытии транспорта: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  bool get isAvailable => _isAvailable;
}
