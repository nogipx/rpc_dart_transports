import 'package:rpc_dart/rpc_dart.dart';

import 'client_streaming_models.dart';

/// Контракт стриминг-сервиса
abstract final class StreamServiceContract extends RpcServiceContract {
  StreamServiceContract() : super('StreamService');

  static const nameProcessDataBlocks = 'processDataBlocks';
  static const nameProcessDataBlocksNoResponse = 'processDataBlocksNoResponse';
  static const nameProcessDataBlocksWithResponse =
      'processDataBlocksWithResponse';

  @override
  void setup() {
    // Метод обработки блоков данных с возвратом результата после завершения обработки
    addClientStreamingMethod<DataBlock, DataBlockResult>(
      methodName: nameProcessDataBlocksWithResponse,
      handler: processDataBlocksWithResponse,
      argumentParser: DataBlock.fromJson,
      responseParser: DataBlockResult.fromJson,
    );

    super.setup();
  }

  // Абстрактный метод с возвратом результата после обработки всех блоков
  ClientStreamingBidiStream<DataBlock, DataBlockResult>
  processDataBlocksWithResponse();
}

/// Серверная реализация StreamService
final class ServerStreamService extends StreamServiceContract {
  RpcLogger get _logger => RpcLogger('ServerStreamService');

  @override
  ClientStreamingBidiStream<DataBlock, DataBlockResult>
  processDataBlocksWithResponse() {
    _logger.debug('Начата обработка блоков файла с возвратом результата');

    // Счетчики для обработки файла
    int blockCount = 0; // Количество блоков
    int totalSize = 0; // Общий размер файла в байтах
    String metadata = ''; // Метаданные файла
    final startTime = DateTime.now();

    final bidiStream =
        BidiStreamGenerator<DataBlock, DataBlockResult>((requests) async* {
          try {
            // Получаем блоки данных из потока
            await for (final block in requests) {
              blockCount++;
              totalSize += block.data.length;

              // Сохраняем метаданные из первого блока
              if (metadata.isEmpty && block.metadata.isNotEmpty) {
                metadata = block.metadata;
              }

              _logger.debug(
                'Получен блок #${block.index}: ${block.data.length} байт (с ответом)',
              );

              // Имитация обработки
              if (block.data.length > 1000) {
                _logger.debug('Обработка большого блока данных (с ответом)...');
                await Future.delayed(Duration(milliseconds: 15));
              }
            }

            _logger.debug(
              'Завершена обработка $blockCount блоков, общий размер: $totalSize байт',
            );

            // Отправляем финальный результат обработки только после получения всех блоков
            yield DataBlockResult(
              blockCount: blockCount,
              totalSize: totalSize,
              metadata: metadata,
              processingTime:
                  '${DateTime.now().difference(startTime).inMilliseconds} мс',
            );

            _logger.debug('Результат обработки отправлен клиенту');
          } catch (error, trace) {
            _logger.error(
              'Произошла ошибка при обработке файла с ответом',
              error: error,
              stackTrace: trace,
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
  ClientStreamingBidiStream<DataBlock, DataBlockResult>
  processDataBlocksWithResponse() {
    return _endpoint
        .clientStreaming(
          serviceName: serviceName,
          methodName: StreamServiceContract.nameProcessDataBlocksWithResponse,
        )
        .call<DataBlock, DataBlockResult>(
          responseParser: DataBlockResult.fromJson,
        );
  }
}
