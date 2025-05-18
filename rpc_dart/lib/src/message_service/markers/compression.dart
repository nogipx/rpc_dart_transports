// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Типы сжатия данных
enum RpcCompressionType {
  /// Без сжатия
  none,

  /// Сжатие GZIP
  gzip,

  /// Сжатие Snappy
  snappy,

  /// Сжатие Deflate
  deflate,

  /// Сжатие Brotli
  brotli,

  /// Сжатие Zstandard
  zstd,
}

/// Маркер для указания используемого метода сжатия
class RpcCompressionMarker extends RpcServiceMarker {
  /// Тип используемого сжатия
  final RpcCompressionType compressionType;

  /// Уровень сжатия (для алгоритмов с настраиваемым уровнем)
  final int? compressionLevel;

  /// Включено ли сжатие (позволяет временно отключить)
  final bool enabled;

  /// Конструктор
  const RpcCompressionMarker({
    required this.compressionType,
    this.compressionLevel,
    this.enabled = true,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.compression;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['compressionType'] = compressionType.name;
    if (compressionLevel != null) {
      baseJson['compressionLevel'] = compressionLevel;
    }
    baseJson['enabled'] = enabled;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcCompressionMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.compression.name) {
      throw FormatException('Неверный формат маркера сжатия');
    }

    final compressionTypeName = json['compressionType'] as String;
    final compressionType = RpcCompressionType.values.firstWhere(
      (type) => type.name == compressionTypeName,
      orElse: () => RpcCompressionType.none,
    );

    return RpcCompressionMarker(
      compressionType: compressionType,
      compressionLevel: json['compressionLevel'] as int?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
