import 'package:rpc_dart/diagnostics.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

Future<RpcDiagnosticClient> factoryDiagnosticClient({
  required Uri diagnosticUrl,
  required RpcClientIdentity clientIdentity,
}) async {
  final transport = ClientWebSocketTransport.fromUrl(
    id: 'diagnostic_connection_${clientIdentity.clientId}',
    url: diagnosticUrl.toString(),
    autoConnect: false, // Изменяем на false, чтобы контролировать подключение
  );

  // Создаем и настраиваем RPC эндпоинт для диагностики
  final endpoint = RpcEndpoint(
    transport: transport,
    debugLabel: 'diagnostic_client_${clientIdentity.clientId}',
  );

  // Явно подключаем транспорт и ждем успешного подключения
  await transport.connect();

  // Ждем немного для гарантированной регистрации всех контрактов
  await Future.delayed(Duration(milliseconds: 100));

  final client = RpcDiagnosticClient(
    endpoint: endpoint,
    clientIdentity: clientIdentity,
    options: RpcDiagnosticOptions(
      enabled: true,
      flushIntervalMs: 2000, // 2 секунды
      samplingRate: 1.0, // Отправляем все метрики
    ),
  );

  return client;
}

/// Контракт для демонстрационного сервиса
abstract class DemoServiceContract extends OldRpcServiceContract {
  DemoServiceContract() : super('demo_service');

  @override
  void setup() {
    // Регистрируем унарный метод echo
    addUnaryRequestMethod<RpcString, RpcString>(
      methodName: 'echo',
      handler: echo,
      argumentParser: RpcString.fromJson,
      responseParser: RpcString.fromJson,
    );

    // Регистрируем метод с серверным стримингом
    addServerStreamingMethod<RpcInt, RpcString>(
      methodName: 'generateNumbers',
      handler: generateNumbers,
      argumentParser: RpcInt.fromJson,
      responseParser: RpcString.fromJson,
    );

    // Регистрируем метод с клиентским стримингом
    addClientStreamingMethod<RpcString, RpcInt>(
      methodName: 'countWords',
      handler: countWords,
      argumentParser: RpcString.fromJson,
      responseParser: RpcInt.fromJson,
    );

    // Регистрируем двунаправленный метод
    addBidirectionalStreamingMethod<RpcString, RpcString>(
      methodName: 'chat',
      handler: chat,
      argumentParser: RpcString.fromJson,
      responseParser: RpcString.fromJson,
    );

    super.setup();
  }

  // Унарный метод - эхо
  Future<RpcString> echo(RpcString request);

  ClientStreamingBidiStream<RpcString, RpcInt> countWords();

  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt _);

  BidiStream<RpcString, RpcString> chat();
}

final class DemoClient extends DemoServiceContract {
  final RpcEndpoint _endpoint;

  DemoClient(this._endpoint);

  @override
  BidiStream<RpcString, RpcString> chat() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: 'demo_service',
          methodName: 'chat',
        )
        .call(
          responseParser: RpcString.fromJson,
        );
  }

  @override
  ClientStreamingBidiStream<RpcString, RpcInt> countWords() {
    return _endpoint
        .clientStreaming(
          serviceName: 'demo_service',
          methodName: 'countWords',
        )
        .call(
          responseParser: RpcInt.fromJson,
        );
  }

  @override
  Future<RpcString> echo(RpcString request) {
    return _endpoint
        .unaryRequest(
          serviceName: 'demo_service',
          methodName: 'echo',
        )
        .call(
          request: request,
          responseParser: RpcString.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt p1) {
    return _endpoint
        .serverStreaming(
          serviceName: 'demo_service',
          methodName: 'generateNumbers',
        )
        .call(
          request: p1,
          responseParser: RpcString.fromJson,
        );
  }
}
