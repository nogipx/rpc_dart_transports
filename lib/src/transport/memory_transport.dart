import 'dart:async';
import 'dart:typed_data';
import 'transport.dart';

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
  Future<void> send(Uint8List data) async {
    if (!isAvailable || _destination == null) {
      throw StateError('Транспорт недоступен или нет получателя');
    }

    // Имитируем небольшую задержку при отправке сообщения
    await Future.delayed(const Duration(milliseconds: 1));

    // Отправляем данные в пункт назначения
    _destination!._receiveData(data);
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
  Future<void> close() async {
    _isAvailable = false;
    await _incomingController.close();
  }

  @override
  bool get isAvailable => _isAvailable;
}
