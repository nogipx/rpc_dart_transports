import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

import 'client_streaming_models.dart';

/// Константа с источником логов для сервера
const String _source = 'ServerStreamService';

/// Контракт стриминг-сервиса
abstract final class StreamServiceContract extends RpcServiceContract {
  StreamServiceContract() : super('StreamService');

  static const nameProcessDataBlocks = 'processDataBlocks';

  @override
  void setup() {
    // Метод обработки блоков данных (client streaming)
    addClientStreamingMethod<DataBlock, DataBlockResult>(
      methodName: nameProcessDataBlocks,
      handler: processDataBlocks,
      argumentParser: DataBlock.fromJson,
      responseParser: DataBlockResult.fromJson,
    );
    super.setup();
  }

  // Абстрактный метод, который должен быть реализован
  ClientStreamingBidiStream<DataBlock, DataBlockResult> processDataBlocks();
}

/// Серверная реализация StreamService
final class ServerStreamService extends StreamServiceContract {
  @override
  ClientStreamingBidiStream<DataBlock, DataBlockResult> processDataBlocks() {
    RpcLog.debug(
      message: 'Создание обработчика для блоков файла',
      source: _source,
    );

    final bidiStream =
        BidiStreamGenerator<DataBlock, DataBlockResult>((requests) async* {
          RpcLog.debug(
            message: 'Начата обработка блоков файла',
            source: _source,
          );

          // Счетчики для обработки файла
          int blockCount = 0; // Количество блоков
          int totalSize = 0; // Общий размер файла в байтах
          String? metadata; // Метаданные файла

          RpcLog.debug(
            message: 'Начинаем получение блоков файла...',
            source: _source,
          );

          try {
            // Получаем блоки данных из потока
            await for (final block in requests) {
              blockCount++;
              totalSize += block.data.length;

              // Сохраняем метаданные из первого блока (например, имя файла)
              if (metadata == null && block.metadata.isNotEmpty) {
                metadata = block.metadata;
              }

              RpcLog.debug(
                message:
                    'Получен блок #${block.index}: ${block.data.length} байт',
                source: _source,
              );

              // Имитация обработки больших блоков данных (проверка на вирусы, расчет хеша и т.д.)
              // Уменьшаем задержку, чтобы не срабатывал таймаут в примере
              if (block.data.length > 1000) {
                RpcLog.debug(
                  message: 'Обработка большого блока данных...',
                  source: _source,
                );
                await Future.delayed(Duration(milliseconds: 10));
              }
            }

            RpcLog.debug(
              message:
                  'Завершена обработка $blockCount блоков, общий размер: $totalSize байт',
              source: _source,
            );

            // Формируем отчет о загрузке файла
            final result = DataBlockResult(
              blockCount: blockCount,
              totalSize: totalSize,
              metadata: metadata ?? 'unknown',
              processingTime: DateTime.now().toIso8601String(),
            );

            RpcLog.debug(
              message: 'Отправка результата обработки: $result',
              source: _source,
            );

            // Возвращаем результат обработки клиенту
            yield result;
          } catch (e, stack) {
            RpcLog.error(
              message: 'Произошла ошибка при обработке файла',
              source: _source,
              error: {'error': e.toString()},
              stackTrace: stack.toString(),
            );
            rethrow;
          }
        }).create();

    return ClientStreamingBidiStream<DataBlock, DataBlockResult>(bidiStream);
  }
}

/// Клиентская реализация StreamService
final class ClientStreamService extends StreamServiceContract {
  final RpcEndpoint _endpoint;

  ClientStreamService(this._endpoint);

  @override
  ClientStreamingBidiStream<DataBlock, DataBlockResult> processDataBlocks() =>
      _endpoint
          .clientStreaming(
            serviceName: serviceName,
            methodName: StreamServiceContract.nameProcessDataBlocks,
          )
          .call<DataBlock, DataBlockResult>(
            responseParser: DataBlockResult.fromJson,
          );
}
