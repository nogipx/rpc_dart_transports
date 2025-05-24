import 'dart:async';
import '_index.dart';

/// ============================================
/// ПРИМЕР ИСПОЛЬЗОВАНИЯ - USER SERVICE
/// ============================================

/// 🎯 Контракт пользовательского сервиса
/// IDE будет показывать автодополнение для всех методов!
/// Теперь полностью дженериковый - можно использовать ЛЮБЫЕ типы!
abstract class UserServiceContract extends RpcServiceContract {
  // Константы имен методов
  static const methodGetUser = 'getUser';
  static const methodCreateUser = 'createUser';
  static const methodListUsers = 'listUsers';
  static const methodWatchUsers = 'watchUsers';

  UserServiceContract() : super('UserService');

  @override
  void setup() {
    // 🎯 Декларативная регистрация методов в DSL стиле!
    // Теперь можно использовать ЛЮБЫЕ пользовательские типы!
    addUnaryMethod<GetUserRequest, UserResponse>(
      methodName: methodGetUser,
      handler: getUser,
      description: 'Получает пользователя по ID',
    );

    addUnaryMethod<CreateUserRequest, UserResponse>(
      methodName: methodCreateUser,
      handler: createUser,
      description: 'Создает нового пользователя',
    );

    addServerStreamMethod<ListUsersRequest, UserResponse>(
      methodName: methodListUsers,
      handler: listUsers,
      description: 'Получает список пользователей потоком',
    );

    addBidirectionalMethod<WatchUsersRequest, UserEventResponse>(
      methodName: methodWatchUsers,
      handler: watchUsers,
      description: 'Наблюдает за изменениями пользователей',
    );

    super.setup();
  }

  /// 🎯 IDE покажет автодополнение для этих методов!
  /// Получает пользователя по ID
  Future<UserResponse> getUser(GetUserRequest request);

  /// Создает нового пользователя
  Future<UserResponse> createUser(CreateUserRequest request);

  /// Получает список пользователей потоком
  Stream<UserResponse> listUsers(ListUsersRequest request);

  /// Наблюдает за изменениями пользователей
  Stream<UserEventResponse> watchUsers(Stream<WatchUsersRequest> requests);
}

/// ============================================
/// КЛИЕНТСКАЯ РЕАЛИЗАЦИЯ
/// ============================================

/// Клиент пользовательского сервиса
/// 🎯 Автоматически генерируется на основе контракта!
class UserServiceClient extends UserServiceContract {
  final RpcEndpoint _endpoint;

  UserServiceClient(this._endpoint);

  @override
  Future<UserResponse> getUser(GetUserRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: UserServiceContract.methodGetUser,
        )
        .call(
          request: request,
          responseParser: UserResponse.fromJson,
        );
  }

  @override
  Future<UserResponse> createUser(CreateUserRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: UserServiceContract.methodCreateUser,
        )
        .call(
          request: request,
          responseParser: UserResponse.fromJson,
        );
  }

  @override
  Stream<UserResponse> listUsers(ListUsersRequest request) {
    return _endpoint
        .serverStream(
          serviceName: serviceName,
          methodName: UserServiceContract.methodListUsers,
        )
        .call(
          request: request,
          responseParser: UserResponse.fromJson,
        );
  }

  @override
  Stream<UserEventResponse> watchUsers(Stream<WatchUsersRequest> requests) {
    return _endpoint
        .bidirectionalStream(
          serviceName: serviceName,
          methodName: UserServiceContract.methodWatchUsers,
        )
        .call(
          requests: requests,
          responseParser: UserEventResponse.fromJson,
        );
  }
}

/// ============================================
/// СЕРВЕРНАЯ РЕАЛИЗАЦИЯ
/// ============================================

/// Сервер пользовательского сервиса
/// 🎯 Принимает callback функции для обработки!
class UserServiceServer extends UserServiceContract {
  @override
  Future<UserResponse> getUser(GetUserRequest request) async {
    print('   📥 Сервер: Получен запрос getUser(${request.userId})');

    if (request.userId == 999) {
      return UserResponse(
        user: null,
        isSuccess: false,
      );
    }

    final user = User(
      id: request.userId,
      name: 'Пользователь ${request.userId}',
      email: 'user${request.userId}@example.com',
    );

    return UserResponse(
      user: user,
    );
  }

  @override
  Future<UserResponse> createUser(CreateUserRequest request) async {
    print('   📥 Сервер: Получен запрос createUser(${request.name})');

    final user = User(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      name: request.name,
      email: request.email,
    );

    return UserResponse(
      user: user,
    );
  }

  @override
  Stream<UserResponse> listUsers(ListUsersRequest request) async* {
    print('   📥 Сервер: Получен запрос listUsers(limit: ${request.limit})');

    for (int i = 1; i <= request.limit; i++) {
      final user = User(
        id: i,
        name: 'Пользователь $i',
        email: 'user$i@example.com',
      );

      yield UserResponse(
        user: user,
      );

      // Имитируем задержку между элементами стрима
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  @override
  Stream<UserEventResponse> watchUsers(
    Stream<WatchUsersRequest> requests,
  ) async* {
    print('   📥 Сервер: Запущен watchUsers');

    await for (final request in requests) {
      print('   📡 Наблюдаем за пользователями: ${request.userIds}');

      // Имитируем события для каждого пользователя
      for (final userId in request.userIds) {
        final event = UserEvent(
          userId: userId,
          eventType: 'USER_UPDATED',
          data: {
            'field': 'last_activity',
            'value': DateTime.now().toIso8601String()
          },
          timestamp: DateTime.now(),
        );

        yield UserEventResponse(
          event: event,
        );

        await Future.delayed(Duration(milliseconds: 200));
      }
    }
  }
}

/// ============================================
/// RPC-СОВМЕСТИМЫЕ ПОЛЬЗОВАТЕЛЬСКИЕ ТИПЫ
/// ============================================

/// Доменная модель запроса пользователя - реализует IRpcSerializableMessage
class GetUserRequest implements IRpcSerializable {
  final int userId;

  GetUserRequest({required this.userId});

  /// Опциональная валидация (не обязательно)
  bool isValid() => userId > 0;

  /// Обязательная сериализация в JSON
  @override
  Uint8List serialize() => {'userId': userId};

  static GetUserRequest fromJson(Map<String, dynamic> json) {
    return GetUserRequest(userId: json['userId']);
  }
}

/// Доменная модель создания пользователя - реализует IRpcSerializableMessage
class CreateUserRequest implements IRpcSerializable {
  final String name;
  final String email;

  CreateUserRequest({required this.name, required this.email});

  /// Опциональная валидация (не обязательно)
  bool isValid() => name.trim().isNotEmpty && email.contains('@');

  @override
  Map<String, dynamic> serialize() => {'name': name, 'email': email};

  static CreateUserRequest fromJson(Map<String, dynamic> json) {
    return CreateUserRequest(name: json['name'], email: json['email']);
  }
}

class ListUsersRequest implements IRpcSerializable {
  final int limit;
  final int offset;

  ListUsersRequest({this.limit = 10, this.offset = 0});

  bool isValid() => limit > 0 && offset >= 0;

  @override
  Map<String, dynamic> serialize() => {'limit': limit, 'offset': offset};

  static ListUsersRequest fromJson(Map<String, dynamic> json) {
    return ListUsersRequest(
      limit: json['limit'] ?? 10,
      offset: json['offset'] ?? 0,
    );
  }
}

class WatchUsersRequest implements IRpcSerializable {
  final List<int> userIds;

  WatchUsersRequest({required this.userIds});

  bool isValid() => userIds.isNotEmpty;

  @override
  Map<String, dynamic> serialize() => {'userIds': userIds};

  static WatchUsersRequest fromJson(Map<String, dynamic> json) {
    return WatchUsersRequest(userIds: List<int>.from(json['userIds']));
  }
}

/// Доменная модель ответа - реализует IRpcSerializableMessage
class UserResponse implements IRpcSerializable {
  final User? user;
  final bool isSuccess;
  final String? errorMessage;

  const UserResponse({
    this.user,
    this.isSuccess = true,
    this.errorMessage,
  });

  @override
  Map<String, dynamic> serialize() => {
        'user': user?.serialize(),
        'isSuccess': isSuccess,
        'errorMessage': errorMessage,
      };

  static UserResponse fromJson(Map<String, dynamic> json) {
    return UserResponse(
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      isSuccess: json['isSuccess'] ?? true,
      errorMessage: json['errorMessage'],
    );
  }
}

class UserEventResponse implements IRpcSerializable {
  final UserEvent event;
  final bool isSuccess;

  const UserEventResponse({required this.event, this.isSuccess = true});

  @override
  Map<String, dynamic> serialize() => {
        'event': event.serialize(),
        'isSuccess': isSuccess,
      };

  static UserEventResponse fromJson(Map<String, dynamic> json) {
    return UserEventResponse(
      event: UserEvent.fromJson(json['event']),
      isSuccess: json['isSuccess'] ?? true,
    );
  }
}

/// Доменная модель пользователя - реализует IRpcSerializableMessage
class User implements IRpcSerializable {
  final int id;
  final String name;
  final String email;

  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  @override
  Map<String, dynamic> serialize() => {
        'id': id,
        'name': name,
        'email': email,
      };

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

/// Доменная модель события - реализует IRpcSerializableMessage
class UserEvent implements IRpcSerializable {
  final int userId;
  final String eventType;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const UserEvent({
    required this.userId,
    required this.eventType,
    required this.data,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> serialize() => {
        'userId': userId,
        'eventType': eventType,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  static UserEvent fromJson(Map<String, dynamic> json) {
    return UserEvent(
      userId: json['userId'],
      eventType: json['eventType'],
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// ============================================
/// ПРИМЕР ИСПОЛЬЗОВАНИЯ СТРОГОГО API
/// ============================================

void exampleUsage() async {
  // 🎯 Теперь TypeScript-подобная строгость!
  // Все типы ОБЯЗАНЫ реализовывать IRpcSerializableMessage

  // ✅ Компилируется - GetUserRequest реализует IRpcSerializableMessage
  final request = GetUserRequest(userId: 123);
  final json = request.serialize(); // Гарантированно доступен!

  final response = UserResponse(
    user: User(id: 123, name: 'Тест', email: 'test@example.com'),
  );
  final responseJson = response.serialize(); // Тоже гарантированно доступен!

  print('✅ Строгий API работает!');
  print('Request JSON: $json');
  print('Response JSON: $responseJson');
}

/// Пример создания и использования клиента
void clientUsageExample() async {
  // Предполагаем, что у нас есть endpoint
  // final endpoint = CleanDomainRpcEndpoint(transport: someTransport);

  // 🎯 Создаем клиент напрямую - просто и понятно!
  // final client = UserServiceClient(endpoint);

  // ✅ Все методы контракта доступны с автодополнением!
  // final user = await client.getUser(GetUserRequest(userId: 123));
  // final newUser = await client.createUser(CreateUserRequest(
  //   name: 'Новый пользователь',
  //   email: 'new@example.com',
  // ));

  // 🔥 IDE покажет все методы: getUser, createUser, listUsers, watchUsers
  print('✅ Простое создание клиента - никаких лишних методов!');
}
