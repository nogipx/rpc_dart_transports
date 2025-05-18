import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rpc_dart/rpc_dart.dart';

part 'bidirectional_models.freezed.dart';
part 'bidirectional_models.g.dart';

/// Тип сообщения в чате
enum MessageType {
  /// Обычное текстовое сообщение
  text,

  /// Информационное сообщение (вход/выход пользователя, и т.д.)
  info,

  /// Системное уведомление
  system,

  /// Сообщение о действии (печатает, отправил файл, и т.д.)
  action,
}

/// Модель сообщения чата
@freezed
abstract class ChatMessage extends IRpcSerializableMessage with _$ChatMessage {
  const ChatMessage._();

  @Implements<IRpcSerializableMessage>()
  const factory ChatMessage({
    @Default('') String sender,
    @Default('') String text,
    @Default(MessageType.text) MessageType type,
    String? timestamp,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
}

/// Класс для простых данных сообщения
@freezed
abstract class SimpleMessageData extends IRpcSerializableMessage with _$SimpleMessageData {
  const SimpleMessageData._();

  @Implements<IRpcSerializableMessage>()
  const factory SimpleMessageData({
    @Default('') String text,
    @Default(0) int number,
    @Default(false) bool flag,
    String? timestamp,
  }) = _SimpleMessageData;

  factory SimpleMessageData.fromJson(Map<String, dynamic> json) =>
      _$SimpleMessageDataFromJson(json);
}

/// Класс для конфигурационных данных
@freezed
abstract class ConfigData extends IRpcSerializableMessage with _$ConfigData {
  const ConfigData._();

  @Implements<IRpcSerializableMessage>()
  const factory ConfigData({
    @Default(false) bool enabled,
    @Default(0) int timeout,
  }) = _ConfigData;

  factory ConfigData.fromJson(Map<String, dynamic> json) => _$ConfigDataFromJson(json);
}

/// Класс для списка элементов
@freezed
abstract class ItemList extends IRpcSerializableMessage with _$ItemList {
  const ItemList._();

  @Implements<IRpcSerializableMessage>()
  const factory ItemList({@Default([]) List<String> items}) = _ItemList;

  factory ItemList.fromJson(Map<String, dynamic> json) => _$ItemListFromJson(json);
}

/// Класс для данных с вложенной структурой
@freezed
abstract class NestedData extends IRpcSerializableMessage with _$NestedData {
  const NestedData._();

  @Implements<IRpcSerializableMessage>()
  const factory NestedData({
    required ConfigData config,
    required ItemList items,
    String? timestamp,
  }) = _NestedData;

  factory NestedData.fromJson(Map<String, dynamic> json) => _$NestedDataFromJson(json);
}
