import 'package:rpc_dart/rpc_dart.dart';

import 'client_streaming_models.dart';

/// Контракт демо-сервиса
abstract final class DemoServiceContract extends RpcServiceContract {
  @override
  final String serviceName = 'DemoService';

  static const nameAggregateNumbers = 'aggregateNumbers';
  static const nameProcessItems = 'processItems';

  @override
  void setup() {
    // Метод агрегации чисел (client streaming)
    addClientStreamingMethod<RpcInt, AggregationResult>(
      methodName: nameAggregateNumbers,
      handler: aggregateNumbers,
      argumentParser: RpcInt.fromJson,
      responseParser: AggregationResult.fromJson,
    );

    // Метод обработки сложных объектов (client streaming)
    addClientStreamingMethod<SerializableItem, ProcessingSummary>(
      methodName: nameProcessItems,
      handler: processItems,
      argumentParser: SerializableItem.fromJson,
      responseParser: ProcessingSummary.fromJson,
    );
  }

  // Абстрактные методы, которые должны быть реализованы
  Future<RpcClientStreamResult<RpcInt, AggregationResult>> aggregateNumbers(
    RpcClientStreamParams<RpcInt, AggregationResult> params,
  );

  Future<RpcClientStreamResult<SerializableItem, ProcessingSummary>> processItems(
    RpcClientStreamParams<SerializableItem, ProcessingSummary> params,
  );
}

/// Контракт стриминг-сервиса
abstract final class StreamServiceContract extends RpcServiceContract {
  @override
  final String serviceName = 'StreamService';

  static const nameProcessDataBlocks = 'processDataBlocks';
  static const nameValidateInput = 'validateInput';

  @override
  void setup() {
    // Метод обработки блоков данных (client streaming)
    addClientStreamingMethod<DataBlock, DataBlockResult>(
      methodName: nameProcessDataBlocks,
      handler: processDataBlocks,
      argumentParser: DataBlock.fromJson,
      responseParser: DataBlockResult.fromJson,
    );

    // Метод валидации входных данных (client streaming)
    addClientStreamingMethod<RpcString, ValidationResult>(
      methodName: nameValidateInput,
      handler: validateInput,
      argumentParser: RpcString.fromJson,
      responseParser: ValidationResult.fromJson,
    );
  }

  // Абстрактные методы, которые должны быть реализованы
  Future<RpcClientStreamResult<DataBlock, DataBlockResult>> processDataBlocks(
    RpcClientStreamParams<DataBlock, DataBlockResult> params,
  );

  Future<RpcClientStreamResult<RpcString, ValidationResult>> validateInput(
    RpcClientStreamParams<RpcString, ValidationResult> params,
  );
}

// -------------------------------------------------------------------------
// Серверные реализации контрактов
// -------------------------------------------------------------------------

/// Серверная реализация DemoService
final class ServerDemoService extends DemoServiceContract {
  @override
  Future<RpcClientStreamResult<RpcInt, AggregationResult>> aggregateNumbers(
    RpcClientStreamParams<RpcInt, AggregationResult> params,
  ) async {
    print('Сервер начал обработку потока чисел');

    // Преобразуем поток к нужному типу
    final typedStream = params.stream?.cast<RpcInt>();
    if (typedStream == null) {
      throw RpcInvalidArgumentException(
        'Сервер не может обработать входящий поток',
        details: {'contract': serviceName, 'method': 'aggregateNumbers'},
      );
    }

    int sum = 0;
    int count = 0;
    int min = 0;
    int max = 0;
    bool firstValue = true;

    await for (final number in typedStream) {
      final value = number.value;

      // Инициализируем min/max при первом значении
      if (firstValue) {
        min = value;
        max = value;
        firstValue = false;
      }

      count++;
      sum += value;
      min = value < min ? value : min;
      max = value > max ? value : max;

      print('  Получено число #$count: $value');
    }

    print('Сервер завершил обработку $count чисел');

    // Формируем ответ со статистикой
    return RpcClientStreamResult<RpcInt, AggregationResult>(
      response: Future.value(
        AggregationResult(
          count: count,
          sum: sum,
          average: count > 0 ? sum / count : 0,
          min: min,
          max: max,
        ),
      ),
    );
  }

  @override
  Future<RpcClientStreamResult<SerializableItem, ProcessingSummary>> processItems(
    RpcClientStreamParams<SerializableItem, ProcessingSummary> params,
  ) async {
    print('Сервер начал обработку потока объектов');

    // Преобразуем поток к нужному типу
    final typedStream = params.stream?.cast<SerializableItem>();
    if (typedStream == null) {
      throw RpcInvalidArgumentException(
        'Сервер не может обработать входящий поток',
        details: {'contract': serviceName, 'method': 'processItems'},
      );
    }

    final List<SerializableItem> items = [];
    int totalValue = 0;

    await for (final item in typedStream) {
      items.add(item);
      totalValue += item.value;
      print('  Получен объект: ${item.name} (${item.value})');
    }

    print('Сервер завершил обработку ${items.length} объектов');

    return RpcClientStreamResult<SerializableItem, ProcessingSummary>(
      response: Future.value(
        ProcessingSummary(
          processedCount: items.length,
          totalValue: totalValue,
          names: items.map((e) => e.name).toList(),
          timestamp: DateTime.now().toIso8601String(),
        ),
      ),
    );
  }
}

/// Серверная реализация StreamService
final class ServerStreamService extends StreamServiceContract {
  @override
  Future<RpcClientStreamResult<DataBlock, DataBlockResult>> processDataBlocks(
    RpcClientStreamParams<DataBlock, DataBlockResult> params,
  ) async {
    print('Сервер начал обработку блоков данных');

    // Преобразуем поток к нужному типу
    final typedStream = params.stream?.cast<DataBlock>();
    if (typedStream == null) {
      throw RpcInvalidArgumentException(
        'Сервер не может обработать входящий поток',
        details: {'contract': serviceName, 'method': 'processDataBlocks'},
      );
    }

    int blockCount = 0;
    int totalSize = 0;
    String? metadata;

    await for (final block in typedStream) {
      blockCount++;
      totalSize += block.data.length;

      // Сохраняем метаданные из первого блока
      if (metadata == null && block.metadata.isNotEmpty) {
        metadata = block.metadata;
      }

      print('  Получен блок #${block.index}: ${block.data.length} байт');

      // Имитация обработки больших блоков
      if (block.data.length > 1000) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    print('Сервер завершил обработку $blockCount блоков данных, всего: $totalSize байт');

    final response = RpcClientStreamResult<DataBlock, DataBlockResult>(
      response: Future.value(
        DataBlockResult(
          blockCount: blockCount,
          totalSize: totalSize,
          metadata: metadata ?? 'no-metadata',
          processingTime: DateTime.now().toIso8601String(),
        ),
      ),
    );

    return response;
  }

  @override
  Future<RpcClientStreamResult<RpcString, ValidationResult>> validateInput(
    RpcClientStreamParams<RpcString, ValidationResult> params,
  ) async {
    print('Сервер начал валидацию входных данных');
    final typedStream = params.stream?.cast<RpcString>();
    if (typedStream == null) {
      throw RpcInvalidArgumentException(
        'Сервер не может обработать входящий поток',
        details: {'contract': serviceName, 'method': 'validateInput'},
      );
    }

    final List<String> errors = [];
    int processed = 0;

    await for (final item in typedStream) {
      processed++;
      final value = item.value;
      print('  Проверяется элемент #$processed: $value');

      if (value.isEmpty) {
        errors.add('Элемент #$processed: Пустое значение');
      } else if (value == 'error') {
        // Демонстрация обработки ошибок: выбрасываем исключение
        throw Exception('Обнаружено запрещенное значение');
      } else if (value.length < 3) {
        errors.add('Элемент #$processed: Значение слишком короткое');
      }
    }

    print('Сервер завершил валидацию: $processed элементов, ${errors.length} ошибок');

    final response = RpcClientStreamResult<RpcString, ValidationResult>(
      response: Future.value(
        ValidationResult(valid: errors.isEmpty, processedCount: processed, errors: errors),
      ),
    );

    return response;
  }
}

// -------------------------------------------------------------------------
// Клиентские реализации контрактов
// -------------------------------------------------------------------------

/// Клиентская реализация DemoService
final class ClientDemoService extends DemoServiceContract {
  final RpcEndpoint _endpoint;

  ClientDemoService(this._endpoint);

  @override
  Future<RpcClientStreamResult<RpcInt, AggregationResult>> aggregateNumbers(
    RpcClientStreamParams<RpcInt, AggregationResult> params,
  ) async => _endpoint
      .clientStreaming(serviceName, DemoServiceContract.nameAggregateNumbers)
      .openClientStream<RpcInt, AggregationResult>(
        responseParser: AggregationResult.fromJson,
        metadata: params.metadata,
        streamId: params.streamId,
      );

  @override
  Future<RpcClientStreamResult<SerializableItem, ProcessingSummary>> processItems(
    RpcClientStreamParams<SerializableItem, ProcessingSummary> params,
  ) async => _endpoint
      .clientStreaming(serviceName, DemoServiceContract.nameProcessItems)
      .openClientStream<SerializableItem, ProcessingSummary>(
        responseParser: ProcessingSummary.fromJson,
        metadata: params.metadata,
        streamId: params.streamId,
      );
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

  @override
  Future<RpcClientStreamResult<RpcString, ValidationResult>> validateInput(
    RpcClientStreamParams<RpcString, ValidationResult> params,
  ) async => _endpoint
      .clientStreaming(serviceName, StreamServiceContract.nameValidateInput)
      .openClientStream<RpcString, ValidationResult>(
        responseParser: ValidationResult.fromJson,
        metadata: params.metadata,
        streamId: params.streamId,
      );
}
