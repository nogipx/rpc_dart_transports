import 'dart:async';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';

part 'rpc_bidirectional_stream_builder.dart';
part 'rpc_client_stream_builder.dart';
part 'rpc_server_stream_builder.dart';
part 'rpc_unary_request_builder.dart';

/// Сериализатор, который просто передает данные как есть без преобразования
class PassthroughSerializer<T> implements IRpcSerializer<T> {
  const PassthroughSerializer();

  T fromBytes(Uint8List bytes) => utf8.decode(bytes) as T;

  Uint8List toBytes(T data) => utf8.encode(data.toString());

  @override
  T deserialize(Uint8List data) => fromBytes(data);

  @override
  Uint8List serialize(T data) => toBytes(data);
}
