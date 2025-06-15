// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Транспорты для RPC Dart
library;

// Экспорт основной библиотеки RPC Dart
export 'package:rpc_dart/rpc_dart.dart';

// Экспорт транспортов
export 'src/server/_index.dart';
export 'src/transports/_index.dart';

// Экспорт server bootstrap фасада
export 'src/server/rpc_server_bootstrap.dart';

// Экспорт P2P роутера
export 'src/router/_index.dart';
