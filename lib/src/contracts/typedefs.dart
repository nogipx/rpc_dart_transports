// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Тип для унарного метода
typedef RpcMethodUnaryHandler<Request, Response> = Future<Response> Function(
    Request);

/// Тип для стримингового метода
typedef RpcMethodServerStreamHandler<Request, Response> = Stream<Response>
    Function(Request);

/// Тип для клиентского стримингового метода
typedef RpcMethodClientStreamHandler<Request, Response> = Future<Response>
    Function(Stream<Request>);

/// Тип для двунаправленного стримингового метода
typedef RpcMethodBidirectionalHandler<Request, Response> = Stream<Response>
    Function(Stream<Request>, String);

/// Тип для десериализации JSON в объект
typedef RpcMethodArgumentParser<Request> = Request Function(
    Map<String, dynamic>);

/// Тип для сериализации объекта в JSON
typedef RpcMethodResponseParser<Response> = Response Function(
    Map<String, dynamic>);
