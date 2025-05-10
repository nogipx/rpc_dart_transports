import 'package:rpc_dart/rpc_dart.dart';

/// Класс для простых данных сообщения
class SimpleMessageData implements IRpcSerializableMessage {
  final String text;
  final int number;
  final bool flag;
  final String? timestamp;

  SimpleMessageData({required this.text, required this.number, required this.flag, this.timestamp});

  @override
  Map<String, dynamic> toJson() => {
    'text': text,
    'number': number,
    'flag': flag,
    if (timestamp != null) 'timestamp': timestamp,
  };

  static SimpleMessageData fromJson(Map<String, dynamic> json) {
    // Извлекаем примитивы из JSON
    String text = '';
    int number = 0;
    bool flag = false;
    String? timestamp;

    if (json.containsKey('text')) {
      final textValue = json['text'];
      if (textValue is String) {
        text = textValue;
      } else if (textValue is Map && textValue.containsKey('v')) {
        text = textValue['v'] as String? ?? '';
      }
    }

    if (json.containsKey('number')) {
      final numberValue = json['number'];
      if (numberValue is int) {
        number = numberValue;
      } else if (numberValue is Map && numberValue.containsKey('v')) {
        number = (numberValue['v'] as num?)?.toInt() ?? 0;
      }
    }

    if (json.containsKey('flag')) {
      final flagValue = json['flag'];
      if (flagValue is bool) {
        flag = flagValue;
      } else if (flagValue is Map && flagValue.containsKey('v')) {
        flag = flagValue['v'] as bool? ?? false;
      }
    }

    if (json.containsKey('timestamp')) {
      final timestampValue = json['timestamp'];
      if (timestampValue is String) {
        timestamp = timestampValue;
      } else if (timestampValue is Map && timestampValue.containsKey('v')) {
        timestamp = timestampValue['v'] as String?;
      }
    }

    return SimpleMessageData(text: text, number: number, flag: flag, timestamp: timestamp);
  }
}

/// Класс для данных с вложенной структурой
class NestedData implements IRpcSerializableMessage {
  final ConfigData config;
  final ItemList items;
  final String? timestamp;

  NestedData({required this.config, required this.items, this.timestamp});

  @override
  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'items': items.toJson(),
    if (timestamp != null) 'timestamp': timestamp,
  };

  static NestedData fromJson(Map<String, dynamic> json) {
    ConfigData config;
    if (json['config'] is Map) {
      config = ConfigData.fromJson(json['config'] as Map<String, dynamic>);
    } else {
      config = ConfigData(enabled: false, timeout: 0);
    }

    ItemList items;
    if (json['items'] is Map) {
      items = ItemList.fromJson(json['items'] as Map<String, dynamic>);
    } else {
      items = ItemList([]);
    }

    String? timestamp;
    if (json.containsKey('timestamp')) {
      final timestampValue = json['timestamp'];
      if (timestampValue is String) {
        timestamp = timestampValue;
      } else if (timestampValue is Map && timestampValue.containsKey('v')) {
        timestamp = timestampValue['v'] as String?;
      }
    }

    return NestedData(config: config, items: items, timestamp: timestamp);
  }
}

/// Класс для конфигурационных данных
class ConfigData implements IRpcSerializableMessage {
  final bool enabled;
  final int timeout;

  ConfigData({required this.enabled, required this.timeout});

  @override
  Map<String, dynamic> toJson() => {'enabled': enabled, 'timeout': timeout};

  static ConfigData fromJson(Map<String, dynamic> json) {
    bool enabled = false;
    int timeout = 0;

    if (json.containsKey('enabled')) {
      final enabledValue = json['enabled'];
      if (enabledValue is bool) {
        enabled = enabledValue;
      } else if (enabledValue is Map && enabledValue.containsKey('v')) {
        enabled = enabledValue['v'] as bool? ?? false;
      }
    }

    if (json.containsKey('timeout')) {
      final timeoutValue = json['timeout'];
      if (timeoutValue is int) {
        timeout = timeoutValue;
      } else if (timeoutValue is Map && timeoutValue.containsKey('v')) {
        timeout = (timeoutValue['v'] as num?)?.toInt() ?? 0;
      }
    }

    return ConfigData(enabled: enabled, timeout: timeout);
  }
}

/// Класс для списка элементов
class ItemList implements IRpcSerializableMessage {
  final List<String> items;

  ItemList(this.items);

  @override
  Map<String, dynamic> toJson() => {'items': items};

  static ItemList fromJson(Map<String, dynamic> json) {
    final List<String> items = [];

    if (json.containsKey('items')) {
      final itemsList = json['items'];
      if (itemsList is List) {
        for (var item in itemsList) {
          if (item is String) {
            items.add(item);
          } else if (item is Map && item.containsKey('v')) {
            items.add(item['v'] as String? ?? '');
          }
        }
      }
    }

    return ItemList(items);
  }
}
