import 'package:rpc_dart/rpc_dart.dart';
import 'dart:async';

/// Пример использования контрактов сервисов для типобезопасности
void main() async {
  print('=== Пример контрактов сервисов ===\n');

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

  // Добавляем middleware для логирования
  client.addMiddleware(
    RpcMiddlewareWrapper(
      debugLabel: 'ClientLogger',
      onResponseHandler: (service, method, response, context, direction) {
        if (direction == RpcDataDirection.fromRemote) {
          print('Клиент получил ответ от $service.$method');
        }
        return response;
      },
    ),
  );

  server.addMiddleware(
    RpcMiddlewareWrapper(
      debugLabel: 'ServerLogger',
      onRequestHandler: (service, method, payload, context, direction) {
        if (direction == RpcDataDirection.fromRemote) {
          print('Сервер получил запрос к $service.$method');
        }
        return payload;
      },
    ),
  );

  try {
    // Создаем и регистрируем серверные контракты
    final userServiceImpl = ServerUserService();
    final notificationServiceImpl = ServerNotificationService();

    // Регистрируем серверные контракты
    server.registerServiceContract(userServiceImpl);
    server.registerServiceContract(notificationServiceImpl);
    print('Серверные контракты зарегистрированы');

    // Создаем клиентские контракты
    final userService = ClientUserService(client);
    final notificationService = ClientNotificationService(client);

    // Регистрируем клиентские контракты (опционально, для вызова через client.invoke)
    client.registerServiceContract(userService);
    client.registerServiceContract(notificationService);
    print('Клиентские контракты зарегистрированы');

    // Демонстрация использования UserService
    await demonstrateUserService(userService);

    // Демонстрация использования NotificationService
    await demonstrateNotificationService(notificationService);
  } catch (e) {
    print('Произошла ошибка: $e');
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    print('\nЭндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Демонстрация использования UserService
Future<void> demonstrateUserService(ClientUserService userService) async {
  print('\n--- Демонстрация UserService ---');

  // Получение информации о пользователе
  print('\nПолучение информации о пользователе:');
  final user = await userService.getUserById(RpcString('user123'));
  print('Получен пользователь:');
  print('  ID: ${user.id}');
  print('  Имя: ${user.name}');
  print('  Email: ${user.email}');
  print('  Роль: ${user.role}');

  // Обновление пользователя
  print('\nОбновление информации о пользователе:');
  final updatedUser = await userService.updateUser(
    UpdateUserRequest(
      id: 'user123',
      name: 'Иван Иванов (обновлено)',
      email: 'ivan@example.com',
    ),
  );
  print('Пользователь обновлен:');
  print('  ID: ${updatedUser.id}');
  print('  Имя: ${updatedUser.name}');
  print('  Обновлен: ${updatedUser.updatedAt}');

  // Поиск пользователей
  print('\nПоиск пользователей с ролью "admin":');
  final users = await userService.searchUsers(
    SearchUsersRequest(role: 'admin', limit: 2),
  );
  print('Найдено пользователей: ${users.length}');

  for (final user in users) {
    print('  - ${user.name} (${user.email}) - ${user.role}');
  }
}

/// Демонстрация использования NotificationService
Future<void> demonstrateNotificationService(
  ClientNotificationService notificationService,
) async {
  print('\n--- Демонстрация NotificationService ---');

  // Получение потока уведомлений
  print('\nПодписка на поток уведомлений:');
  final notificationsStream = notificationService.subscribeToNotifications(
    SubscriptionRequest(userId: 'user123'),
  );

  // Отправка уведомления
  print('\nОтправка уведомления:');
  final notificationResult = await notificationService.sendNotification(
    NotificationRequest(
      userId: 'user123',
      title: 'Важное уведомление',
      message: 'Это тестовое уведомление от RPC',
      type: 'info',
    ),
  );
  print('Уведомление отправлено:');
  print('  ID: ${notificationResult.notificationId}');
  print('  Статус: ${notificationResult.status}');

  // Отправляем 3 новых уведомления для демонстрации
  print('Отправляем 3 новых уведомления...');
  for (var i = 1; i <= 3; i++) {
    await notificationService.sendNotification(
      NotificationRequest(
        userId: 'user123',
        title: 'Уведомление #$i',
        message: 'Содержание уведомления #$i',
        type: i % 2 == 0 ? 'warning' : 'info',
      ),
    );

    // Небольшая задержка для имитации реального сценария
    await Future.delayed(Duration(milliseconds: 300));
  }

  print('\nОжидаем получения уведомлений:');
  var count = 0;
  await for (final notification in notificationsStream) {
    print('Получено уведомление:');
    print('  ID: ${notification.id}');
    print('  Заголовок: ${notification.title}');
    print('  Сообщение: ${notification.message}');
    print('  Тип: ${notification.type}');

    count++;
    if (count >= 3) break; // Ограничиваем для демонстрации
  }
}

// -------------------------------------------------------------------------
// Определения моделей данных
// -------------------------------------------------------------------------

/// Модель пользователя
class User implements IRpcSerializableMessage {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String createdAt;
  final String? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

/// Запрос на обновление пользователя
class UpdateUserRequest implements IRpcSerializableMessage {
  final String id;
  final String? name;
  final String? email;
  final String? role;
  final String? avatarUrl;

  UpdateUserRequest({
    required this.id,
    this.name,
    this.email,
    this.role,
    this.avatarUrl,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (role != null) 'role': role,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };

  static UpdateUserRequest fromJson(Map<String, dynamic> json) {
    return UpdateUserRequest(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Результат обновления пользователя
class UpdateUserResponse implements IRpcSerializableMessage {
  final String id;
  final String name;
  final String updatedAt;
  final bool success;

  UpdateUserResponse({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.success,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'updatedAt': updatedAt,
        'success': success,
      };

  static UpdateUserResponse fromJson(Map<String, dynamic> json) {
    return UpdateUserResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      updatedAt: json['updatedAt'] as String,
      success: json['success'] as bool,
    );
  }
}

/// Запрос на поиск пользователей
class SearchUsersRequest implements IRpcSerializableMessage {
  final String? name;
  final String? email;
  final String? role;
  final int limit;
  final int offset;

  SearchUsersRequest({
    this.name,
    this.email,
    this.role,
    this.limit = 10,
    this.offset = 0,
  });

  @override
  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (role != null) 'role': role,
        'limit': limit,
        'offset': offset,
      };

  static SearchUsersRequest fromJson(Map<String, dynamic> json) {
    return SearchUsersRequest(
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      limit: json['limit'] as int? ?? 10,
      offset: json['offset'] as int? ?? 0,
    );
  }
}

/// Запрос уведомления
class NotificationRequest implements IRpcSerializableMessage {
  final String userId;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? metadata;

  NotificationRequest({
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        if (metadata != null) 'metadata': metadata,
      };

  static NotificationRequest fromJson(Map<String, dynamic> json) {
    return NotificationRequest(
      userId: json['userId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Результат отправки уведомления
class NotificationResult implements IRpcSerializableMessage {
  final String notificationId;
  final String status;
  final String createdAt;

  NotificationResult({
    required this.notificationId,
    required this.status,
    required this.createdAt,
  });

  @override
  Map<String, dynamic> toJson() => {
        'notificationId': notificationId,
        'status': status,
        'createdAt': createdAt,
      };

  static NotificationResult fromJson(Map<String, dynamic> json) {
    return NotificationResult(
      notificationId: json['notificationId'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

/// Модель уведомления
class Notification implements IRpcSerializableMessage {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool read;
  final String createdAt;
  final Map<String, dynamic>? metadata;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
    this.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'read': read,
        'createdAt': createdAt,
        if (metadata != null) 'metadata': metadata,
      };

  static Notification fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      read: json['read'] as bool,
      createdAt: json['createdAt'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Запрос на подписку
class SubscriptionRequest implements IRpcSerializableMessage {
  final String userId;
  final List<String>? types;

  SubscriptionRequest({
    required this.userId,
    this.types,
  });

  @override
  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (types != null) 'types': types,
      };

  static SubscriptionRequest fromJson(Map<String, dynamic> json) {
    return SubscriptionRequest(
      userId: json['userId'] as String,
      types: json['types'] != null
          ? (json['types'] as List).map((e) => e as String).toList()
          : null,
    );
  }
}

// -------------------------------------------------------------------------
// Контракты сервисов
// -------------------------------------------------------------------------

/// Контракт сервиса пользователей
abstract final class UserServiceContract extends RpcServiceContract {
  @override
  final String serviceName = 'UserService';

  @override
  void setup() {
    // Унарный метод получения пользователя по ID
    addUnaryMethod<RpcString, User>(
      methodName: 'getUserById',
      handler: getUserById,
      argumentParser: (json) => RpcString.fromJson(json),
      responseParser: User.fromJson,
    );

    // Унарный метод обновления пользователя
    addUnaryMethod<UpdateUserRequest, UpdateUserResponse>(
      methodName: 'updateUser',
      handler: updateUser,
      argumentParser: UpdateUserRequest.fromJson,
      responseParser: UpdateUserResponse.fromJson,
    );

    // Унарный метод поиска пользователей
    addUnaryMethod<SearchUsersRequest, RpcList<User>>(
      methodName: 'searchUsers',
      handler: searchUsers,
      argumentParser: SearchUsersRequest.fromJson,
      responseParser: (json) {
        final map = json;
        final list = map['value'] as List;
        return RpcList<User>(
            list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList());
      },
    );
  }

  // Абстрактные методы, которые должны быть реализованы
  Future<User> getUserById(RpcString id);
  Future<UpdateUserResponse> updateUser(UpdateUserRequest request);
  Future<RpcList<User>> searchUsers(SearchUsersRequest request);
}

/// Контракт сервиса уведомлений
abstract final class NotificationServiceContract extends RpcServiceContract {
  @override
  final String serviceName = 'NotificationService';

  @override
  void setup() {
    // Унарный метод отправки уведомления
    addUnaryMethod<NotificationRequest, NotificationResult>(
      methodName: 'sendNotification',
      handler: sendNotification,
      argumentParser: NotificationRequest.fromJson,
      responseParser: NotificationResult.fromJson,
    );

    // Серверный стриминг для подписки на уведомления
    addServerStreamingMethod<SubscriptionRequest, Notification>(
      methodName: 'subscribeToNotifications',
      handler: subscribeToNotifications,
      argumentParser: SubscriptionRequest.fromJson,
      responseParser: Notification.fromJson,
    );
  }

  // Абстрактные методы, которые должны быть реализованы
  Future<NotificationResult> sendNotification(NotificationRequest request);
  Stream<Notification> subscribeToNotifications(SubscriptionRequest request);
}

// -------------------------------------------------------------------------
// Серверные реализации контрактов
// -------------------------------------------------------------------------

/// Серверная реализация UserService
final class ServerUserService extends UserServiceContract {
  // Имитация БД пользователей
  final Map<String, User> _users = {
    'user123': User(
      id: 'user123',
      name: 'Иван Иванов',
      email: 'ivan@example.com',
      role: 'user',
      createdAt: DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
    ),
    'admin456': User(
      id: 'admin456',
      name: 'Администратор',
      email: 'admin@example.com',
      role: 'admin',
      createdAt: DateTime.now().subtract(Duration(days: 90)).toIso8601String(),
    ),
    'admin789': User(
      id: 'admin789',
      name: 'Супер Админ',
      email: 'super@example.com',
      role: 'admin',
      avatarUrl: 'https://example.com/avatar.png',
      createdAt: DateTime.now().subtract(Duration(days: 60)).toIso8601String(),
    ),
  };

  @override
  Future<User> getUserById(RpcString id) async {
    print('ServerUserService: получение пользователя с ID ${id.value}');

    // Имитация задержки сети
    await Future.delayed(Duration(milliseconds: 100));

    final user = _users[id.value];
    if (user == null) {
      throw Exception('Пользователь не найден: ${id.value}');
    }

    return user;
  }

  @override
  Future<UpdateUserResponse> updateUser(UpdateUserRequest request) async {
    print('ServerUserService: обновление пользователя с ID ${request.id}');

    // Имитация задержки сети
    await Future.delayed(Duration(milliseconds: 200));

    final user = _users[request.id];
    if (user == null) {
      throw Exception('Пользователь не найден: ${request.id}');
    }

    // Обновляем пользователя
    final updatedUser = User(
      id: user.id,
      name: request.name ?? user.name,
      email: request.email ?? user.email,
      role: request.role ?? user.role,
      avatarUrl: request.avatarUrl ?? user.avatarUrl,
      createdAt: user.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );

    // Сохраняем обновленного пользователя
    _users[request.id] = updatedUser;

    return UpdateUserResponse(
      id: updatedUser.id,
      name: updatedUser.name,
      updatedAt: updatedUser.updatedAt!,
      success: true,
    );
  }

  @override
  Future<RpcList<User>> searchUsers(SearchUsersRequest request) async {
    print('ServerUserService: поиск пользователей');

    // Имитация задержки сети
    await Future.delayed(Duration(milliseconds: 300));

    final result = _users.values.where((user) {
      if (request.name != null && !user.name.contains(request.name!)) {
        return false;
      }

      if (request.email != null && !user.email.contains(request.email!)) {
        return false;
      }

      if (request.role != null && user.role != request.role) {
        return false;
      }

      return true;
    }).toList();

    // Применяем пагинацию
    final start = request.offset;
    final end = start + request.limit;

    if (start >= result.length) {
      return RpcList<User>([]);
    }

    return RpcList<User>(
        result.sublist(start, end < result.length ? end : result.length));
  }
}

/// Серверная реализация NotificationService
final class ServerNotificationService extends NotificationServiceContract {
  // Имитация хранилища уведомлений
  final Map<String, List<Notification>> _notifications = {};

  // Потоки уведомлений для пользователей
  final Map<String, StreamController<Notification>> _streams = {};

  @override
  Future<NotificationResult> sendNotification(
    NotificationRequest request,
  ) async {
    print(
      'ServerNotificationService: отправка уведомления для ${request.userId}',
    );

    // Имитация задержки сети
    await Future.delayed(Duration(milliseconds: 150));

    final notificationId = 'notif-${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = DateTime.now().toIso8601String();

    // Создаем уведомление
    final notification = Notification(
      id: notificationId,
      userId: request.userId,
      title: request.title,
      message: request.message,
      type: request.type,
      read: false,
      createdAt: createdAt,
      metadata: request.metadata,
    );

    // Сохраняем уведомление
    _notifications.putIfAbsent(request.userId, () => []).add(notification);

    // Отправляем уведомление в поток, если он существует
    final streamController = _streams[request.userId];
    if (streamController != null && !streamController.isClosed) {
      streamController.add(notification);
    }

    return NotificationResult(
      notificationId: notificationId,
      status: 'sent',
      createdAt: createdAt,
    );
  }

  @override
  Stream<Notification> subscribeToNotifications(SubscriptionRequest request) {
    print(
        'ServerNotificationService: подписка на уведомления для ${request.userId}');

    // Создаем контроллер для потока уведомлений
    final controller = StreamController<Notification>();

    // Сохраняем контроллер
    _streams[request.userId] = controller;

    // Отправляем существующие уведомления
    final existingNotifications = _notifications[request.userId] ?? [];

    for (final notification in existingNotifications) {
      // Фильтрация по типам, если указаны
      if (request.types == null || request.types!.contains(notification.type)) {
        controller.add(notification);
      }
    }

    // Закрываем поток при отписке
    controller.onCancel = () {
      print(
          'ServerNotificationService: отписка от уведомлений для ${request.userId}');
      _streams.remove(request.userId);
      controller.close();
    };

    return controller.stream;
  }
}

// -------------------------------------------------------------------------
// Клиентские реализации контрактов
// -------------------------------------------------------------------------

/// Клиентская реализация UserService
final class ClientUserService extends UserServiceContract {
  final RpcEndpoint _endpoint;

  ClientUserService(this._endpoint);

  @override
  Future<User> getUserById(RpcString id) {
    return _endpoint.unary(serviceName, 'getUserById').call<RpcString, User>(
          request: id,
          responseParser: User.fromJson,
        );
  }

  @override
  Future<UpdateUserResponse> updateUser(UpdateUserRequest request) {
    return _endpoint
        .unary(serviceName, 'updateUser')
        .call<UpdateUserRequest, UpdateUserResponse>(
          request: request,
          responseParser: UpdateUserResponse.fromJson,
        );
  }

  @override
  Future<RpcList<User>> searchUsers(SearchUsersRequest request) {
    return _endpoint
        .unary(serviceName, 'searchUsers')
        .call<SearchUsersRequest, RpcList<User>>(
          request: request,
          responseParser: (json) {
            final map = json;
            final list = map['value'] as List;
            return RpcList<User>(list
                .map((e) => User.fromJson(e as Map<String, dynamic>))
                .toList());
          },
        );
  }
}

/// Клиентская реализация NotificationService
final class ClientNotificationService extends NotificationServiceContract {
  final RpcEndpoint _endpoint;

  ClientNotificationService(this._endpoint);

  @override
  Future<NotificationResult> sendNotification(NotificationRequest request) {
    return _endpoint
        .unary(serviceName, 'sendNotification')
        .call<NotificationRequest, NotificationResult>(
          request: request,
          responseParser: NotificationResult.fromJson,
        );
  }

  @override
  Stream<Notification> subscribeToNotifications(SubscriptionRequest request) {
    return _endpoint
        .serverStreaming(serviceName, 'subscribeToNotifications')
        .openStream<SubscriptionRequest, Notification>(
          request: request,
          responseParser: Notification.fromJson,
        );
  }
}
