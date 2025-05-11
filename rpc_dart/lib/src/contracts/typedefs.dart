// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

/// Тип для унарного метода
typedef RpcMethodUnaryHandler<Request extends IRpcSerializableMessage,
        Response extends IRpcSerializableMessage>
    = Future<Response> Function(Request);

// ---

/// Тип для стримингового метода
typedef RpcMethodServerStreamHandler<Request extends IRpcSerializableMessage,
        Response extends IRpcSerializableMessage>
    = Stream<Response> Function(Request);

// ---

/// Тип для клиентского стримингового метода
typedef RpcMethodClientStreamHandler<Request extends IRpcSerializableMessage,
        Response extends IRpcSerializableMessage>
    = Future<RpcClientStreamResult<Request, Response>> Function(
        RpcClientStreamParams<Request, Response>);

final class RpcClientStreamResult<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  final StreamController<Request>? controller;
  final Future<Response>? response;

  const RpcClientStreamResult({this.controller, this.response});
}

final class RpcClientStreamParams<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  final Stream<Request>? stream;
  final Map<String, dynamic>? metadata;
  final String? streamId;

  const RpcClientStreamParams({this.stream, this.metadata, this.streamId});
}

// ---

/// Тип для двунаправленного стримингового метода
typedef RpcMethodBidirectionalHandler<Request extends IRpcSerializableMessage,
        Response extends IRpcSerializableMessage>
    = BidiStream<Request, Response> Function();

// ---

/// Тип для десериализации JSON в объект
typedef RpcMethodArgumentParser<Request extends IRpcSerializableMessage>
    = Request Function(Map<String, dynamic>);

/// Тип для сериализации объекта в JSON
typedef RpcMethodResponseParser<Response extends IRpcSerializableMessage>
    = Response Function(Map<String, dynamic>);
