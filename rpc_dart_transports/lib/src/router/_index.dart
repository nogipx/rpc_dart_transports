// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Роутер для маршрутизации RPC сообщений между клиентами
///
/// Включает:
/// - RouterResponderContract - серверная часть роутера
/// - RouterCallerContract - клиентская часть роутера
/// - RouterMessage - модели данных для сообщений
/// - RouterMessageType - типы сообщений роутера
library;

export 'router_contract.dart';
export 'router_client.dart';
export 'router_models.dart';
