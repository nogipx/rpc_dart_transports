// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// WebSocket транспорт для RPC Dart
///
/// Включает:
/// - WebSocketBaseTransport - базовая реализация транспорта
/// - WebSocketCallerTransport - клиентская часть
/// - WebSocketResponderTransport - серверная часть
/// - Компоненты обработки сообщений и управления потоками
library;

export 'websocket_base_transport.dart';
export 'websocket_caller_transport.dart';
export 'websocket_responder_transport.dart';

// Обработчики и менеджеры
export 'processors/message_processor.dart';
export 'processors/message_encoder.dart';
export 'managers/stream_manager.dart';
export 'managers/reconnect_manager.dart';
