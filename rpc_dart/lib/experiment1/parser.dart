part of '_index.dart';

/// Состояние процесса парсинга входящих данных потока gRPC.
///
/// Управляет буферизацией и состоянием парсинга при обработке
/// фрагментированных сообщений gRPC. Сообщения могут приходить
/// по частям или несколько сообщений в одном фрагменте.
class _MessageParserState {
  /// Текущий накопительный буфер данных
  List<int> buffer = [];

  /// Ожидаемая длина текущего сообщения (null, если заголовок еще не прочитан)
  int? expectedMessageLength;

  /// Флаг сжатия для текущего обрабатываемого сообщения
  bool isCompressed = false;

  /// Сбрасывает состояние для обработки следующего сообщения.
  ///
  /// Вызывается после успешного извлечения полного сообщения
  /// для подготовки к обработке следующего.
  void reset() {
    expectedMessageLength = null;
    isCompressed = false;
  }
}

/// Парсер для обработки фрагментированных сообщений gRPC.
///
/// Отвечает за правильную сборку полных сообщений из фрагментированных
/// потоков данных, поступающих через HTTP/2 DATA фреймы. Решает проблему
/// несовпадения границ HTTP/2 фреймов и сообщений gRPC.
final class RpcMessageParser {
  /// Внутреннее состояние парсера
  final _MessageParserState _state = _MessageParserState();

  /// Обрабатывает входящий фрагмент данных и извлекает полные сообщения.
  ///
  /// Накапливает входящие данные в буфере и извлекает из него полные сообщения,
  /// используя информацию о длине из 5-байтного префикса. Может извлечь
  /// несколько сообщений из одного фрагмента или продолжить накопление
  /// для получения полного сообщения.
  ///
  /// [data] Новый фрагмент входящих данных
  /// Возвращает список полных сообщений, извлеченных из данных
  List<Uint8List> call(Uint8List data) {
    final result = <Uint8List>[];

    // Добавляем данные в буфер
    _state.buffer.addAll(data);

    // Обрабатываем буфер, пока можем извлекать сообщения
    while (_state.buffer.length >= GrpcConstants.MESSAGE_PREFIX_SIZE) {
      // Если мы еще не знаем длину сообщения, извлекаем ее из заголовка
      if (_state.expectedMessageLength == null) {
        final header =
            GrpcMessageFrame.parseHeader(Uint8List.fromList(_state.buffer));
        _state.isCompressed = header.isCompressed;
        _state.expectedMessageLength = header.messageLength;

        // Удаляем заголовок из буфера
        _state.buffer =
            _state.buffer.sublist(GrpcConstants.MESSAGE_PREFIX_SIZE);
      }

      // Если у нас достаточно данных для полного сообщения
      if (_state.buffer.length >= _state.expectedMessageLength!) {
        // Извлекаем сообщение
        final messageBytes =
            _state.buffer.sublist(0, _state.expectedMessageLength!);
        result.add(Uint8List.fromList(messageBytes));

        // Обновляем буфер, удаляя обработанное сообщение
        _state.buffer = _state.buffer.sublist(_state.expectedMessageLength!);

        // Сбрасываем состояние для следующего сообщения
        _state.reset();
      } else {
        // Недостаточно данных для полного сообщения, нужно ждать
        break;
      }
    }

    return result;
  }
}
