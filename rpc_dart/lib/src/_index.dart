import 'package:rpc_dart/rpc_dart.dart';

export 'contracts/_index.dart';
export 'endpoint/_index.dart';
export 'logs/_logs.dart';
export 'primitives/_index.dart';
export 'rpc/_index.dart';
export 'serializers/_index.dart';

// BINARY

RpcBinarySerializer<RpcBool> get binaryBoolSerializer =>
    RpcBinarySerializer<RpcBool>(RpcBool.fromBytes);

RpcBinarySerializer<RpcNull> get binaryNullSerializer =>
    RpcBinarySerializer<RpcNull>(RpcNull.fromBytes);

RpcBinarySerializer<RpcNum> get binaryNumSerializer =>
    RpcBinarySerializer<RpcNum>(RpcNum.fromBytes);

RpcBinarySerializer<RpcDouble> get binaryDoubleSerializer =>
    RpcBinarySerializer<RpcDouble>(RpcDouble.fromBytes);

RpcBinarySerializer<RpcInt> get binaryIntSerializer =>
    RpcBinarySerializer<RpcInt>(RpcInt.fromBytes);

RpcBinarySerializer<RpcString> get binaryStringSerializer =>
    RpcBinarySerializer<RpcString>(RpcString.fromBytes);

// JSON

RpcJsonSerializer<RpcBool> get jsonBoolSerializer =>
    RpcJsonSerializer<RpcBool>(RpcBool.fromJson);

RpcJsonSerializer<RpcNull> get jsonNullSerializer =>
    RpcJsonSerializer<RpcNull>(RpcNull.fromJson);

RpcJsonSerializer<RpcNum> get jsonNumSerializer =>
    RpcJsonSerializer<RpcNum>(RpcNum.fromJson);

RpcJsonSerializer<RpcDouble> get jsonDoubleSerializer =>
    RpcJsonSerializer<RpcDouble>(RpcDouble.fromJson);

RpcJsonSerializer<RpcInt> get jsonIntSerializer =>
    RpcJsonSerializer<RpcInt>(RpcInt.fromJson);

RpcJsonSerializer<RpcString> get jsonStringSerializer =>
    RpcJsonSerializer<RpcString>(RpcString.fromJson);

// CBOR

RpcCborSerializer<RpcBool> get cborBoolSerializer =>
    RpcCborSerializer<RpcBool>(RpcBool.fromJson);

RpcCborSerializer<RpcNull> get cborNullSerializer =>
    RpcCborSerializer<RpcNull>(RpcNull.fromJson);

RpcCborSerializer<RpcNum> get cborNumSerializer =>
    RpcCborSerializer<RpcNum>(RpcNum.fromJson);

RpcCborSerializer<RpcDouble> get cborDoubleSerializer =>
    RpcCborSerializer<RpcDouble>(RpcDouble.fromJson);

RpcCborSerializer<RpcInt> get cborIntSerializer =>
    RpcCborSerializer<RpcInt>(RpcInt.fromJson);

RpcCborSerializer<RpcString> get cborStringSerializer =>
    RpcCborSerializer<RpcString>(RpcString.fromJson);
