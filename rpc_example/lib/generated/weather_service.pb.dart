//
//  Generated code. Do not modify.
//  source: weather_service.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

// Временный фикс для $_clearField
extension ProtobufClearFieldFix on $pb.GeneratedMessage {
  void $_clearField($core.int tagNumber) => clearField(tagNumber);
}

/// Запрос погоды по городу
class WeatherRequest extends $pb.GeneratedMessage {
  factory WeatherRequest({
    $core.String? city,
  }) {
    final $result = create();
    if (city != null) {
      $result.city = city;
    }
    return $result;
  }
  WeatherRequest._() : super();
  factory WeatherRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory WeatherRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WeatherRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'weather'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'city')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeatherRequest clone() => WeatherRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeatherRequest copyWith(void Function(WeatherRequest) updates) =>
      super.copyWith((message) => updates(message as WeatherRequest)) as WeatherRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WeatherRequest create() => WeatherRequest._();
  WeatherRequest createEmptyInstance() => create();
  static $pb.PbList<WeatherRequest> createRepeated() => $pb.PbList<WeatherRequest>();
  @$core.pragma('dart2js:noInline')
  static WeatherRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WeatherRequest>(create);
  static WeatherRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get city => $_getSZ(0);
  @$pb.TagNumber(1)
  set city($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCity() => $_has(0);
  @$pb.TagNumber(1)
  void clearCity() => $_clearField(1);
}

/// Ответ с данными о погоде
class WeatherResponse extends $pb.GeneratedMessage {
  factory WeatherResponse({
    $core.String? city,
    $core.double? temperature,
    $core.String? condition,
    $core.double? humidity,
    $core.double? windSpeed,
  }) {
    final $result = create();
    if (city != null) {
      $result.city = city;
    }
    if (temperature != null) {
      $result.temperature = temperature;
    }
    if (condition != null) {
      $result.condition = condition;
    }
    if (humidity != null) {
      $result.humidity = humidity;
    }
    if (windSpeed != null) {
      $result.windSpeed = windSpeed;
    }
    return $result;
  }
  WeatherResponse._() : super();
  factory WeatherResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory WeatherResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WeatherResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'weather'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'city')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'temperature', $pb.PbFieldType.OD)
    ..aOS(3, _omitFieldNames ? '' : 'condition')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'humidity', $pb.PbFieldType.OD)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'windSpeed', $pb.PbFieldType.OD)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeatherResponse clone() => WeatherResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeatherResponse copyWith(void Function(WeatherResponse) updates) =>
      super.copyWith((message) => updates(message as WeatherResponse)) as WeatherResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WeatherResponse create() => WeatherResponse._();
  WeatherResponse createEmptyInstance() => create();
  static $pb.PbList<WeatherResponse> createRepeated() => $pb.PbList<WeatherResponse>();
  @$core.pragma('dart2js:noInline')
  static WeatherResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WeatherResponse>(create);
  static WeatherResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get city => $_getSZ(0);
  @$pb.TagNumber(1)
  set city($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCity() => $_has(0);
  @$pb.TagNumber(1)
  void clearCity() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get temperature => $_getN(1);
  @$pb.TagNumber(2)
  set temperature($core.double v) {
    $_setDouble(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTemperature() => $_has(1);
  @$pb.TagNumber(2)
  void clearTemperature() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get condition => $_getSZ(2);
  @$pb.TagNumber(3)
  set condition($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasCondition() => $_has(2);
  @$pb.TagNumber(3)
  void clearCondition() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get humidity => $_getN(3);
  @$pb.TagNumber(4)
  set humidity($core.double v) {
    $_setDouble(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasHumidity() => $_has(3);
  @$pb.TagNumber(4)
  void clearHumidity() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get windSpeed => $_getN(4);
  @$pb.TagNumber(5)
  set windSpeed($core.double v) {
    $_setDouble(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasWindSpeed() => $_has(4);
  @$pb.TagNumber(5)
  void clearWindSpeed() => $_clearField(5);
}

/// Запрос на получение прогноза
class ForecastRequest extends $pb.GeneratedMessage {
  factory ForecastRequest({
    $core.String? city,
    $core.int? days,
  }) {
    final $result = create();
    if (city != null) {
      $result.city = city;
    }
    if (days != null) {
      $result.days = days;
    }
    return $result;
  }
  ForecastRequest._() : super();
  factory ForecastRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ForecastRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ForecastRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'weather'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'city')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'days', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForecastRequest clone() => ForecastRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForecastRequest copyWith(void Function(ForecastRequest) updates) =>
      super.copyWith((message) => updates(message as ForecastRequest)) as ForecastRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ForecastRequest create() => ForecastRequest._();
  ForecastRequest createEmptyInstance() => create();
  static $pb.PbList<ForecastRequest> createRepeated() => $pb.PbList<ForecastRequest>();
  @$core.pragma('dart2js:noInline')
  static ForecastRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ForecastRequest>(create);
  static ForecastRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get city => $_getSZ(0);
  @$pb.TagNumber(1)
  set city($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCity() => $_has(0);
  @$pb.TagNumber(1)
  void clearCity() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get days => $_getIZ(1);
  @$pb.TagNumber(2)
  set days($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDays() => $_has(1);
  @$pb.TagNumber(2)
  void clearDays() => $_clearField(2);
}

/// Ответ с прогнозом погоды
class ForecastResponse extends $pb.GeneratedMessage {
  factory ForecastResponse({
    $core.String? city,
    $core.Iterable<DailyForecast>? forecast,
  }) {
    final $result = create();
    if (city != null) {
      $result.city = city;
    }
    if (forecast != null) {
      $result.forecast.addAll(forecast);
    }
    return $result;
  }
  ForecastResponse._() : super();
  factory ForecastResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ForecastResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ForecastResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'weather'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'city')
    ..pc<DailyForecast>(2, _omitFieldNames ? '' : 'forecast', $pb.PbFieldType.PM,
        subBuilder: DailyForecast.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForecastResponse clone() => ForecastResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForecastResponse copyWith(void Function(ForecastResponse) updates) =>
      super.copyWith((message) => updates(message as ForecastResponse)) as ForecastResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ForecastResponse create() => ForecastResponse._();
  ForecastResponse createEmptyInstance() => create();
  static $pb.PbList<ForecastResponse> createRepeated() => $pb.PbList<ForecastResponse>();
  @$core.pragma('dart2js:noInline')
  static ForecastResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ForecastResponse>(create);
  static ForecastResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get city => $_getSZ(0);
  @$pb.TagNumber(1)
  set city($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCity() => $_has(0);
  @$pb.TagNumber(1)
  void clearCity() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<DailyForecast> get forecast => $_getList(1);
}

/// Прогноз на день
class DailyForecast extends $pb.GeneratedMessage {
  factory DailyForecast({
    $core.String? date,
    $core.double? temperatureMin,
    $core.double? temperatureMax,
    $core.String? condition,
  }) {
    final $result = create();
    if (date != null) {
      $result.date = date;
    }
    if (temperatureMin != null) {
      $result.temperatureMin = temperatureMin;
    }
    if (temperatureMax != null) {
      $result.temperatureMax = temperatureMax;
    }
    if (condition != null) {
      $result.condition = condition;
    }
    return $result;
  }
  DailyForecast._() : super();
  factory DailyForecast.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DailyForecast.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DailyForecast',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'weather'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'date')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'temperatureMin', $pb.PbFieldType.OD)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'temperatureMax', $pb.PbFieldType.OD)
    ..aOS(4, _omitFieldNames ? '' : 'condition')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DailyForecast clone() => DailyForecast()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DailyForecast copyWith(void Function(DailyForecast) updates) =>
      super.copyWith((message) => updates(message as DailyForecast)) as DailyForecast;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DailyForecast create() => DailyForecast._();
  DailyForecast createEmptyInstance() => create();
  static $pb.PbList<DailyForecast> createRepeated() => $pb.PbList<DailyForecast>();
  @$core.pragma('dart2js:noInline')
  static DailyForecast getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DailyForecast>(create);
  static DailyForecast? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get date => $_getSZ(0);
  @$pb.TagNumber(1)
  set date($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearDate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get temperatureMin => $_getN(1);
  @$pb.TagNumber(2)
  set temperatureMin($core.double v) {
    $_setDouble(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTemperatureMin() => $_has(1);
  @$pb.TagNumber(2)
  void clearTemperatureMin() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get temperatureMax => $_getN(2);
  @$pb.TagNumber(3)
  set temperatureMax($core.double v) {
    $_setDouble(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasTemperatureMax() => $_has(2);
  @$pb.TagNumber(3)
  void clearTemperatureMax() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get condition => $_getSZ(3);
  @$pb.TagNumber(4)
  set condition($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasCondition() => $_has(3);
  @$pb.TagNumber(4)
  void clearCondition() => $_clearField(4);
}

/// Обновление погодных данных в реальном времени
class WeatherUpdate extends $pb.GeneratedMessage {
  factory WeatherUpdate({
    $core.String? city,
    $core.double? temperature,
    $core.String? condition,
  }) {
    final $result = create();
    if (city != null) {
      $result.city = city;
    }
    if (temperature != null) {
      $result.temperature = temperature;
    }
    if (condition != null) {
      $result.condition = condition;
    }
    return $result;
  }
  WeatherUpdate._() : super();
  factory WeatherUpdate.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory WeatherUpdate.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'WeatherUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'weather'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'city')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'temperature', $pb.PbFieldType.OD)
    ..aOS(3, _omitFieldNames ? '' : 'condition')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeatherUpdate clone() => WeatherUpdate()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeatherUpdate copyWith(void Function(WeatherUpdate) updates) =>
      super.copyWith((message) => updates(message as WeatherUpdate)) as WeatherUpdate;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WeatherUpdate create() => WeatherUpdate._();
  WeatherUpdate createEmptyInstance() => create();
  static $pb.PbList<WeatherUpdate> createRepeated() => $pb.PbList<WeatherUpdate>();
  @$core.pragma('dart2js:noInline')
  static WeatherUpdate getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WeatherUpdate>(create);
  static WeatherUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get city => $_getSZ(0);
  @$pb.TagNumber(1)
  set city($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasCity() => $_has(0);
  @$pb.TagNumber(1)
  void clearCity() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get temperature => $_getN(1);
  @$pb.TagNumber(2)
  set temperature($core.double v) {
    $_setDouble(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTemperature() => $_has(1);
  @$pb.TagNumber(2)
  void clearTemperature() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get condition => $_getSZ(2);
  @$pb.TagNumber(3)
  set condition($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasCondition() => $_has(2);
  @$pb.TagNumber(3)
  void clearCondition() => $_clearField(3);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
