import 'dart:async';
import 'dart:convert';
import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования встроенных middleware для обработки запросов и ответов
void main() async {
  print('=== Пример использования встроенных middleware ===\n');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты соединены');

  // Создаем эндпоинты с метками для отладки
  final client = RpcEndpoint(
    transport: clientTransport,
    serializer: JsonSerializer(),
    debugLabel: 'client',
  );
  final server = RpcEndpoint(
    transport: serverTransport,
    serializer: JsonSerializer(),
    debugLabel: 'server',
  );
  print('Эндпоинты созданы');

  // Регистрируем контракты сервисов
  server.registerServiceContract(SimpleRpcServiceContract('GreetingService'));
  server.registerServiceContract(SimpleRpcServiceContract('ErrorService'));
  server.registerServiceContract(SimpleRpcServiceContract('DataService'));
  client.registerServiceContract(SimpleRpcServiceContract('GreetingService'));
  client.registerServiceContract(SimpleRpcServiceContract('ErrorService'));
  client.registerServiceContract(SimpleRpcServiceContract('DataService'));

  // Регистрируем методы на сервере
  registerServerMethods(server);
  print('Методы зарегистрированы');

  try {
    // Демонстрация стандартного запроса без middleware
    await demonstrateWithoutMiddleware(client);

    // Добавление middleware на клиент и сервер
    print('\n--- Добавляем встроенные middleware ---');
    setupMiddlewares(client, server);

    // Демонстрация запроса с обработкой через middleware
    await demonstrateWithMiddleware(client);

    // Демонстрация обработки ошибок через middleware
    await demonstrateErrorHandling(client);

    // Демонстрация стриминга с middleware
    await demonstrateStreamingWithMiddleware(client);
  } catch (e, stackTrace) {
    print('Произошла ошибка: $e');
    print('Трассировка стека: $stackTrace');
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    print('\nЭндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Регистрация методов на сервере
void registerServerMethods(RpcEndpoint server) {
  // Простой унарный метод
  server
      .unary('GreetingService', 'greet')
      .register<GreetingRequest, GreetingResponse>(
        handler: (request) async {
          print('Сервер: обработка приветствия для ${request.name}');
          return GreetingResponse(
            message: 'Привет, ${request.name}!',
            timestamp: DateTime.now().toIso8601String(),
          );
        },
        requestParser: GreetingRequest.fromJson,
        responseParser: GreetingResponse.fromJson,
      );

  // Метод с ошибкой
  server
      .unary('ErrorService', 'checkAccess')
      .register<AccessRequest, AccessResponse>(
        handler: (request) async {
          print('Сервер: проверка доступа для ${request.userId}');

          if (request.userId.isEmpty) {
            throw Exception('UserId не может быть пустым');
          }

          if (request.userId == 'blocked') {
            // Выбрасываем RpcException вместо обычного Exception
            throw RpcException(
              code: 'PERMISSION_DENIED',
              message: 'Пользователь заблокирован',
              details: {
                'user_id': request.userId,
                'blocked_at': DateTime.now().toIso8601String(),
              },
            );
          }

          return AccessResponse(
            granted: true,
            permissions: ['read', 'write'],
          );
        },
        requestParser: AccessRequest.fromJson,
        responseParser: AccessResponse.fromJson,
      );

  // Метод стриминга
  server
      .serverStreaming('DataService', 'getData')
      .register<DataRequest, DataItem>(
        handler: (request) async* {
          print('Сервер: запрос данных, количество: ${request.count}');

          for (int i = 1; i <= request.count; i++) {
            await Future.delayed(Duration(milliseconds: 300));
            yield DataItem(
              id: 'item-$i',
              name: 'Тестовый элемент $i',
              value: i * 10,
            );
          }
        },
        requestParser: DataRequest.fromJson,
        responseParser: DataItem.fromJson,
      );
}

/// Настройка всех необходимых middleware для примера
void setupMiddlewares(RpcEndpoint client, RpcEndpoint server) {
  // 1. Настройка клиентских middleware

  // Метаданные для авторизации
  final authMetadata = MetadataMiddleware(
    headerMetadata: {
      'auth_token': 'user-123-token',
      'client_version': '1.0.0',
      'device_type': 'mobile',
    },
  );
  print('Клиент: добавлен MetadataMiddleware для аутентификации');
  client.addMiddleware(authMetadata);

  // Добавляем замер времени выполнения запросов
  client.addMiddleware(TimingMiddleware(
    onTiming: (message, duration) {
      print('Клиент: $message за ${duration.inMilliseconds}ms');
    },
  ));
  print('Клиент: добавлен TimingMiddleware для замера времени');

  // Добавляем логирование для клиента
  client.addMiddleware(LoggingMiddleware(id: 'client'));
  print('Клиент: добавлен LoggingMiddleware для логирования');

  // 2. Настройка серверных middleware

  // Метаданные для ответов сервера
  final serverMetadata = MetadataMiddleware(
    trailerMetadata: {
      'server_version': '1.0.0',
      'processed_at': DateTime.now().toIso8601String(),
    },
  );
  print('Сервер: добавлен MetadataMiddleware для ответов');
  server.addMiddleware(serverMetadata);

  // Расширенное логирование и замер времени для сервера
  server.addMiddleware(DebugWithTimingMiddleware(id: 'server'));
  print(
      'Сервер: добавлен DebugWithTimingMiddleware для отладки и замера времени');

  // Обработчик для обогащения ответов
  final responseEnricher = RpcMiddlewareWrapper(
    debugLabel: 'ResponseEnricher',
    onResponseHandler: (serviceName, methodName, response, context, direction) {
      if (direction == RpcDataDirection.toRemote) {
        if (response is GreetingResponse) {
          // Обогащаем ответ
          return GreetingResponse(
            message: '${response.message} (обогащено middleware)',
            timestamp: response.timestamp,
            extra: {'processed_by': 'ResponseEnricher'},
          );
        }
      }
      return response;
    },
    onStreamDataHandler: (serviceName, methodName, data, streamId, direction) {
      if (direction == RpcDataDirection.toRemote && data is DataItem) {
        // Обогащаем данные стрима
        return DataItem(
          id: data.id,
          name: '${data.name} (обработано)',
          value: data.value * 2, // Удваиваем значение
        );
      }
      return data;
    },
  );
  print('Сервер: добавлен обработчик для обогащения ответов');
  server.addMiddleware(responseEnricher);
}

/// Демонстрация запроса без middleware
Future<void> demonstrateWithoutMiddleware(RpcEndpoint client) async {
  print('\n--- Запрос без middleware ---');

  final request = GreetingRequest(name: 'Гость');

  final response = await client
      .unary('GreetingService', 'greet')
      .call<GreetingRequest, GreetingResponse>(
        request: request,
        responseParser: GreetingResponse.fromJson,
      );

  print('Получен ответ: ${response.message}');
}

/// Демонстрация запроса с middleware
Future<void> demonstrateWithMiddleware(RpcEndpoint client) async {
  print('\n--- Запрос с middleware ---');

  final request = GreetingRequest(name: 'Пользователь');

  // Дополнительные метаданные запроса
  final metadata = {
    'client_id': 'demo-app',
    'device': 'testing',
    'timestamp': DateTime.now().toIso8601String(),
  };

  print('Отправляем запрос с метаданными: ${jsonEncode(metadata)}');

  final response = await client
      .unary('GreetingService', 'greet')
      .call<GreetingRequest, GreetingResponse>(
        request: request,
        metadata: metadata, // Передаем заголовочные метаданные
        responseParser: GreetingResponse.fromJson,
      );

  print('Получен обогащенный ответ: ${response.message}');
  if (response.extra != null) {
    final extra = response.extra as Map<String, dynamic>;
    print('Дополнительные данные: $extra');
  }
}

/// Демонстрация обработки ошибок через middleware
Future<void> demonstrateErrorHandling(RpcEndpoint client) async {
  print('\n--- Обработка ошибок через middleware ---');

  // 1. Нормальный запрос
  try {
    print('Отправка корректного запроса на проверку доступа:');

    final validRequest = AccessRequest(userId: 'user123');

    final response = await client
        .unary('ErrorService', 'checkAccess')
        .call<AccessRequest, AccessResponse>(
          request: validRequest,
          metadata: {'action': 'valid_access_check'}, // Метаданные
          responseParser: AccessResponse.fromJson,
        );

    print('Доступ предоставлен: ${response.granted}');
    print('Разрешения: ${response.permissions.join(", ")}');
  } catch (e) {
    print('Не должно было произойти ошибки: $e');
  }

  // 2. Запрос с ошибкой
  try {
    print('\nОтправка запроса с заблокированным пользователем:');

    final blockedRequest = AccessRequest(userId: 'blocked');

    await client
        .unary('ErrorService', 'checkAccess')
        .call<AccessRequest, AccessResponse>(
          request: blockedRequest,
          responseParser: AccessResponse.fromJson,
        );

    print('Этот код не должен выполниться');
  } catch (e) {
    if (e is RpcException) {
      print('Получено исключение RpcException:');
      print('  Код: ${e.code}');
      print('  Сообщение: ${e.message}');
      if (e.details != null) {
        print('  Детали: ${jsonEncode(e.details)}');
      }
    } else {
      print('Получено исключение: $e');
    }
  }
}

/// Демонстрация стриминга с middleware
Future<void> demonstrateStreamingWithMiddleware(RpcEndpoint client) async {
  print('\n--- Стриминг с middleware ---');

  final request = DataRequest(category: 'demo', count: 3);

  print('Запрашиваем поток данных:');

  final dataStream = client
      .serverStreaming('DataService', 'getData')
      .openStream<DataRequest, DataItem>(
        request: request,
        responseParser: DataItem.fromJson,
      );

  await for (final item in dataStream) {
    print('Получен элемент:');
    print('  ID: ${item.id}');
    print('  Имя: ${item.name}');
    print('  Значение: ${item.value}');
  }

  print('Поток данных завершен');
}

/// Класс запроса приветствия
class GreetingRequest implements IRpcSerializableMessage {
  final String name;

  GreetingRequest({required this.name});

  @override
  Map<String, dynamic> toJson() => {'name': name};

  static GreetingRequest fromJson(Map<String, dynamic> json) {
    return GreetingRequest(name: json['name'] as String);
  }
}

/// Класс ответа с приветствием
class GreetingResponse implements IRpcSerializableMessage {
  final String message;
  final String timestamp;
  final Map<String, dynamic>? extra;

  GreetingResponse({
    required this.message,
    required this.timestamp,
    this.extra,
  });

  @override
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'message': message,
      'timestamp': timestamp,
    };

    if (extra != null) {
      result['extra'] = extra;
    }

    return result;
  }

  static GreetingResponse fromJson(Map<String, dynamic> json) {
    return GreetingResponse(
      message: json['message'] as String,
      timestamp: json['timestamp'] as String,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }
}

/// Класс запроса доступа
class AccessRequest implements IRpcSerializableMessage {
  final String userId;

  AccessRequest({required this.userId});

  @override
  Map<String, dynamic> toJson() => {'userId': userId};

  static AccessRequest fromJson(Map<String, dynamic> json) {
    return AccessRequest(userId: json['userId'] as String);
  }
}

/// Класс ответа на запрос доступа
class AccessResponse implements IRpcSerializableMessage {
  final bool granted;
  final List<String> permissions;

  AccessResponse({
    required this.granted,
    required this.permissions,
  });

  @override
  Map<String, dynamic> toJson() => {
        'granted': granted,
        'permissions': permissions,
      };

  static AccessResponse fromJson(Map<String, dynamic> json) {
    return AccessResponse(
      granted: json['granted'] as bool,
      permissions:
          (json['permissions'] as List).map((e) => e as String).toList(),
    );
  }
}

/// Класс запроса данных
class DataRequest implements IRpcSerializableMessage {
  final String category;
  final int count;

  DataRequest({
    required this.category,
    required this.count,
  });

  @override
  Map<String, dynamic> toJson() => {
        'category': category,
        'count': count,
      };

  static DataRequest fromJson(Map<String, dynamic> json) {
    return DataRequest(
      category: json['category'] as String,
      count: json['count'] as int,
    );
  }
}

/// Класс элемента данных
class DataItem implements IRpcSerializableMessage {
  final String id;
  final String name;
  final int value;

  DataItem({
    required this.id,
    required this.name,
    required this.value,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
      };

  static DataItem fromJson(Map<String, dynamic> json) {
    return DataItem(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'] as int,
    );
  }
}

/// Класс исключения RPC
class RpcException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  RpcException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'RpcException[$code]: $message';
}
