import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Тестовые модели сообщений
class UserRequest implements IRpcSerializableMessage {
  final String username;
  final int age;

  UserRequest(this.username, this.age);

  @override
  Map<String, dynamic> toJson() => {
        'username': username,
        'age': age,
      };

  static UserRequest fromJson(Map<String, dynamic> json) {
    return UserRequest(
      json['username'] as String,
      json['age'] as int,
    );
  }
}

class UserResponse implements IRpcSerializableMessage {
  final String id;
  final String name;
  final bool isActive;

  UserResponse(this.id, this.name, this.isActive);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isActive': isActive,
      };

  static UserResponse fromJson(Map<String, dynamic> json) {
    return UserResponse(
      json['id'] as String,
      json['name'] as String,
      json['isActive'] as bool,
    );
  }
}

class NotificationMessage implements IRpcSerializableMessage {
  final String type;
  final String message;

  NotificationMessage(this.type, this.message);

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message,
      };

  static NotificationMessage fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      json['type'] as String,
      json['message'] as String,
    );
  }
}

// Контракт сервиса пользователей
abstract base class UserServiceContract extends RpcServiceContract {
  UserServiceContract() : super('UserService');

  RpcEndpoint? get client;

  // Константы для имен методов (для типобезопасности)
  static const String registerUserMethod = 'registerUser';
  static const String subscribeToNotificationsMethod =
      'subscribeToNotifications';

  @override
  void setup() {
    print('Setting up UserServiceContract');
    print('Service name: $serviceName');
    // Регистрация пользователя (унарный метод)
    addUnaryRequestMethod<UserRequest, UserResponse>(
      methodName: registerUserMethod,
      handler: registerUser,
      argumentParser: UserRequest.fromJson,
      responseParser: UserResponse.fromJson,
    );

    // Получение уведомлений (стрим)
    print('Adding server streaming method: $subscribeToNotificationsMethod');
    addServerStreamingMethod<UserRequest, NotificationMessage>(
      methodName: subscribeToNotificationsMethod,
      handler: subscribeToNotifications,
      argumentParser: UserRequest.fromJson,
      responseParser: NotificationMessage.fromJson,
    );
    print('Method subscribeToNotifications registered in contract');
    super.setup();
  }

  // Методы контракта
  Future<UserResponse> registerUser(UserRequest request);
  ServerStreamingBidiStream<UserRequest, NotificationMessage>
      subscribeToNotifications(UserRequest request);
}

// Серверная реализация
base class ServerUserService extends UserServiceContract {
  final Map<String, UserResponse> _users = {};

  @override
  RpcEndpoint? get client => null;

  @override
  Future<UserResponse> registerUser(UserRequest request) async {
    print('ServerUserService.registerUser called with ${request.username}');
    // Простая проверка валидности
    if (request.username.isEmpty) {
      throw ArgumentError('Username не может быть пустым');
    }

    if (request.age < 18) {
      throw ArgumentError('Возраст должен быть не менее 18 лет');
    }

    // Создаем пользователя
    final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final user = UserResponse(id, request.username, true);

    // Сохраняем
    _users[id] = user;

    return user;
  }

  @override
  ServerStreamingBidiStream<UserRequest, NotificationMessage>
      subscribeToNotifications(UserRequest request) {
    print(
        'ServerUserService.subscribeToNotifications called with ${request.username}');
    return BidiStreamGenerator<UserRequest, NotificationMessage>(
        (Stream<UserRequest> requestStream) async* {
      // Проверяем, существует ли пользователь
      bool userExists =
          _users.values.any((user) => user.name == request.username);

      print('User exists check: $userExists');

      if (!userExists) {
        // Уведомление об ошибке
        yield NotificationMessage('error', 'Пользователь не найден');
        return;
      }

      // Отправляем приветствие
      yield NotificationMessage(
          'welcome', 'Добро пожаловать, ${request.username}!');

      // Отправляем несколько уведомлений
      for (int i = 1; i <= 3; i++) {
        await Future.delayed(Duration(milliseconds: 10));
        yield NotificationMessage(
            'info', 'Уведомление #$i для пользователя ${request.username}');
      }

      // Отправляем завершающее уведомление
      yield NotificationMessage('bye', 'До свидания, ${request.username}!');
    }).createServerStreaming();
  }
}

// Клиентская реализация
base class ClientUserService extends UserServiceContract {
  @override
  final RpcEndpoint client;

  ClientUserService(this.client);

  @override
  Future<UserResponse> registerUser(UserRequest request) {
    print('ClientUserService.registerUser called with ${request.username}');
    return client
        .unaryRequest(
          serviceName: serviceName,
          methodName: UserServiceContract.registerUserMethod,
        )
        .call<UserRequest, UserResponse>(
          request: request,
          responseParser: UserResponse.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<UserRequest, NotificationMessage>
      subscribeToNotifications(UserRequest request) {
    print(
        'ClientUserService.subscribeToNotifications called with ${request.username}');
    try {
      print(
          'Creating ServerStreaming object. serviceName=$serviceName, methodName=${UserServiceContract.subscribeToNotificationsMethod}');
      final serverStreaming = client.serverStreaming(
        serviceName: serviceName,
        methodName: UserServiceContract.subscribeToNotificationsMethod,
      );

      print('Calling method with request=${request.toJson()}');
      final result = serverStreaming.call<UserRequest, NotificationMessage>(
        request: request,
        responseParser: NotificationMessage.fromJson,
      );

      print('ServerStreaming call completed');
      return result;
    } catch (e, stack) {
      print('ERROR in subscribeToNotifications: $e');
      print('Stack trace: $stack');
      rethrow;
    }
  }
}

// Фабричные методы
UserRequest createUserRequest({String username = 'test_user', int age = 25}) {
  return UserRequest(username, age);
}

// Команда для вывода всех зарегистрированных методов
void printRegisteredMethods(RpcEndpoint endpoint, String label) {
  // Выводит информацию о зарегистрированных методах
  print('== Методы, зарегистрированные на $label ==');
  try {
    final dynamic impl =
        endpoint; // Используем dynamic для доступа к внутренним полям
    final dynamic delegate = impl._delegate;
    final Map<String, Map<String, dynamic>> methodHandlers =
        delegate._methodHandlers;
    final Map<String, dynamic> contractsMap = impl._contracts;

    print('Зарегистрированные контракты: ${contractsMap.keys.join(', ')}');

    for (final service in methodHandlers.keys) {
      print('Сервис: $service');
      final methods = methodHandlers[service]!;
      for (final method in methods.keys) {
        print('  - Метод: $method');
      }
    }
  } catch (e, stack) {
    print('Ошибка при получении информации о методах: $e');
    print('Stack trace: $stack');
  }
  print('====================');
}

void main() {
  group('Контракты сервисов и их валидация', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late JsonSerializer serializer;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientUserService clientService;
    late ServerUserService serverService;

    setUp(() {
      try {
        // Создаем пару связанных транспортов
        clientTransport = MemoryTransport('client');
        serverTransport = MemoryTransport('server');
        clientTransport.connect(serverTransport);
        serverTransport.connect(clientTransport);
        print('Transports connected');

        // Сериализатор
        serializer = JsonSerializer();
        print('Serializer created');

        // Создаем эндпоинты
        clientEndpoint = RpcEndpoint(
          transport: clientTransport,
          serializer: serializer,
          debugLabel: 'client',
        );
        serverEndpoint = RpcEndpoint(
          transport: serverTransport,
          serializer: serializer,
          debugLabel: 'server',
        );
        print('Endpoints created');

        // Создаем сервисы
        serverService = ServerUserService();
        clientService = ClientUserService(clientEndpoint);
        print('Services created');

        // Регистрируем контракт сервера
        print(
            'Registering server contract, service name: ${serverService.serviceName}');
        try {
          serverEndpoint.registerServiceContract(serverService);
          print('Server contract registered successfully');
        } catch (e, stack) {
          print('ERROR registering server contract: $e');
          print('Stack trace: $stack');
          rethrow;
        }

        // Регистрируем контракт клиента
        print(
            'Registering client contract, service name: ${clientService.serviceName}');
        try {
          clientEndpoint.registerServiceContract(clientService);
          print('Client contract registered successfully');
        } catch (e, stack) {
          print('ERROR registering client contract: $e');
          print('Stack trace: $stack');
          rethrow;
        }

        // Выводим информацию о зарегистрированных методах
        printRegisteredMethods(serverEndpoint, 'SERVER');
        printRegisteredMethods(clientEndpoint, 'CLIENT');
      } catch (e, stack) {
        print('ERROR in setUp: $e');
        print('Stack trace: $stack');
        rethrow;
      }
    });

    tearDown(() async {
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test('успешная_регистрация_пользователя_возвращает_корректный_ответ',
        () async {
      // Создаем запрос
      final request = createUserRequest(username: 'ivan', age: 30);

      // Отправляем запрос
      final response = await clientService.registerUser(request);

      // Проверяем ответ
      expect(response.name, equals('ivan'));
      expect(response.isActive, isTrue);
      expect(response.id, startsWith('user_'));
    });

    test(
        'подписка_на_уведомления_после_регистрации_возвращает_корректный_поток',
        () async {
      // Создаем и регистрируем пользователя
      final registerRequest = createUserRequest(username: 'maria', age: 25);
      await clientService.registerUser(registerRequest);

      // Подписываемся на уведомления
      final notificationRequest = createUserRequest(username: 'maria', age: 25);
      final notificationStream =
          clientService.subscribeToNotifications(notificationRequest);

      // Получаем все уведомления
      final notifications = await notificationStream.toList();

      // Проверяем ответы
      expect(notifications.length, equals(5));
      expect(notifications[0].type, equals('welcome'));
      expect(notifications[1].type, equals('info'));
      expect(notifications[4].type, equals('bye'));
    });

    test('подписка_без_регистрации_возвращает_ошибку', () async {
      // Создаем запрос без предварительной регистрации
      final request = createUserRequest(username: 'unknown_user', age: 20);

      // Получаем поток уведомлений
      final stream = clientService.subscribeToNotifications(request);

      // Получаем первое уведомление
      final firstNotification = await stream.first;

      // Проверяем, что это уведомление об ошибке
      expect(firstNotification.type, equals('error'));
      expect(firstNotification.message, contains('не найден'));
    });

    // Другие тесты...
  });
}
