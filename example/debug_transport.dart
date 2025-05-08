import 'dart:async';
import 'dart:typed_data';

import 'package:rpc_dart/rpc_dart.dart';

/// Отладочный транспорт
class DebugTransport extends MemoryTransport {
  DebugTransport(super.id);

  void _log(String message) {
    print('DebugTransport[$id]: $message');
  }

  @override
  Future<void> send(Uint8List data) async {
    _log('ОТПРАВЛЯЕТ: ${data.length} байт');
    return super.send(data);
  }

  @override
  Stream<Uint8List> receive() {
    final controller = StreamController<Uint8List>.broadcast();

    super.receive().listen((data) {
      _log('ПОЛУЧАЕТ: ${data.length} байт');

      // Распаковываем сообщение для отладки
      try {
        final serializer = JsonSerializer();
        final json = serializer.deserialize(data);
        if (json is Map<String, dynamic>) {
          final type = json['type'] as int?;
          final id = json['id'] as String?;
          final payload = json['payload'] as dynamic;
          _log('Сообщение: type=$type, id=$id, payload=$payload');
        }
      } catch (e) {
        _log('Ошибка при разборе сообщения: $e');
      }

      controller.add(data);
    });

    return controller.stream;
  }

  @override
  Future<void> close() {
    _log('ЗАКРЫВАЕТСЯ');
    return super.close();
  }
}
