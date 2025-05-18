// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Класс для обработки различных служебных маркеров
class RpcMarkerHandler {
  /// Обработчик для маркеров завершения клиентского стрима
  final void Function(RpcClientStreamEndMarker)? onClientStreamEnd;

  /// Обработчик для маркеров завершения серверного стрима
  final void Function(RpcServerStreamEndMarker)? onServerStreamEnd;

  /// Обработчик для пинг-запросов
  final void Function(RpcPingMarker)? onPing;

  /// Обработчик для понг-ответов
  final void Function(RpcPongMarker)? onPong;

  /// Обработчик для статусов
  final void Function(RpcStatusMarker)? onStatus;

  /// Обработчик для заголовков
  final void Function(RpcHeadersMarker)? onHeaders;

  /// Обработчик для трейлеров
  final void Function(RpcTrailersMarker)? onTrailers;

  /// Обработчик для маркеров тайм-аутов
  final void Function(RpcDeadlineMarker)? onDeadline;

  /// Обработчик для маркеров отмены
  final void Function(RpcCancelMarker)? onCancel;

  /// Обработчик для маркеров управления потоком
  final void Function(RpcFlowControlMarker)? onFlowControl;

  /// Обработчик для маркеров сжатия
  final void Function(RpcCompressionMarker)? onCompression;

  /// Обработчик для маркеров проверки состояния
  final void Function(RpcHealthCheckMarker)? onHealthCheck;

  /// Обработчик для маркеров инициализации стриминга
  final void Function(RpcClientStreamingMarker)? onClientStreamingInit;

  /// Обработчик для маркеров инициализации двунаправленного стриминга
  final void Function(RpcBidirectionalStreamingMarker)? onBidirectionalInit;

  /// Обработчик для маркеров закрытия канала связи
  final void Function(RpcChannelClosedMarker)? onChannelClosed;

  /// Универсальный обработчик для любых маркеров (вызывается всегда)
  final void Function(RpcServiceMarker)? onAnyMarker;

  /// Конструктор
  const RpcMarkerHandler({
    this.onClientStreamEnd,
    this.onServerStreamEnd,
    this.onPing,
    this.onPong,
    this.onStatus,
    this.onHeaders,
    this.onTrailers,
    this.onDeadline,
    this.onCancel,
    this.onFlowControl,
    this.onCompression,
    this.onHealthCheck,
    this.onClientStreamingInit,
    this.onBidirectionalInit,
    this.onChannelClosed,
    this.onAnyMarker,
  });

  /// Обрабатывает маркер в соответствии с его типом
  void handleMarker(RpcServiceMarker marker) {
    // Всегда вызываем универсальный обработчик, если он есть
    onAnyMarker?.call(marker);

    // Вызываем специфичный обработчик в зависимости от типа маркера
    switch (marker.markerType) {
      case RpcMarkerType.clientStreamEnd:
        onClientStreamEnd?.call(marker as RpcClientStreamEndMarker);
        break;
      case RpcMarkerType.serverStreamEnd:
        onServerStreamEnd?.call(marker as RpcServerStreamEndMarker);
        break;
      case RpcMarkerType.ping:
        onPing?.call(marker as RpcPingMarker);
        break;
      case RpcMarkerType.pong:
        onPong?.call(marker as RpcPongMarker);
        break;
      case RpcMarkerType.status:
        onStatus?.call(marker as RpcStatusMarker);
        break;
      case RpcMarkerType.headers:
        onHeaders?.call(marker as RpcHeadersMarker);
        break;
      case RpcMarkerType.trailers:
        onTrailers?.call(marker as RpcTrailersMarker);
        break;
      case RpcMarkerType.deadline:
        onDeadline?.call(marker as RpcDeadlineMarker);
        break;
      case RpcMarkerType.cancel:
        onCancel?.call(marker as RpcCancelMarker);
        break;
      case RpcMarkerType.flowControl:
        onFlowControl?.call(marker as RpcFlowControlMarker);
        break;
      case RpcMarkerType.compression:
        onCompression?.call(marker as RpcCompressionMarker);
        break;
      case RpcMarkerType.healthCheck:
        onHealthCheck?.call(marker as RpcHealthCheckMarker);
        break;
      case RpcMarkerType.clientStreamingInit:
        onClientStreamingInit?.call(marker as RpcClientStreamingMarker);
        break;
      case RpcMarkerType.bidirectional:
        onBidirectionalInit?.call(marker as RpcBidirectionalStreamingMarker);
        break;
      case RpcMarkerType.channelClosed:
        onChannelClosed?.call(marker as RpcChannelClosedMarker);
        break;
    }
  }

  /// Проверяет, является ли объект служебным маркером
  static bool isServiceMarker(dynamic obj) {
    if (obj is Map<String, dynamic>) {
      // Проверка на стандартный маркер с флагом
      if (obj.containsKey('_isServiceMessage') &&
          obj['_isServiceMessage'] == true) {
        return true;
      }

      // Проверка на старые форматы маркеров
      if (obj.containsKey('_clientStreaming') && obj.containsKey('_streamId')) {
        return true;
      }

      if (obj.containsKey('_bidirectional') && obj.containsKey('_streamId')) {
        return true;
      }

      if (obj.containsKey('_clientStreamEnd') &&
          obj['_clientStreamEnd'] == true) {
        return true;
      }

      if (obj.containsKey('_serverStreamEnd') &&
          obj['_serverStreamEnd'] == true) {
        return true;
      }

      if (obj.containsKey('_channelClosed') && obj['_channelClosed'] == true) {
        return true;
      }

      return false;
    }
    return obj is RpcServiceMarker;
  }

  /// Создает маркер из JSON-объекта, если это маркер
  /// Возвращает null, если объект не является маркером
  static RpcServiceMarker? tryParseMarker(dynamic obj) {
    if (obj is RpcServiceMarker) {
      return obj;
    }

    if (obj is Map<String, dynamic>) {
      // Проверка на специальную форму клиентского стриминга
      if (obj.containsKey('_clientStreaming') && obj.containsKey('_streamId')) {
        final streamId = obj['_streamId'] as String;
        return RpcClientStreamingMarker(
          streamId: streamId,
          parameters: Map.from(obj)
            ..removeWhere((key, _) => key.startsWith('_')),
        );
      }

      // Проверка на специальную форму двунаправленного стриминга
      if (obj.containsKey('_bidirectional') && obj.containsKey('_streamId')) {
        final streamId = obj['_streamId'] as String;
        return RpcBidirectionalStreamingMarker(
          streamId: streamId,
          parameters: Map.from(obj)
            ..removeWhere((key, _) => key.startsWith('_')),
        );
      }

      // Проверка на маркер завершения клиентского стрима
      if (obj.containsKey('_clientStreamEnd') &&
          obj['_clientStreamEnd'] == true) {
        return const RpcClientStreamEndMarker();
      }

      // Проверка на маркер завершения серверного стрима
      if (obj.containsKey('_serverStreamEnd') &&
          obj['_serverStreamEnd'] == true) {
        return const RpcServerStreamEndMarker();
      }

      // Проверка на маркер закрытия канала
      if (obj.containsKey('_channelClosed') && obj['_channelClosed'] == true) {
        return RpcChannelClosedMarker(
          streamId: obj['_streamId'] as String?,
          reason: obj['reason'] as String?,
        );
      }

      // Проверка на обычный маркер
      if (obj.containsKey('_isServiceMessage') &&
          obj['_isServiceMessage'] == true) {
        try {
          return RpcServiceMarker.fromJson(obj);
        } catch (e) {
          // Если разбор маркера не удался, возвращаем null
          return null;
        }
      }
    }

    return null;
  }
}
