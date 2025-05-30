// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Роутер для маршрутизации RPC сообщений между клиентами
///
/// Включает:
/// - IRouterContract, IRouter, IRouterClientManager - интерфейсы роутера
/// - RouterResponderImpl - основная реализация роутера
/// - RouterResponderContract - RPC контракт адаптер
/// - RouterClient - клиентская часть роутера
/// - RouterMessage, RouterEvent, RouterClientInfo - основные модели данных
/// - RouterRegisterRequest, RouterRegisterResponse - DTO для запросов/ответов
/// - RouterStats - статистика роутера
library;

// Интерфейсы
export 'interfaces/router_interface.dart';

// Реализации
export 'implementations/router_responder.dart';

// RPC контракты
export 'router_contract.dart';

// Клиентская часть
export 'router_client.dart';

// Основные модели данных
export 'router_models.dart';

// DTO модели для запросов и ответов
export 'models/_index.dart';

// Статистика
export 'router_stats.dart';
