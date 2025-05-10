import 'package:collection/collection.dart';
import 'package:rpc_dart/rpc_dart.dart';

part 'bool.dart';
part 'list.dart';
part 'map.dart';
part 'null.dart';
part 'num.dart';
part 'string.dart';

/// Базовый класс для всех примитивных типов сообщений
abstract class RpcPrimitiveMessage<T> implements IRpcSerializableMessage {
  final T value;

  const RpcPrimitiveMessage(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RpcPrimitiveMessage<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
