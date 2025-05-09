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
abstract base class UserServiceContract
    extends RpcServiceContract<IRpcSerializableMessage> {
  RpcEndpoint? get client;

  @override
  final String serviceName = 'UserService';

  @override
  void setup() {
    // Регистрация пользователя (унарный метод)
    addUnaryMethod<UserRequest, UserResponse>(
      methodName: 'registerUser',
      handler: registerUser,
      argumentParser: UserRequest.fromJson,
      responseParser: UserResponse.fromJson,
    );

    // Получение уведомлений (стрим)
    addServerStreamingMethod<UserRequest, NotificationMessage>(
      methodName: 'subscribeToNotifications',
      handler: subscribeToNotifications,
      argumentParser: UserRequest.fromJson,
      responseParser: NotificationMessage.fromJson,
    );
  }

  // Методы контракта
  Future<UserResponse> registerUser(UserRequest request);
  Stream<NotificationMessage> subscribeToNotifications(UserRequest request);
}

// Серверная реализация
base class ServerUserService extends UserServiceContract {
  final Map<String, UserResponse> _users = {};

  @override
  RpcEndpoint? get client => null;

  @override
  Future<UserResponse> registerUser(UserRequest request) async {
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
  Stream<NotificationMessage> subscribeToNotifications(
      UserRequest request) async* {
    // Проверяем, существует ли пользователь
    bool userExists =
        _users.values.any((user) => user.name == request.username);

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
  }
}

// Клиентская реализация
base class ClientUserService extends UserServiceContract {
  @override
  final RpcEndpoint client;

  ClientUserService(this.client);

  @override
  Future<UserResponse> registerUser(UserRequest request) {
    return client
        .unary(serviceName, 'registerUser')
        .call<UserRequest, UserResponse>(
          request: request,
          responseParser: UserResponse.fromJson,
        );
  }

  @override
  Stream<NotificationMessage> subscribeToNotifications(UserRequest request) {
    return client
        .serverStreaming(serviceName, 'subscribeToNotifications')
        .openStream<UserRequest, NotificationMessage>(
          request: request,
          responseParser: NotificationMessage.fromJson,
        );
  }
}

// Фабричные методы
UserRequest createUserRequest({String username = 'test_user', int age = 25}) {
  return UserRequest(username, age);
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
      // Arrange - подготовка
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');

      // Соединяем транспорты
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем сериализатор
      serializer = JsonSerializer();

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: serializer,
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: serializer,
      );

      // Создаем сервисы
      clientService = ClientUserService(clientEndpoint);
      serverService = ServerUserService();

      // Регистрируем контракты на обоих концах
      serverEndpoint.registerServiceContract(serverService);
      clientEndpoint.registerServiceContract(clientService);
    });

    tearDown(() async {
      // Освобождение ресурсов
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test('успешная_регистрация_пользователя_возвращает_корректный_ответ',
        () async {
      // Arrange - подготовка
      final request = createUserRequest(username: 'john_doe', age: 30);

      // Act - действие
      final response = await clientService.registerUser(request);

      // Assert - проверка
      expect(response.name, equals('john_doe'));
      expect(response.isActive, isTrue);
      expect(response.id, startsWith('user_'));
    });

    test('регистрация_с_невалидными_данными_вызывает_исключение', () async {
      // Arrange - подготовка
      final invalidAgeRequest =
          createUserRequest(username: 'young_user', age: 16);
      final emptyUsernameRequest = createUserRequest(username: '', age: 25);

      // Act & Assert - действие и проверка
      expect(
        () => clientService.registerUser(invalidAgeRequest),
        throwsA(anything),
      );

      expect(
        () => clientService.registerUser(emptyUsernameRequest),
        throwsA(anything),
      );
    });

    test(
        'подписка_на_уведомления_после_регистрации_возвращает_корректный_поток',
        () async {
      // Arrange - подготовка
      final registerRequest =
          createUserRequest(username: 'stream_user', age: 35);
      final notifications = <NotificationMessage>[];

      // Сначала регистрируем пользователя
      await clientService.registerUser(registerRequest);

      // Act - действие
      final stream = clientService.subscribeToNotifications(registerRequest);

      // Assert - проверка
      await for (var notification in stream) {
        notifications.add(notification);
      }

      // Проверяем количество уведомлений (приветствие + 3 инфо + прощание)
      expect(notifications.length, equals(5));

      // Проверяем типы уведомлений
      expect(notifications[0].type, equals('welcome'));
      expect(notifications[1].type, equals('info'));
      expect(notifications[4].type, equals('bye'));

      // Проверяем содержимое уведомлений
      expect(notifications[0].message, contains('stream_user'));
      expect(notifications[4].message, contains('До свидания'));
    });

    test('подписка_без_регистрации_возвращает_ошибку', () async {
      // Arrange - подготовка
      final request = createUserRequest(username: 'unknown_user', age: 40);
      final notifications = <NotificationMessage>[];

      // Act - действие
      final stream = clientService.subscribeToNotifications(request);

      // Assert - проверка
      await for (var notification in stream) {
        notifications.add(notification);
      }

      // Должно быть только одно уведомление с ошибкой
      expect(notifications.length, equals(1));
      expect(notifications[0].type, equals('error'));
      expect(notifications[0].message, contains('не найден'));
    });
  });
}
