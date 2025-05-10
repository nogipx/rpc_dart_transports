import 'package:rpc_dart/rpc_dart.dart';

import 'client_streaming_models.dart';

/// Контракт стриминг-сервиса
abstract final class StreamServiceContract extends RpcServiceContract {
  @override
  final String serviceName = 'StreamService';

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
  }

  // Абстрактный метод, который должен быть реализован
  Future<RpcClientStreamResult<DataBlock, DataBlockResult>> processDataBlocks(
    RpcClientStreamParams<DataBlock, DataBlockResult> params,
  );
}

/// Серверная реализация StreamService
final class ServerStreamService extends StreamServiceContract {
  @override
  Future<RpcClientStreamResult<DataBlock, DataBlockResult>> processDataBlocks(
    RpcClientStreamParams<DataBlock, DataBlockResult> params,
  ) async {
    print('Сервер: начата обработка блоков файла');
    print('  ID потока: ${params.streamId}');

    // Проверка валидности потока
    final typedStream = params.stream?.cast<DataBlock>();
    if (typedStream == null) {
      print('  Ошибка: поток данных отсутствует');
      throw RpcInvalidArgumentException(
        'Ошибка: невозможно обработать входящий поток данных',
        details: {'contract': serviceName, 'method': 'processDataBlocks'},
      );
    }

    // Счетчики для обработки файла
    int blockCount = 0; // Количество блоков
    int totalSize = 0; // Общий размер файла в байтах
    String? metadata; // Метаданные файла

    print('  Начинаем получение блоков файла...');

    try {
      // Получаем блоки данных из потока
      await for (final block in typedStream) {
        blockCount++;
        totalSize += block.data.length;

        // Сохраняем метаданные из первого блока (например, имя файла)
        if (metadata == null && block.metadata.isNotEmpty) {
          metadata = block.metadata;
        }

        print('  Получен блок #${block.index}: ${block.data.length} байт');

        // Имитация обработки больших блоков данных (проверка на вирусы, расчет хеша и т.д.)
        if (block.data.length > 1000) {
          print('  Обработка большого блока данных...');
          await Future.delayed(Duration(milliseconds: 50));
        }
      }

      print(
        'Сервер: завершена обработка $blockCount блоков, общий размер: $totalSize байт',
      );

      // Формируем отчет о загрузке файла
      final result = DataBlockResult(
        blockCount: blockCount,
        totalSize: totalSize,
        metadata: metadata ?? 'unknown',
        processingTime: DateTime.now().toIso8601String(),
      );

      print('Сервер: отправка результата обработки: $result');

      // Возвращаем результат обработки клиенту
      final response = RpcClientStreamResult<DataBlock, DataBlockResult>(
        response: Future.value(result),
      );

      return response;
    } catch (e, stack) {
      print('Произошла ошибка при обработке файла: $e');
      print('Стек вызовов: $stack');
      rethrow;
    }
  }
}

/// Клиентская реализация StreamService
final class ClientStreamService extends StreamServiceContract {
  final RpcEndpoint _endpoint;

  ClientStreamService(this._endpoint);

  @override
  Future<RpcClientStreamResult<DataBlock, DataBlockResult>> processDataBlocks(
    RpcClientStreamParams<DataBlock, DataBlockResult> params,
  ) async => _endpoint
      .clientStreaming(serviceName, StreamServiceContract.nameProcessDataBlocks)
      .openClientStream<DataBlock, DataBlockResult>(
        responseParser: DataBlockResult.fromJson,
        metadata: params.metadata,
        streamId: params.streamId,
      );
}
