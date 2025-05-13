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
    = ServerStreamingBidiStream<Response, Request> Function(Request);

// ---

/// Тип для клиентского стримингового метода
typedef RpcMethodClientStreamHandler<Request extends IRpcSerializableMessage,
        Response extends IRpcSerializableMessage>
    = ClientStreamingBidiStream<Request, Response> Function();

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
