//
//  Generated code. Do not modify.
//  source: weather_service.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use weatherRequestDescriptor instead')
const WeatherRequest$json = {
  '1': 'WeatherRequest',
  '2': [
    {'1': 'city', '3': 1, '4': 1, '5': 9, '10': 'city'},
  ],
};

/// Descriptor for `WeatherRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List weatherRequestDescriptor = $convert.base64Decode(
    'Cg5XZWF0aGVyUmVxdWVzdBISCgRjaXR5GAEgASgJUgRjaXR5');

@$core.Deprecated('Use weatherResponseDescriptor instead')
const WeatherResponse$json = {
  '1': 'WeatherResponse',
  '2': [
    {'1': 'city', '3': 1, '4': 1, '5': 9, '10': 'city'},
    {'1': 'temperature', '3': 2, '4': 1, '5': 1, '10': 'temperature'},
    {'1': 'condition', '3': 3, '4': 1, '5': 9, '10': 'condition'},
    {'1': 'humidity', '3': 4, '4': 1, '5': 1, '10': 'humidity'},
    {'1': 'wind_speed', '3': 5, '4': 1, '5': 1, '10': 'windSpeed'},
  ],
};

/// Descriptor for `WeatherResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List weatherResponseDescriptor = $convert.base64Decode(
    'Cg9XZWF0aGVyUmVzcG9uc2USEgoEY2l0eRgBIAEoCVIEY2l0eRIgCgt0ZW1wZXJhdHVyZRgCIA'
    'EoAVILdGVtcGVyYXR1cmUSHAoJY29uZGl0aW9uGAMgASgJUgljb25kaXRpb24SGgoIaHVtaWRp'
    'dHkYBCABKAFSCGh1bWlkaXR5Eh0KCndpbmRfc3BlZWQYBSABKAFSCXdpbmRTcGVlZA==');

@$core.Deprecated('Use forecastRequestDescriptor instead')
const ForecastRequest$json = {
  '1': 'ForecastRequest',
  '2': [
    {'1': 'city', '3': 1, '4': 1, '5': 9, '10': 'city'},
    {'1': 'days', '3': 2, '4': 1, '5': 5, '10': 'days'},
  ],
};

/// Descriptor for `ForecastRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forecastRequestDescriptor = $convert.base64Decode(
    'Cg9Gb3JlY2FzdFJlcXVlc3QSEgoEY2l0eRgBIAEoCVIEY2l0eRISCgRkYXlzGAIgASgFUgRkYX'
    'lz');

@$core.Deprecated('Use forecastResponseDescriptor instead')
const ForecastResponse$json = {
  '1': 'ForecastResponse',
  '2': [
    {'1': 'city', '3': 1, '4': 1, '5': 9, '10': 'city'},
    {'1': 'forecast', '3': 2, '4': 3, '5': 11, '6': '.weather.DailyForecast', '10': 'forecast'},
  ],
};

/// Descriptor for `ForecastResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forecastResponseDescriptor = $convert.base64Decode(
    'ChBGb3JlY2FzdFJlc3BvbnNlEhIKBGNpdHkYASABKAlSBGNpdHkSMgoIZm9yZWNhc3QYAiADKA'
    'syFi53ZWF0aGVyLkRhaWx5Rm9yZWNhc3RSCGZvcmVjYXN0');

@$core.Deprecated('Use dailyForecastDescriptor instead')
const DailyForecast$json = {
  '1': 'DailyForecast',
  '2': [
    {'1': 'date', '3': 1, '4': 1, '5': 9, '10': 'date'},
    {'1': 'temperature_min', '3': 2, '4': 1, '5': 1, '10': 'temperatureMin'},
    {'1': 'temperature_max', '3': 3, '4': 1, '5': 1, '10': 'temperatureMax'},
    {'1': 'condition', '3': 4, '4': 1, '5': 9, '10': 'condition'},
  ],
};

/// Descriptor for `DailyForecast`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dailyForecastDescriptor = $convert.base64Decode(
    'Cg1EYWlseUZvcmVjYXN0EhIKBGRhdGUYASABKAlSBGRhdGUSJwoPdGVtcGVyYXR1cmVfbWluGA'
    'IgASgBUg50ZW1wZXJhdHVyZU1pbhInCg90ZW1wZXJhdHVyZV9tYXgYAyABKAFSDnRlbXBlcmF0'
    'dXJlTWF4EhwKCWNvbmRpdGlvbhgEIAEoCVIJY29uZGl0aW9u');

@$core.Deprecated('Use weatherUpdateDescriptor instead')
const WeatherUpdate$json = {
  '1': 'WeatherUpdate',
  '2': [
    {'1': 'city', '3': 1, '4': 1, '5': 9, '10': 'city'},
    {'1': 'temperature', '3': 2, '4': 1, '5': 1, '10': 'temperature'},
    {'1': 'condition', '3': 3, '4': 1, '5': 9, '10': 'condition'},
  ],
};

/// Descriptor for `WeatherUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List weatherUpdateDescriptor = $convert.base64Decode(
    'Cg1XZWF0aGVyVXBkYXRlEhIKBGNpdHkYASABKAlSBGNpdHkSIAoLdGVtcGVyYXR1cmUYAiABKA'
    'FSC3RlbXBlcmF0dXJlEhwKCWNvbmRpdGlvbhgDIAEoCVIJY29uZGl0aW9u');

