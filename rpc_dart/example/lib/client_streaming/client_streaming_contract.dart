import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

import 'client_streaming_models.dart';

/// Контракт стриминг-сервиса
abstract final class StreamServiceContract extends RpcServiceContract {
  StreamServiceContract() : super('StreamService');

  static const nameProcessDataBlocks = 'processDataBlocks';
  static const nameProcessDataBlocksNoResponse = 'processDataBlocksNoResponse';

  @override
  void setup() {
    // Метод обработки блоков данных (client streaming)
    addClientStreamingMethod<DataBlock>(
      methodName: nameProcessDataBlocks,
      handler: processDataBlocks,
      argumentParser: DataBlock.fromJson,
    );

    // Метод обработки блоков данных без ожидания ответа
    addClientStreamingMethod<DataBlock>(
      methodName: nameProcessDataBlocksNoResponse,
      handler: processDataBlocksNoResponse,
      argumentParser: DataBlock.fromJson,
    );

    super.setup();
  }

  // Абстрактный метод, который должен быть реализован
  ClientStreamingBidiStream<DataBlock> processDataBlocks();

  // Абстрактный метод без ожидания ответа
  ClientStreamingBidiStream<DataBlock> processDataBlocksNoResponse();
}

/// Серверная реализация StreamService
final class ServerStreamService extends StreamServiceContract {
  RpcLogger get _logger => RpcLogger('ServerStreamService');

  @override
  ClientStreamingBidiStream<DataBlock> processDataBlocks() {
    _logger.debug('Создание обработчика для блоков файла');

    final bidiStream =
        BidiStreamGenerator<DataBlock, RpcNull>((requests) async* {
          _logger.debug('Начата обработка блоков файла');

          // Счетчики для обработки файла
          int blockCount = 0; // Количество блоков
          int totalSize = 0; // Общий размер файла в байтах
          String? metadata; // Метаданные файла

          _logger.debug('Начинаем получение блоков файла...');

          try {
            // Получаем блоки данных из потока
            await for (final block in requests) {
              blockCount++;
              totalSize += block.data.length;

              // Сохраняем метаданные из первого блока (например, имя файла)
              if (metadata == null && block.metadata.isNotEmpty) {
                metadata = block.metadata;
              }

              _logger.debug(
                'Получен блок #${block.index}: ${block.data.length} байт',
              );

              // Имитация обработки больших блоков данных (проверка на вирусы, расчет хеша и т.д.)
              // Уменьшаем задержку, чтобы не срабатывал таймаут в примере
              if (block.data.length > 1000) {
                _logger.debug('Обработка большого блока данных...');
                await Future.delayed(Duration(milliseconds: 10));
              }
            }

            _logger.debug(
              'Завершена обработка $blockCount блоков, общий размер: $totalSize байт',
            );

            // В упрощенной версии мы обрабатываем данные, но не отправляем ответ
            _logger.debug('Обработка завершена');
          } catch (error, trace) {
            _logger.error(
              'Произошла ошибка при обработке файла',
              error: error,
              stackTrace: trace,
            );
            rethrow;
          }
        }).create();

    return ClientStreamingBidiStream<DataBlock>(bidiStream);
  }

  @override
  ClientStreamingBidiStream<DataBlock> processDataBlocksNoResponse() {
    _logger.debug('Создание обработчика для блоков файла без ожидания ответа');

    final bidiStream =
        BidiStreamGenerator<DataBlock, RpcNull>((requests) async* {
          _logger.debug('Начата обработка блоков файла (без ответа)');

          // Счетчики для обработки файла
          int blockCount = 0; // Количество блоков
          int totalSize = 0; // Общий размер файла в байтах

          _logger.debug('Начинаем получение блоков файла...');

          try {
            // Получаем блоки данных из потока
            await for (final block in requests) {
              blockCount++;
              totalSize += block.data.length;

              _logger.debug(
                'Получен блок #${block.index}: ${block.data.length} байт (без ответа)',
              );

              // Минимальная обработка данных
              if (block.data.length > 1000) {
                await Future.delayed(Duration(milliseconds: 5));
              }
            }

            _logger.debug(
              'Завершена обработка $blockCount блоков, общий размер: $totalSize байт (без ответа)',
            );
          } catch (error, trace) {
            _logger.error(
              'Произошла ошибка при обработке файла (без ответа)',
              error: error,
              stackTrace: trace,
            );
            rethrow;
          }
        }).create();

    // Используем новую версию с упрощенным конструктором
    return ClientStreamingBidiStream<DataBlock>(bidiStream);
  }
}

/// Клиентская реализация StreamService
final class ClientStreamService extends StreamServiceContract {
  final RpcEndpoint _endpoint;

  ClientStreamService(this._endpoint);

  @override
  ClientStreamingBidiStream<DataBlock> processDataBlocks() =>
      _endpoint
          .clientStreaming(
            serviceName: serviceName,
            methodName: StreamServiceContract.nameProcessDataBlocks,
          )
          .call<DataBlock>();

  @override
  ClientStreamingBidiStream<DataBlock> processDataBlocksNoResponse() =>
      _endpoint
          .clientStreaming(
            serviceName: serviceName,
            methodName: StreamServiceContract.nameProcessDataBlocksNoResponse,
          )
          .call<DataBlock>();
}
