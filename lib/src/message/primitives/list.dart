part of '_index.dart';

/// Обертка для списка значений, использующая DelegatingList
class RpcList<E> extends DelegatingList<E> implements IRpcSerializableMessage {
  /// Создает RpcList из списка
  RpcList(List<E> list) : super(List<E>.from(list));

  /// Создает RpcList из JSON, предполагая что элементы уже правильного типа
  factory RpcList.fromJson(Map<String, dynamic> json) {
    try {
      final list = json['v'] as List?;
      if (list == null) {
        return RpcList<E>([]);
      }
      return RpcList<E>(list.cast<E>());
    } catch (e) {
      // Если что-то пошло не так, возвращаем пустой список
      return RpcList<E>([]);
    }
  }

  /// Создает RpcList из JSON с конвертером для элементов
  factory RpcList.withConverter(
    Map<String, dynamic> json,
    E Function(dynamic) itemFromJson,
  ) {
    try {
      final list = json['v'] as List?;
      if (list == null) {
        return RpcList<E>([]);
      }
      return RpcList<E>(list.map((item) => itemFromJson(item)).toList());
    } catch (e) {
      // Если что-то пошло не так, возвращаем пустой список
      return RpcList<E>([]);
    }
  }

  /// Создает RpcList из обычного списка
  static RpcList<T> from<T>(List<T> list) {
    if (T != IRpcSerializableMessage &&
        !list.every((element) => element is IRpcSerializableMessage)) {
      throw RpcUnsupportedOperationException(
        operation: 'from',
        type: 'RpcList',
        details: {
          'hint': 'All elements of the list must implement IRpcSerializableMessage. '
              'Use RpcInt, RpcString and other explicit wrappers for primitive types.',
        },
      );
    }
    return RpcList<T>(List<T>.from(list));
  }

  @override
  Map<String, dynamic> toJson() {
    final convertedList = map((item) {
      if (item is! IRpcSerializableMessage) {
        throw RpcUnsupportedOperationException(
          operation: 'toJson',
          type: 'RpcList',
          details: {
            'hint': 'Element $item must implement IRpcSerializableMessage. '
                'Use RpcInt, RpcString and other explicit wrappers for primitive types.',
          },
        );
      }
      return (item as IRpcSerializableMessage).toJson();
    }).toList();

    return {'v': convertedList};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RpcList<E>) return false;

    return const ListEquality().equals(this, other);
  }

  @override
  int get hashCode => const ListEquality().hash(this);

  @override
  String toString() => toJson().toString();
}
