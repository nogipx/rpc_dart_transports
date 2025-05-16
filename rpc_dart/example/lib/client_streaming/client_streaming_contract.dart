import 'package:rpc_dart/rpc_dart.dart';
import '../utils/logger.dart';

import 'client_streaming_models.dart';

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
  /// Логгер для серверной части
  final logger = ExampleLogger('ServerStreamService');

  @override
  ClientStreamingBidiStream<DataBlock, DataBlockResult> processDataBlocks() {
    logger.debug('Создание обработчика для блоков файла');

    final bidiStream =
        BidiStreamGenerator<DataBlock, DataBlockResult>((requests) async* {
          logger.debug('Начата обработка блоков файла');

          // Счетчики для обработки файла
          int blockCount = 0; // Количество блоков
          int totalSize = 0; // Общий размер файла в байтах
          String? metadata; // Метаданные файла

          logger.debug('Начинаем получение блоков файла...');

          try {
            // Получаем блоки данных из потока
            await for (final block in requests) {
              blockCount++;
              totalSize += block.data.length;

              // Сохраняем метаданные из первого блока (например, имя файла)
              if (metadata == null && block.metadata.isNotEmpty) {
                metadata = block.metadata;
              }

              logger.debug(
                'Получен блок #${block.index}: ${block.data.length} байт',
              );

              // Имитация обработки больших блоков данных (проверка на вирусы, расчет хеша и т.д.)
              // Уменьшаем задержку, чтобы не срабатывал таймаут в примере
              if (block.data.length > 1000) {
                logger.debug('Обработка большого блока данных...');
                await Future.delayed(Duration(milliseconds: 10));
              }
            }

            logger.debug(
              'Завершена обработка $blockCount блоков, общий размер: $totalSize байт',
            );

            // Формируем отчет о загрузке файла
            final result = DataBlockResult(
              blockCount: blockCount,
              totalSize: totalSize,
              metadata: metadata ?? 'unknown',
              processingTime: DateTime.now().toIso8601String(),
            );

            logger.debug('Отправка результата обработки: $result');

            // Возвращаем результат обработки клиенту
            yield result;
          } catch (e, stack) {
            logger.error('Произошла ошибка при обработке файла', e, stack);
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
