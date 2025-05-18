// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Расширение для IRpcTransport, добавляющее методы для работы с маркерами
extension RpcMarkerTransportExtension on IRpcTransport {
  /// Отправляет служебный маркер
  Future<void> sendServiceMarker(
    RpcServiceMarker marker, {
    IRpcSerializer serializer = const MsgPackSerializer(),
  }) async {
    final json = marker.toJson();
    final data = serializer.serialize(json);
    await send(data);
  }

  /// Отправляет успешный статус OK
  Future<void> sendOkStatus([String message = 'OK']) async {
    await sendStatus(
      code: RpcStatusCode.ok,
      message: message,
    );
  }

  /// Отправляет маркер статуса
  Future<void> sendStatus({
    required RpcStatusCode code,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    final marker = RpcStatusMarker(
      code: code,
      message: message,
      details: details,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер отмены операции
  Future<void> cancelOperation({
    required String operationId,
    String? reason,
    Map<String, dynamic>? details,
  }) async {
    final marker = RpcCancelMarker(
      operationId: operationId,
      reason: reason,
      details: details,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер установки тайм-аута
  Future<void> setDeadline(Duration timeout) async {
    final marker = RpcDeadlineMarker.fromDuration(timeout);
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер завершения клиентского потока
  Future<void> endClientStream() async {
    const marker = RpcClientStreamEndMarker();
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер завершения серверного потока
  Future<void> endServerStream() async {
    const marker = RpcServerStreamEndMarker();
    await sendServiceMarker(marker);
  }

  /// Отправляет пинг для проверки соединения
  Future<void> sendPing() async {
    final marker = RpcPingMarker();
    await sendServiceMarker(marker);
  }

  /// Отправляет понг в ответ на пинг
  Future<void> sendPong(RpcPingMarker pingMarker) async {
    final marker = RpcPongMarker(originalTimestamp: pingMarker.timestamp);
    await sendServiceMarker(marker);
  }

  /// Отправляет заголовки (метаданные)
  Future<void> sendHeaders(Map<String, dynamic> headers) async {
    final marker = RpcHeadersMarker(headers: headers);
    await sendServiceMarker(marker);
  }

  /// Отправляет трейлеры (завершающие метаданные)
  Future<void> sendTrailers(Map<String, dynamic> trailers) async {
    final marker = RpcTrailersMarker(trailers: trailers);
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер управления потоком
  Future<void> sendFlowControl({
    required int windowSize,
    bool allowData = true,
  }) async {
    final marker = RpcFlowControlMarker(
      windowSize: windowSize,
      allowData: allowData,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет запрос на проверку состояния сервиса
  Future<void> checkServiceHealth(String serviceName) async {
    final marker = RpcHealthCheckMarker(serviceName: serviceName);
    await sendServiceMarker(marker);
  }

  /// Отправляет ответ о состоянии сервиса
  Future<void> reportServiceHealth({
    required String serviceName,
    required RpcServiceHealthStatus status,
  }) async {
    final marker = RpcHealthCheckMarker.response(
      serviceName: serviceName,
      status: status,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет информацию о сжатии
  Future<void> setCompression({
    required RpcCompressionType compressionType,
    int? compressionLevel,
    bool enabled = true,
  }) async {
    final marker = RpcCompressionMarker(
      compressionType: compressionType,
      compressionLevel: compressionLevel,
      enabled: enabled,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер инициализации двунаправленного стриминга
  Future<void> initBidirectionalStreaming({
    required String streamId,
    Map<String, dynamic>? parameters,
  }) async {
    final marker = RpcBidirectionalStreamingMarker(
      streamId: streamId,
      parameters: parameters,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер закрытия канала
  Future<void> closeChannel({
    String? streamId,
    String? reason,
  }) async {
    final marker = RpcChannelClosedMarker(
      streamId: streamId,
      reason: reason,
    );
    await sendServiceMarker(marker);
  }
}
