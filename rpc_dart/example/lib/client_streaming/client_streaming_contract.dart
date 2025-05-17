import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

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
    // Метод обработки блоков данных (client streaming)
    addClientStreamingMethod<DataBlock, RpcNull>(
      methodName: nameProcessDataBlocks,
      handler: processDataBlocks,
      argumentParser: DataBlock.fromJson,
      responseParser: (json) => RpcNull(),
    );

    // Метод обработки блоков данных без ожидания ответа
    addClientStreamingMethod<DataBlock, RpcNull>(
      methodName: nameProcessDataBlocksNoResponse,
      handler: processDataBlocksNoResponse,
      argumentParser: DataBlock.fromJson,
      responseParser: (json) => RpcNull(),
    );

    // Метод обработки блоков данных с возвратом результата после завершения обработки
    addClientStreamingMethod<DataBlock, DataBlockResult>(
      methodName: nameProcessDataBlocksWithResponse,
      handler: processDataBlocksWithResponse,
      argumentParser: DataBlock.fromJson,
      responseParser: DataBlockResult.fromJson,
    );

    super.setup();
  }

  // Абстрактный метод, который должен быть реализован
  ClientStreamingBidiStream<DataBlock, RpcNull> processDataBlocks();

  // Абстрактный метод без ожидания ответа
  ClientStreamingBidiStream<DataBlock, RpcNull> processDataBlocksNoResponse();

  // Абстрактный метод с возвратом результата после обработки всех блоков
  ClientStreamingBidiStream<DataBlock, DataBlockResult>
  processDataBlocksWithResponse();
}

/// Серверная реализация StreamService
final class ServerStreamService extends StreamServiceContract {
  RpcLogger get _logger => RpcLogger('ServerStreamService');

  @override
  ClientStreamingBidiStream<DataBlock, RpcNull> processDataBlocks() {
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

    return ClientStreamingBidiStream<DataBlock, RpcNull>(bidiStream);
  }

  @override
  ClientStreamingBidiStream<DataBlock, RpcNull> processDataBlocksNoResponse() {
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
    return ClientStreamingBidiStream<DataBlock, RpcNull>(bidiStream);
  }

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

              yield DataBlockResult(
                blockCount: blockCount,
                totalSize: totalSize,
                metadata: metadata,
                processingTime:
                    '${DateTime.now().difference(startTime).inMilliseconds} мс',
              );
            }

            _logger.debug(
              'Завершена обработка $blockCount блоков, общий размер: $totalSize байт',
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
  ClientStreamingBidiStream<DataBlock, RpcNull> processDataBlocks() =>
      _endpoint
          .clientStreaming(
            serviceName: serviceName,
            methodName: StreamServiceContract.nameProcessDataBlocks,
          )
          .call<DataBlock, RpcNull>();

  @override
  ClientStreamingBidiStream<DataBlock, RpcNull> processDataBlocksNoResponse() =>
      _endpoint
          .clientStreaming(
            serviceName: serviceName,
            methodName: StreamServiceContract.nameProcessDataBlocksNoResponse,
          )
          .call<DataBlock, RpcNull>(noResponse: true);

  @override
  ClientStreamingBidiStream<DataBlock, DataBlockResult>
  processDataBlocksWithResponse() => _endpoint
      .clientStreaming(
        serviceName: serviceName,
        methodName: StreamServiceContract.nameProcessDataBlocksWithResponse,
      )
      .call<DataBlock, DataBlockResult>(
        responseParser:
            (dynamic data) =>
                data is Map<String, dynamic>
                    ? DataBlockResult.fromJson(data)
                    : data as DataBlockResult,
      );
}
