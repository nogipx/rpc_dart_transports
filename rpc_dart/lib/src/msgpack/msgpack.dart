// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

part 'data_writer.dart';
part 'deserializer.dart';
part 'serializer.dart';

class MsgPackFormatException implements Exception {
  MsgPackFormatException(this.message);
  final String message;

  @override
  String toString() {
    return "FormatError: $message";
  }
}

Uint8List serialize(
  dynamic value, {
  ExtEncoder? extEncoder,
}) {
  final s = Serializer(extEncoder: extEncoder);
  s.encode(value);
  return s.takeBytes();
}

dynamic deserialize(
  Uint8List list, {
  ExtDecoder? extDecoder,
  bool copyBinaryData = false,
}) {
  final d = Deserializer(
    list,
    extDecoder: extDecoder,
    copyBinaryData: copyBinaryData,
  );
  return d.decode();
}
