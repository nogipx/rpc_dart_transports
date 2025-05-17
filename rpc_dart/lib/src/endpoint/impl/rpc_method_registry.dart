// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Структура для хранения полной информации о методе
final class MethodRegistration {
  /// Имя сервиса, которому принадлежит метод
  final String serviceName;

  /// Имя метода
  final String methodName;

  /// Тип метода (унарный, стриминг и т.д.)
  final RpcMethodType? methodType;

  /// Обработчик метода
  final dynamic handler;

  /// Функция для парсинга аргументов
  final Function? argumentParser;

  /// Функция для парсинга ответов (может быть null для некоторых типов)
  final Function? responseParser;

  /// Имплементация метода
  final RpcMethodImplementation? implementation;

  MethodRegistration({
    required this.serviceName,
    required this.methodName,
    required this.handler,
    this.methodType,
    this.argumentParser,
    this.responseParser,
    this.implementation,
  });
}

/// Класс для управления регистрацией и поиском сервисных контрактов и их методов
final class RpcMethodRegistry implements IRpcMethodRegistry {
  /// Зарегистрированные контракты сервисов
  final Map<String, IRpcServiceContract<IRpcSerializableMessage>> _contracts =
      {};

  /// Структурированная информация о зарегистрированных методах
  final Map<String, Map<String, MethodRegistration>> _methods = {};

  /// Логгер
  final RpcLogger _logger = RpcLogger('RpcServiceRegistry');

  /// Возвращает зарегистрированный контракт сервиса по имени
  @override
  IRpcServiceContract<IRpcSerializableMessage>? getServiceContract(
      String serviceName) {
    return _contracts[serviceName];
  }

  /// Возвращает все зарегистрированные контракты
  @override
  Map<String, IRpcServiceContract<IRpcSerializableMessage>> getAllContracts() {
    return Map.unmodifiable(_contracts);
  }

  /// Регистрирует сервисный контракт и все его методы
  @override
  void registerContract(IRpcServiceContract<IRpcSerializableMessage> contract) {
    if (_contracts.containsKey(contract.serviceName)) {
      _logger.error(
          'Контракт сервиса ${contract.serviceName} уже зарегистрирован');
      return;
    }

    _logger.debug('Регистрация контракта: ${contract.serviceName}');
    _contracts[contract.serviceName] = contract;

    // Если контракт имеет собственный реестр, объединяем его с текущим
    if (contract is RpcServiceContract) {
      contract.mergeInto(this);
    } else {
      // Для обычных контрактов продолжаем использовать прежнюю логику
      contract.setup();
      _collectAndRegisterMethods(contract);

      // Рекурсивно регистрируем подконтракты, если возможно
      if (contract is RpcServiceContract) {
        for (final subContract in contract.getSubContracts()) {
          registerContract(subContract);
        }
      }
    }
  }

  /// Собирает и регистрирует все методы контракта
  void _collectAndRegisterMethods(
      IRpcServiceContract<IRpcSerializableMessage> contract) {
    for (final method in contract.methods) {
      final methodName = method.methodName;
      final handler = contract.getMethodHandler(methodName);
      final argumentParser = contract.getMethodArgumentParser(methodName);
      final responseParser = contract.getMethodResponseParser(methodName);

      _logger.debug('Сбор метода ${contract.serviceName}.$methodName:');
      _logger.debug('  - Handler: ${handler != null ? "найден" : "не найден"}');
      _logger.debug(
          '  - ArgumentParser: ${argumentParser != null ? "найден" : "не найден"}');
      _logger.debug(
          '  - ResponseParser: ${responseParser != null ? "найден" : "не найден"}');

      if (handler == null || argumentParser == null) {
        _logger.error(
            'Метод ${contract.serviceName}.$methodName пропущен из-за отсутствия обязательных компонентов');
        continue;
      }

      registerMethod(
        serviceName: contract.serviceName,
        methodName: methodName,
        methodType: method.methodType,
        handler: handler,
        argumentParser: argumentParser,
        responseParser: responseParser,
      );
    }
  }

  /// Регистрирует отдельный метод
  @override
  void registerMethod({
    required String serviceName,
    required String methodName,
    required dynamic handler,
    RpcMethodType? methodType,
    Function? argumentParser,
    Function? responseParser,
  }) {
    if (handler == null) {
      throw ArgumentError(
          'Handler и argumentParser обязательны для регистрации метода');
    }

    // Проверка необходимости responseParser для определенных типов методов
    bool needsResponseParser = methodType == RpcMethodType.unary ||
        methodType == RpcMethodType.serverStreaming ||
        methodType == RpcMethodType.bidirectional;

    if (needsResponseParser && responseParser == null) {
      _logger.error(
          'Метод $serviceName.$methodName типа $methodType требует responseParser, но он не предоставлен');
    }

    // Создаем запись о методе в реестре
    _methods.putIfAbsent(serviceName, () => {});

    final registration = MethodRegistration(
      serviceName: serviceName,
      methodName: methodName,
      methodType: methodType,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );

    _methods[serviceName]![methodName] = registration;
    _logger.debug('Метод $serviceName.$methodName успешно зарегистрирован');
  }

  /// Регистрирует реализацию метода
  @override
  void registerMethodImplementation({
    required String serviceName,
    required String methodName,
    required RpcMethodImplementation implementation,
  }) {
    _logger.debug('Регистрация реализации метода $serviceName.$methodName');

    // Проверяем, существует ли уже запись для этого метода
    final existingMethod = findMethod(serviceName, methodName);

    // Создаем запись о методе в реестре, если её ещё нет
    _methods.putIfAbsent(serviceName, () => {});

    if (existingMethod != null) {
      // Если метод уже зарегистрирован, обновляем его с имплементацией
      final updatedRegistration = MethodRegistration(
        serviceName: existingMethod.serviceName,
        methodName: existingMethod.methodName,
        methodType: existingMethod.methodType,
        handler: existingMethod.handler,
        argumentParser: existingMethod.argumentParser,
        responseParser: existingMethod.responseParser,
        implementation: implementation,
      );

      _methods[serviceName]![methodName] = updatedRegistration;
      _logger.debug(
          'Добавлена реализация для существующего метода $serviceName.$methodName');
    } else {
      // Если метод ещё не зарегистрирован, создаем новую запись только с имплементацией
      final registration = MethodRegistration(
        serviceName: serviceName,
        methodName: methodName,
        methodType: implementation.type,
        handler: null, // Обработчик будет вызываться через имплементацию
        argumentParser: null, // Парсер будет вызываться через имплементацию
        responseParser: null, // Парсер будет вызываться через имплементацию
        implementation: implementation,
      );

      _methods[serviceName]![methodName] = registration;
      _logger.debug(
          'Создана новая запись метода $serviceName.$methodName с имплементацией');
    }
  }

  /// Находит информацию о методе по имени сервиса и методу
  @override
  MethodRegistration? findMethod(String serviceName, String methodName) {
    return _methods[serviceName]?[methodName];
  }

  /// Возвращает список всех зарегистрированных методов
  @override
  Iterable<MethodRegistration> getAllMethods() {
    return _methods.values.expand((methods) => methods.values);
  }

  /// Возвращает список методов для конкретного сервиса
  @override
  Iterable<MethodRegistration> getMethodsForService(String serviceName) {
    return _methods[serviceName]?.values ?? const [];
  }

  /// Очищает весь реестр
  @override
  void clearMethodsRegistry() {
    _contracts.clear();
    _methods.clear();
  }
}

/// Выводит отладочную информацию о методах в registry
void debugPrintRegisteredMethods(IRpcMethodRegistry registry, String label) {
  final methods = registry.getAllMethods();

  print('\n=== Методы в registry: $label (${methods.length}) ===');
  for (final method in methods) {
    print('${method.serviceName}.${method.methodName} (${method.methodType})');
    print('  • Handler: ${method.handler != null ? 'Есть' : 'Нет!'}');
    print('  • ArgParser: ${method.argumentParser != null ? 'Есть' : 'Нет!'}');
    print('  • RespParser: ${method.responseParser != null ? 'Есть' : 'Нет!'}');
    print(
        '  • Implementation: ${method.implementation != null ? 'Есть' : 'Нет!'}');
  }
  print('=====================================\n');
}

/// Выводит информацию о зарегистрированных контрактах
void debugPrintRegisteredContracts(IRpcMethodRegistry registry, String label) {
  final contracts = registry.getAllContracts();

  print('\n=== Контракты в registry: $label (${contracts.length}) ===');
  for (final entry in contracts.entries) {
    final contractName = entry.key;
    final contract = entry.value;

    print('$contractName (${contract.runtimeType})');
    print('  • Методов: ${contract.methods.length}');

    if (contract is RpcServiceContract) {
      final subContracts = contract.getSubContracts();
      print('  • Субконтрактов: ${subContracts.length}');
      for (final subContract in subContracts) {
        print(
            '    - ${subContract.serviceName} (${subContract.methods.length} методов)');
      }
    }
  }
  print('=====================================\n');
}
