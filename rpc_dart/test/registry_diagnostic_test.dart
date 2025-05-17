// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';
import 'fixtures/test_contract.dart';
import 'fixtures/test_factory.dart';
import 'dart:async';

// Сообщения для диагностики
class DiagnosticRequest implements IRpcSerializableMessage {
  final String metricName;
  final Map<String, dynamic> parameters;

  DiagnosticRequest(this.metricName, {this.parameters = const {}});

  @override
  Map<String, dynamic> toJson() => {
        'metricName': metricName,
        'parameters': parameters,
      };

  factory DiagnosticRequest.fromJson(Map<String, dynamic> json) {
    return DiagnosticRequest(
      json['metricName'] as String? ?? '',
      parameters: (json['parameters'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class DiagnosticResponse implements IRpcSerializableMessage {
  final bool success;
  final Map<String, dynamic> metrics;
  final String error;

  DiagnosticResponse({
    required this.success,
    this.metrics = const {},
    this.error = '',
  });

  @override
  Map<String, dynamic> toJson() => {
        'success': success,
        'metrics': metrics,
        'error': error,
      };

  factory DiagnosticResponse.fromJson(Map<String, dynamic> json) {
    return DiagnosticResponse(
      success: json['success'] as bool? ?? false,
      metrics: (json['metrics'] as Map<String, dynamic>?) ?? {},
      error: json['error'] as String? ?? '',
    );
  }
}

/// Контракт для тестирования диагностических методов
abstract class DiagnosticServiceContract extends RpcServiceContract {
  // Константы для имен методов
  static const methodGetMetric = 'getMetric';
  static const methodGetAllMetrics = 'getAllMetrics';
  static const methodStreamMetrics = 'streamMetrics';

  DiagnosticServiceContract() : super('diagnostic_service');

  @override
  void setup() {
    // Унарный метод для получения конкретной метрики
    addUnaryRequestMethod<DiagnosticRequest, DiagnosticResponse>(
      methodName: methodGetMetric,
      handler: getMetric,
      argumentParser: DiagnosticRequest.fromJson,
      responseParser: DiagnosticResponse.fromJson,
    );

    // Унарный метод для получения всех метрик
    addUnaryRequestMethod<DiagnosticRequest, DiagnosticResponse>(
      methodName: methodGetAllMetrics,
      handler: getAllMetrics,
      argumentParser: DiagnosticRequest.fromJson,
      responseParser: DiagnosticResponse.fromJson,
    );

    // Серверный стриминг для отслеживания метрик в реальном времени
    addServerStreamingMethod<DiagnosticRequest, DiagnosticResponse>(
      methodName: methodStreamMetrics,
      handler: streamMetricsHandler,
      argumentParser: DiagnosticRequest.fromJson,
      responseParser: DiagnosticResponse.fromJson,
    );

    super.setup();
  }

  /// Метод получения конкретной метрики
  Future<DiagnosticResponse> getMetric(DiagnosticRequest request);

  /// Метод получения всех метрик
  Future<DiagnosticResponse> getAllMetrics(DiagnosticRequest request);

  /// Метод для стриминга метрик в реальном времени - внутренняя реализация
  Stream<DiagnosticResponse> streamMetrics(DiagnosticRequest request);

  /// Обертка для стриминга метрик в формате ServerStreamingBidiStream
  ServerStreamingBidiStream<DiagnosticRequest, DiagnosticResponse>
      streamMetricsHandler(DiagnosticRequest request) {
    // Используем BidiStreamGenerator для преобразования потока в BidiStream
    return BidiStreamGenerator<DiagnosticRequest, DiagnosticResponse>(
      (_) => streamMetrics(request),
    ).createServerStreaming();
  }
}

/// Серверная реализация диагностического контракта
class DiagnosticServiceServer extends DiagnosticServiceContract {
  // Демо метрики
  final Map<String, dynamic> _metrics = {
    'cpu': {'usage': 0.42, 'temperature': 65},
    'memory': {'total': 16384, 'used': 8192, 'free': 8192},
    'network': {'rx': 1024, 'tx': 512, 'connections': 5},
  };

  @override
  Future<DiagnosticResponse> getMetric(DiagnosticRequest request) async {
    if (_metrics.containsKey(request.metricName)) {
      return DiagnosticResponse(
        success: true,
        metrics: {request.metricName: _metrics[request.metricName]},
      );
    } else {
      return DiagnosticResponse(
        success: false,
        error: 'Метрика ${request.metricName} не найдена',
      );
    }
  }

  @override
  Future<DiagnosticResponse> getAllMetrics(DiagnosticRequest request) async {
    return DiagnosticResponse(
      success: true,
      metrics: _metrics,
    );
  }

  @override
  Stream<DiagnosticResponse> streamMetrics(DiagnosticRequest request) async* {
    final metricName = request.metricName.isEmpty ? null : request.metricName;
    final interval = request.parameters['interval'] as int? ?? 1000;

    // Эмуляция изменения метрик в реальном времени
    for (var i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: interval));

      if (metricName != null && !_metrics.containsKey(metricName)) {
        yield DiagnosticResponse(
          success: false,
          error: 'Метрика $metricName не найдена',
        );
        break;
      }

      // Обновляем значения
      _updateMetrics();

      if (metricName != null) {
        yield DiagnosticResponse(
          success: true,
          metrics: {metricName: _metrics[metricName]},
        );
      } else {
        yield DiagnosticResponse(
          success: true,
          metrics: _metrics,
        );
      }
    }
  }

  // Обновление метрик с небольшими случайными изменениями
  void _updateMetrics() {
    double random(double max, double min) =>
        min + (max - min) * (DateTime.now().millisecondsSinceEpoch % 100) / 100;

    (_metrics['cpu'] as Map<String, dynamic>)['usage'] =
        double.parse((random(0.7, 0.1)).toStringAsFixed(2));
    (_metrics['cpu'] as Map<String, dynamic>)['temperature'] =
        (55 + (random(15, 0))).toInt();

    (_metrics['memory'] as Map<String, dynamic>)['used'] =
        (4096 + (random(12288, 0))).toInt();
    (_metrics['memory'] as Map<String, dynamic>)['free'] =
        16384 - (_metrics['memory'] as Map<String, dynamic>)['used'] as int;

    (_metrics['network'] as Map<String, dynamic>)['rx'] =
        (512 + (random(2048, 0))).toInt();
    (_metrics['network'] as Map<String, dynamic>)['tx'] =
        (256 + (random(1024, 0))).toInt();
    (_metrics['network'] as Map<String, dynamic>)['connections'] =
        (1 + (random(10, 0))).toInt();
  }
}

/// Клиентская реализация диагностического контракта
class DiagnosticServiceClient extends DiagnosticServiceContract {
  final RpcEndpoint _endpoint;

  DiagnosticServiceClient(this._endpoint);

  @override
  Future<DiagnosticResponse> getMetric(DiagnosticRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: DiagnosticServiceContract.methodGetMetric,
        )
        .call(
          request: request,
          responseParser: DiagnosticResponse.fromJson,
        );
  }

  @override
  Future<DiagnosticResponse> getAllMetrics(DiagnosticRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: DiagnosticServiceContract.methodGetAllMetrics,
        )
        .call(
          request: request,
          responseParser: DiagnosticResponse.fromJson,
        );
  }

  @override
  Stream<DiagnosticResponse> streamMetrics(DiagnosticRequest request) {
    return _endpoint
        .serverStreaming(
          serviceName: serviceName,
          methodName: DiagnosticServiceContract.methodStreamMetrics,
        )
        .call(
          request: request,
          responseParser: DiagnosticResponse.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<DiagnosticRequest, DiagnosticResponse>
      streamMetricsHandler(DiagnosticRequest request) {
    throw UnimplementedError('Клиент не должен реализовывать этот метод');
  }
}

void main() {
  group('Тестирование диагностических методов с явным registry', () {
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late DiagnosticServiceClient diagnosticClient;
    late IRpcMethodRegistry serverRegistry;

    setUp(() {
      // Используем нашу новую фабрику для создания тестового окружения
      final testEnv = TestFactory.setupTestEnvironment(
        contractFactories: [
          (
            type: DiagnosticServiceContract,
            clientFactory: (endpoint) => DiagnosticServiceClient(endpoint),
            serverFactory: () => DiagnosticServiceServer(),
          ),
        ],
      );

      clientEndpoint = testEnv.clientEndpoint;
      serverEndpoint = testEnv.serverEndpoint;
      serverRegistry = testEnv.serverRegistry;

      // Получаем реализации из мапы контрактов
      diagnosticClient = testEnv.clientContracts
          .get<DiagnosticServiceContract>() as DiagnosticServiceClient;

      // Выводим отладочную информацию о registry
      TestFactory.debugPrintRegisteredContracts(serverRegistry, 'Сервер');
      TestFactory.debugPrintRegisteredMethods(serverRegistry, 'Сервер');
    });

    tearDown(() async {
      await TestFixtureUtils.tearDown(clientEndpoint, serverEndpoint);
    });

    test('получение_существующей_метрики', () async {
      final request = DiagnosticRequest('cpu');
      final response = await diagnosticClient.getMetric(request);

      expect(response.success, isTrue);
      expect(response.metrics, contains('cpu'));
      expect(response.metrics['cpu'], isA<Map>());
      expect(response.metrics['cpu']['usage'], isA<double>());
      expect(response.metrics['cpu']['temperature'], isA<int>());
    });

    test('получение_несуществующей_метрики', () async {
      final request = DiagnosticRequest('несуществующая_метрика');
      final response = await diagnosticClient.getMetric(request);

      expect(response.success, isFalse);
      expect(response.error, contains('не найдена'));
    });

    test('получение_всех_метрик', () async {
      final request = DiagnosticRequest('');
      final response = await diagnosticClient.getAllMetrics(request);

      expect(response.success, isTrue);
      expect(response.metrics.keys, containsAll(['cpu', 'memory', 'network']));
    });

    test('стриминг_метрик', () async {
      final request = DiagnosticRequest('cpu', parameters: {'interval': 100});
      final stream = diagnosticClient.streamMetrics(request);

      // Создаем Future.value() чтобы собрать все сообщения из потока
      final responses = await stream.toList();

      // Проверяем, что мы получили ровно 5 ответов (это вшито в реализацию)
      expect(responses.length, equals(5));

      // Проверяем, что все ответы успешны
      for (final response in responses) {
        expect(response.success, isTrue);
        expect(response.metrics, contains('cpu'));
        expect(response.metrics['cpu']['usage'], isA<double>());
        expect(response.metrics['cpu']['temperature'], isA<int>());
      }

      // Проверяем, что метрики действительно меняются между ответами
      final firstUsage = responses.first.metrics['cpu']['usage'];
      final lastUsage = responses.last.metrics['cpu']['usage'];
      expect(firstUsage, isNot(equals(lastUsage)));
    });

    test('стриминг_несуществующей_метрики', () async {
      final request =
          DiagnosticRequest('несуществующая', parameters: {'interval': 100});
      final stream = diagnosticClient.streamMetrics(request);

      // Получаем первый ответ из потока
      final response = await stream.first;

      // Проверяем, что получен ответ с ошибкой
      expect(response.success, isFalse);
      expect(response.error, contains('не найдена'));
    });

    test('сочетание_разных_видов_запросов', () async {
      // 1. Сначала запускаем стриминг в фоне
      final streamRequest =
          DiagnosticRequest('memory', parameters: {'interval': 200});
      final streamFuture =
          diagnosticClient.streamMetrics(streamRequest).toList();

      // 2. Делаем унарный запрос во время работы стрима
      await Future.delayed(Duration(milliseconds: 100));
      final unaryRequest = DiagnosticRequest('network');
      final unaryResponse = await diagnosticClient.getMetric(unaryRequest);

      // 3. Ждем завершения стрима
      final streamResponses = await streamFuture;

      // Проверяем результаты
      expect(unaryResponse.success, isTrue);
      expect(unaryResponse.metrics, contains('network'));

      expect(streamResponses.length, equals(5));
      for (final response in streamResponses) {
        expect(response.success, isTrue);
        expect(response.metrics, contains('memory'));
      }
    });
  });
}
