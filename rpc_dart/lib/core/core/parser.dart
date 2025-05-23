part of '../_index.dart';

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

    // Выводим информацию о входящих данных для отладки
    final hexBytes = data.length > 20
        ? data
            .sublist(0, 20)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ')
        : data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print(
        '[RpcMessageParser] Получены данные размером: ${data.length} байт. Первые байты: $hexBytes');

    // Добавляем данные в буфер
    _state.buffer.addAll(data);

    print(
        '[RpcMessageParser] Длина буфера после добавления: ${_state.buffer.length} байт');
    if (_state.buffer.length >= 5) {
      final bufferHex = _state.buffer
          .take(20)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      print('[RpcMessageParser] Первые байты буфера: $bufferHex');
    }

    // Обрабатываем буфер, пока можем извлекать сообщения
    while (_state.buffer.length >= GrpcConstants.MESSAGE_PREFIX_SIZE) {
      print(
          '[RpcMessageParser] Проверяем наличие заголовка в буфере (${_state.buffer.length} байт)');

      // Если мы еще не знаем длину сообщения, извлекаем ее из заголовка
      if (_state.expectedMessageLength == null) {
        print('[RpcMessageParser] Парсим заголовок сообщения');
        try {
          final header =
              GrpcMessageFrame.parseHeader(Uint8List.fromList(_state.buffer));
          _state.isCompressed = header.isCompressed;
          _state.expectedMessageLength = header.messageLength;

          print(
              '[RpcMessageParser] Заголовок распарсен: сжатие=${_state.isCompressed}, длина=${_state.expectedMessageLength}');

          // Удаляем заголовок из буфера
          _state.buffer =
              _state.buffer.sublist(GrpcConstants.MESSAGE_PREFIX_SIZE);
          print(
              '[RpcMessageParser] Заголовок удален, теперь буфер содержит ${_state.buffer.length} байт');
        } catch (e) {
          print('[RpcMessageParser] Ошибка при парсинге заголовка: $e');
          return result; // Возвращаем то, что есть, при ошибке
        }
      }

      // Если у нас достаточно данных для полного сообщения
      if (_state.buffer.length >= _state.expectedMessageLength!) {
        print(
            '[RpcMessageParser] Есть полное сообщение. Буфер: ${_state.buffer.length} байт, ожидаемая длина: ${_state.expectedMessageLength} байт');

        // Извлекаем сообщение
        final messageBytes =
            _state.buffer.sublist(0, _state.expectedMessageLength!);
        print(
            '[RpcMessageParser] Извлечено сообщение размером: ${messageBytes.length} байт');
        result.add(Uint8List.fromList(messageBytes));

        // Обновляем буфер, удаляя обработанное сообщение
        _state.buffer = _state.buffer.sublist(_state.expectedMessageLength!);
        print(
            '[RpcMessageParser] Обновлен буфер, теперь содержит ${_state.buffer.length} байт');

        // Сбрасываем состояние для следующего сообщения
        _state.reset();
        print('[RpcMessageParser] Состояние сброшено для следующего сообщения');
      } else {
        // Недостаточно данных для полного сообщения, нужно ждать
        print(
            '[RpcMessageParser] Недостаточно данных для полного сообщения. Буфер: ${_state.buffer.length} байт, ожидаемая длина: ${_state.expectedMessageLength} байт');
        break;
      }
    }

    print(
        '[RpcMessageParser] Обработка завершена, извлечено сообщений: ${result.length}');
    return result;
  }
}
