# Поддержка бинарной сериализации в RPC Dart

В RPC Dart версии 2.0 была добавлена поддержка различных форматов сериализации, что позволяет использовать как JSON, так и бинарные форматы (например, Protobuf) без изменения основной библиотеки.

## Поддерживаемые форматы

RPC Dart поддерживает два основных формата сериализации:

1. `RpcSerializationFormat.json` - стандартный JSON формат (через UTF-8)
2. `RpcSerializationFormat.binary` - произвольный бинарный формат (Protobuf, MessagePack и др.)

## Использование форматов сериализации

### Указание формата в моделях

Чтобы указать формат сериализации для модели, реализуйте метод `getFormat()`:

```dart
class MyModel implements IRpcSerializable {
  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;
  
  @override
  Uint8List serialize() {
    // Ваша бинарная сериализация
    return Uint8List.fromList([1, 2, 3]);
  }
  
  static MyModel fromBytes(Uint8List bytes) {
    // Ваша бинарная десериализация
    return MyModel();
  }
}
```

Более простой способ - использовать готовый миксин:

```dart
class MyModel implements IRpcSerializable with BinarySerializable {
  @override
  Uint8List serialize() {
    // Реализация сериализации
    return Uint8List.fromList([1, 2, 3]);
  }
  
  static MyModel fromBytes(Uint8List bytes) {
    // Реализация десериализации
    return MyModel();
  }
}
```

### Указание формата при регистрации метода

При регистрации метода в контракте можно указать предпочтительный формат сериализации:

```dart
@override
void setup() {
  addUnaryMethod<BinaryRequest, BinaryResponse>(
    methodName: 'binaryMethod',
    handler: binaryMethod,
    serializationFormat: RpcSerializationFormat.binary,
  );
  
  // Для других типов методов:
  addServerStreamMethod<BinaryRequest, BinaryResponse>(
    methodName: 'streamMethod',
    handler: streamMethod,
    serializationFormat: RpcSerializationFormat.binary,
  );
  
  super.setup();
}
```

### Указание формата при вызове метода

При создании билдера запроса можно указать предпочтительный формат:

```dart
final response = await endpoint
    .unaryRequest(
      serviceName: 'MyService',
      methodName: 'myMethod',
      preferredFormat: RpcSerializationFormat.binary,
    )
    .call(
      request: request,
      responseParser: MyResponse.fromJson,
    );
```

Также можно указать формат непосредственно при вызове:

```dart
final response = await endpoint
    .unaryRequest(serviceName: 'MyService', methodName: 'myMethod')
    .call(
      request: request,
      responseParser: MyResponse.fromJson,
      serializationFormat: RpcSerializationFormat.binary,
    );
```

## Приоритет форматов сериализации

Формат сериализации определяется в следующем порядке:

1. Формат, указанный при вызове метода
2. Формат, указанный при создании билдера
3. Формат, указанный при регистрации метода
4. Формат, возвращаемый объектом запроса через `getFormat()`
5. По умолчанию `RpcSerializationFormat.json`

## Интеграция с Protobuf

Для использования Protobuf в вашем проекте:

1. Добавьте зависимости в `pubspec.yaml`:

```yaml
dependencies:
  protobuf: ^3.0.0

dev_dependencies:
  protoc_plugin: ^21.0.0
```

2. Создайте `.proto` файлы и сгенерируйте Dart-код

3. Создайте обертки для Protobuf моделей:

```dart
class ProtoUser implements IRpcSerializable with BinarySerializable {
  final User _proto;  // Класс, сгенерированный из .proto файла
  
  ProtoUser(this._proto);
  
  @override
  Uint8List serialize() {
    return Uint8List.fromList(_proto.writeToBuffer());
  }
  
  static ProtoUser fromBytes(Uint8List bytes) {
    return ProtoUser(User.fromBuffer(bytes));
  }
  
  // Геттеры для доступа к полям
  int get id => _proto.id;
  String get name => _proto.name;
}
```

4. Используйте эти обертки в контрактах:

```dart
abstract class UserServiceContract extends RpcServiceContract {
  @override
  void setup() {
    addUnaryMethod<ProtoGetUserRequest, ProtoGetUserResponse>(
      methodName: 'getUser',
      handler: getUser,
      serializationFormat: RpcSerializationFormat.binary,
    );
    
    super.setup();
  }
  
  Future<ProtoGetUserResponse> getUser(ProtoGetUserRequest request);
}
```

## Преимущества бинарной сериализации

1. **Производительность**: бинарные форматы быстрее сериализуются и десериализуются
2. **Компактность**: меньший размер данных по сравнению с JSON
3. **Типобезопасность**: строгая типизация и валидация схемы данных
4. **Обратная совместимость**: лучшая поддержка версионирования схем

## Миграция с JSON на бинарный формат

Для постепенной миграции рекомендуется:

1. Создать обертки для бинарных моделей, сохраняя обратную совместимость
2. Обновить контракты для поддержки обоих форматов
3. Постепенно переводить клиенты на бинарный формат
4. Обновить серверные реализации для оптимизации работы с бинарными данными 