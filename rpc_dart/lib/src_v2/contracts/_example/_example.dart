import 'dart:async';
import '../_index.dart';
import 'dart:convert';

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

/// Доменная модель запроса пользователя - теперь с JsonRpcSerializable
class GetUserRequest implements IRpcJsonSerializable, IRpcSerializable {
  final int userId;

  GetUserRequest({required this.userId});

  /// Опциональная валидация (не обязательно)
  bool isValid() => userId > 0;

  /// Сериализация в JSON
  @override
  Map<String, dynamic> toJson() => {'userId': userId};

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static GetUserRequest fromJson(Map<String, dynamic> json) {
    return GetUserRequest(userId: json['userId']);
  }
}

/// Доменная модель создания пользователя - теперь с JsonRpcSerializable
class CreateUserRequest implements IRpcJsonSerializable, IRpcSerializable {
  final String name;
  final String email;

  CreateUserRequest({required this.name, required this.email});

  /// Опциональная валидация (не обязательно)
  bool isValid() => name.trim().isNotEmpty && email.contains('@');

  @override
  Map<String, dynamic> toJson() => {'name': name, 'email': email};

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static CreateUserRequest fromJson(Map<String, dynamic> json) {
    return CreateUserRequest(name: json['name'], email: json['email']);
  }
}

class ListUsersRequest implements IRpcJsonSerializable, IRpcSerializable {
  final int limit;
  final int offset;

  ListUsersRequest({this.limit = 10, this.offset = 0});

  bool isValid() => limit > 0 && offset >= 0;

  @override
  Map<String, dynamic> toJson() => {'limit': limit, 'offset': offset};

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static ListUsersRequest fromJson(Map<String, dynamic> json) {
    return ListUsersRequest(
      limit: json['limit'] ?? 10,
      offset: json['offset'] ?? 0,
    );
  }
}

class WatchUsersRequest implements IRpcJsonSerializable, IRpcSerializable {
  final List<int> userIds;

  WatchUsersRequest({required this.userIds});

  bool isValid() => userIds.isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {'userIds': userIds};

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static WatchUsersRequest fromJson(Map<String, dynamic> json) {
    return WatchUsersRequest(userIds: List<int>.from(json['userIds']));
  }
}

/// Доменная модель ответа - теперь с JsonRpcSerializable
class UserResponse implements IRpcJsonSerializable, IRpcSerializable {
  final User? user;
  final bool isSuccess;
  final String? errorMessage;

  const UserResponse({
    this.user,
    this.isSuccess = true,
    this.errorMessage,
  });

  @override
  Map<String, dynamic> toJson() => {
        'user': user?.toJson(),
        'isSuccess': isSuccess,
        'errorMessage': errorMessage,
      };

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static UserResponse fromJson(Map<String, dynamic> json) {
    return UserResponse(
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      isSuccess: json['isSuccess'] ?? true,
      errorMessage: json['errorMessage'],
    );
  }
}

class UserEventResponse implements IRpcJsonSerializable, IRpcSerializable {
  final UserEvent event;
  final bool isSuccess;

  const UserEventResponse({required this.event, this.isSuccess = true});

  @override
  Map<String, dynamic> toJson() => {
        'event': event.toJson(),
        'isSuccess': isSuccess,
      };

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static UserEventResponse fromJson(Map<String, dynamic> json) {
    return UserEventResponse(
      event: UserEvent.fromJson(json['event']),
      isSuccess: json['isSuccess'] ?? true,
    );
  }
}

/// Доменная модель пользователя - теперь с JsonRpcSerializable
class User implements IRpcJsonSerializable, IRpcSerializable {
  final int id;
  final String name;
  final String email;

  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

/// Доменная модель события - теперь с JsonRpcSerializable
class UserEvent implements IRpcJsonSerializable, IRpcSerializable {
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
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'eventType': eventType,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

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
  final json = request.toJson(); // Используем toJson для получения JSON
  // Сериализуем в байты для отправки
  final serialized = request.serialize();

  final response = UserResponse(
    user: User(id: 123, name: 'Тест', email: 'test@example.com'),
  );
  final responseJson = response.toJson(); // Используем toJson для JSON

  print('✅ Строгий API работает!');
  print('Request JSON: $json');
  print('Response JSON: $responseJson');
  print('Serialized bytes length: ${serialized.length}');

  // ============================================
  // 🔥 НОВОЕ: Поддержка бинарной сериализации!
  // ============================================

  // Создание модели с бинарной сериализацией
  final binaryUser =
      BinaryUser(id: 456, name: 'Бинарный', email: 'binary@example.com');
  print(
      'Формат сериализации: ${binaryUser.getFormat().name}'); // Выведет "binary"

  // Контракт может указать предпочтительный формат сериализации
  /*
  addUnaryMethod<BinaryUser, BinaryUserResponse>(
    methodName: 'getBinaryUser',
    handler: getBinaryUser,
    serializationFormat: RpcSerializationFormat.binary, // Явное указание формата
  );
  */

  // Клиент также может указать формат при вызове
  /*
  final endpoint = RpcEndpoint(...);
  final response = await endpoint
      .unaryRequest(
        serviceName: 'UserService', 
        methodName: 'getUser',
        preferredFormat: RpcSerializationFormat.binary, // Приоритет у binary
      )
      .call(
        request: request,
        responseParser: UserResponse.fromJson,
      );
  */
}

/// Пример модели с бинарной сериализацией
class BinaryUser extends User {
  BinaryUser({required super.id, required super.name, required super.email});

  // Переопределяем формат на binary
  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;
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

/// ============================================
/// ПРИМЕР ИНТЕГРАЦИИ С PROTOBUF (ПОЛЬЗОВАТЕЛЬСКИЙ КОД)
/// ============================================

/* 
// Этот код показывает, как пользователи могут интегрировать сгенерированные 
// Protobuf классы с RPC Dart библиотекой без внесения изменений в саму библиотеку

// Предположим, у нас есть такое proto-определение:
// syntax = "proto3";
// package user;
//
// message User {
//   int32 id = 1;
//   string name = 2;
//   string email = 3;
// }
//
// message GetUserRequest {
//   int32 user_id = 1;
// }
//
// message GetUserResponse {
//   User user = 1;
//   bool success = 2;
//   string error_message = 3;
// }

// Импорты в пользовательском коде
import 'package:protobuf/protobuf.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'generated/user.pb.dart'; // Сгенерированные protobuf файлы

// Класс-обертка для протобаф-модели
class ProtoUser implements IRpcSerializable with BinarySerializable {
  final User _proto;
  
  ProtoUser(this._proto);
  
  factory ProtoUser.create({required int id, required String name, required String email}) {
    return ProtoUser(User()
      ..id = id
      ..name = name
      ..email = email);
  }
  
  @override
  Uint8List serialize() {
    // Используем встроенную сериализацию protobuf
    return Uint8List.fromList(_proto.writeToBuffer());
  }
  
  static ProtoUser fromBytes(Uint8List bytes) {
    return ProtoUser(User.fromBuffer(bytes));
  }
  
  int get id => _proto.id;
  String get name => _proto.name;
  String get email => _proto.email;
}

// Аналогично для других моделей
class ProtoGetUserRequest implements IRpcSerializable with BinarySerializable {
  final GetUserRequest _proto;
  
  ProtoGetUserRequest(this._proto);
  
  factory ProtoGetUserRequest.create({required int userId}) {
    return ProtoGetUserRequest(GetUserRequest()..userId = userId);
  }
  
  @override
  Uint8List serialize() {
    return Uint8List.fromList(_proto.writeToBuffer());
  }
  
  static ProtoGetUserRequest fromBytes(Uint8List bytes) {
    return ProtoGetUserRequest(GetUserRequest.fromBuffer(bytes));
  }
  
  int get userId => _proto.userId;
}

class ProtoGetUserResponse implements IRpcSerializable with BinarySerializable {
  final GetUserResponse _proto;
  
  ProtoGetUserResponse(this._proto);
  
  factory ProtoGetUserResponse.create({
    User? user,
    bool success = true,
    String errorMessage = '',
  }) {
    return ProtoGetUserResponse(GetUserResponse()
      ..user = user ?? User()
      ..success = success
      ..errorMessage = errorMessage);
  }
  
  @override
  Uint8List serialize() {
    return Uint8List.fromList(_proto.writeToBuffer());
  }
  
  static ProtoGetUserResponse fromBytes(Uint8List bytes) {
    return ProtoGetUserResponse(GetUserResponse.fromBuffer(bytes));
  }
  
  User? get user => _proto.hasUser() ? _proto.user : null;
  bool get success => _proto.success;
  String get errorMessage => _proto.errorMessage;
}

// Пример использования
void protoUsageExample() {
  // Создание протобаф-моделей
  final protoUser = ProtoUser.create(
    id: 123,
    name: 'Протобаф Пользователь',
    email: 'proto@example.com',
  );
  
  // Сериализация в бинарный формат
  final bytes = protoUser.serialize();
  
  // Десериализация
  final restoredUser = ProtoUser.fromBytes(bytes);
  
  print('ProtoUser: ${restoredUser.id}, ${restoredUser.name}, ${restoredUser.email}');
  
  // Использование в контракте
  // abstract class ProtoUserServiceContract extends RpcServiceContract {
  //   ProtoUserServiceContract() : super('ProtoUserService');
  //
  //   @override
  //   void setup() {
  //     addUnaryMethod<ProtoGetUserRequest, ProtoGetUserResponse>(
  //       methodName: 'getUser',
  //       handler: getUser,
  //       serializationFormat: RpcSerializationFormat.binary,
  //     );
  //   }
  //
  //   Future<ProtoGetUserResponse> getUser(ProtoGetUserRequest request);
  // }
}
*/
