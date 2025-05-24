// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Структура для хранения полной информации о методе
final class MethodRegistration<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  /// Имя сервиса, которому принадлежит метод
  final String serviceName;

  /// Имя метода
  final String methodName;

  /// Тип метода (унарный, стриминг и т.д.)
  final RpcMethodType methodType;

  /// Обработчик унарного метода
  final RpcMethodUnaryHandler<Request, Response>? _unaryHandler;

  /// Обработчик серверного стрима
  final RpcMethodServerStreamHandler<Request, Response>? _serverStreamHandler;

  /// Обработчик клиентского стрима с ответом
  final RpcMethodClientStreamHandler<Request, Response>? _clientStreamHandler;

  /// Обработчик двунаправленного стрима
  final RpcMethodBidirectionalHandler<Request, Response>? _bidirectionalHandler;

  /// Функция для парсинга аргументов
  final Request Function(dynamic)? argumentParser;

  /// Функция для парсинга ответов (может быть null для некоторых типов)
  final Response Function(dynamic)? responseParser;

  /// Контракт метода (если доступен)
  final RpcMethodContract<Request, Response>? methodContract;

  /// Логгер
  final RpcLogger _logger;

  /// Создает регистрацию унарного метода
  MethodRegistration.unary({
    required this.serviceName,
    required this.methodName,
    required RpcMethodUnaryHandler<Request, Response> handler,
    required this.argumentParser,
    required this.responseParser,
    this.methodContract,
  })  : methodType = RpcMethodType.unary,
        _unaryHandler = handler,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = null,
        _logger = RpcLogger('$serviceName.$methodName.registry');

  /// Создает регистрацию метода серверного стриминга
  MethodRegistration.serverStreaming({
    required this.serviceName,
    required this.methodName,
    required RpcMethodServerStreamHandler<Request, Response> handler,
    required this.argumentParser,
    required this.responseParser,
    this.methodContract,
  })  : methodType = RpcMethodType.serverStreaming,
        _unaryHandler = null,
        _serverStreamHandler = handler,
        _clientStreamHandler = null,
        _bidirectionalHandler = null,
        _logger = RpcLogger('$serviceName.$methodName.registry');

  /// Создает регистрацию метода клиентского стриминга
  MethodRegistration.clientStreaming({
    required this.serviceName,
    required this.methodName,
    required RpcMethodClientStreamHandler<Request, Response> handler,
    required this.argumentParser,
    this.responseParser,
    this.methodContract,
  })  : methodType = RpcMethodType.clientStreaming,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = handler,
        _bidirectionalHandler = null,
        _logger = RpcLogger('$serviceName.$methodName.registry');

  /// Создает регистрацию метода двунаправленного стриминга
  MethodRegistration.bidirectional({
    required this.serviceName,
    required this.methodName,
    required RpcMethodBidirectionalHandler<Request, Response> handler,
    this.argumentParser,
    this.responseParser,
    this.methodContract,
  })  : methodType = RpcMethodType.bidirectional,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = handler,
        _logger = RpcLogger('$serviceName.$methodName.registry');

  /// Выполняет унарный запрос
  Future<Response> invokeUnary(Request request) async {
    if (_unaryHandler == null) {
      throw RpcMethodInvocationException(
        'Unary handler is not defined for $serviceName.$methodName',
      );
    }

    try {
      _logger.debug('Invoking unary method $serviceName.$methodName');
      return await _unaryHandler!(request);
    } catch (e, stackTrace) {
      _logger.error('Error invoking unary method $serviceName.$methodName: $e',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Выполняет серверный стриминг запрос
  ServerStreamingBidiStream<Request, Response> invokeServerStreaming(
      Request request) {
    if (_serverStreamHandler == null) {
      throw RpcMethodInvocationException(
        'Server streaming handler is not defined for $serviceName.$methodName',
      );
    }

    _logger.debug('Invoking server streaming method $serviceName.$methodName');
    try {
      return _serverStreamHandler!(request);
    } catch (e, stackTrace) {
      _logger.error(
          'Error invoking server streaming method $serviceName.$methodName: $e',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Выполняет клиентский стриминг запрос
  ClientStreamingBidiStream<Request, Response> invokeClientStreaming() {
    if (_clientStreamHandler == null) {
      throw RpcMethodInvocationException(
        'Client streaming handler is not defined for $serviceName.$methodName',
      );
    }

    try {
      _logger
          .debug('Invoking client streaming method $serviceName.$methodName');
      return _clientStreamHandler!();
    } catch (e, stackTrace) {
      _logger.error(
          'Error invoking client streaming method $serviceName.$methodName: $e',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Выполняет двунаправленный стриминг запрос
  BidiStream<Request, Response> invokeBidirectional() {
    if (_bidirectionalHandler == null) {
      throw RpcMethodInvocationException(
        'Bidirectional streaming handler is not defined for $serviceName.$methodName',
      );
    }

    try {
      _logger.debug(
          'Invoking bidirectional streaming method $serviceName.$methodName');
      return _bidirectionalHandler!();
    } catch (e, stackTrace) {
      _logger.error(
          'Error invoking bidirectional streaming method $serviceName.$methodName: $e',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Парсит аргументы запроса
  Request parseArguments(dynamic rawArguments) {
    if (argumentParser == null) {
      throw RpcSerializationException(
        customMessage:
            'Argument parser is not defined for $serviceName.$methodName',
      );
    }

    try {
      return argumentParser!(rawArguments);
    } catch (e, stackTrace) {
      _logger.error('Error parsing arguments for $serviceName.$methodName: $e',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Парсит результат
  Response? parseResponse(dynamic rawResponse) {
    if (responseParser == null) {
      // Для некоторых методов responseParser может быть null
      return null;
    }

    try {
      return responseParser!(rawResponse);
    } catch (e, stackTrace) {
      _logger.error('Error parsing response for $serviceName.$methodName: $e',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Получает обработчик метода на основе типа
  dynamic getHandler() {
    switch (methodType) {
      case RpcMethodType.unary:
        return _unaryHandler;
      case RpcMethodType.serverStreaming:
        return _serverStreamHandler;
      case RpcMethodType.clientStreaming:
        return _clientStreamHandler;
      case RpcMethodType.bidirectional:
        return _bidirectionalHandler;
    }
  }
}

/// Ошибка вызова метода RPC
class RpcMethodInvocationException implements Exception {
  final String message;

  RpcMethodInvocationException(this.message);

  @override
  String toString() => 'RpcMethodInvocationException: $message';
}

/// Класс для управления регистрацией и поиском сервисных контрактов и их методов
final class RpcMethodRegistry implements IRpcMethodRegistry {
  /// Зарегистрированные контракты сервисов
  final Map<String, OldIRpcServiceContract<IRpcSerializableMessage>>
      _contracts = {};

  /// Структурированная информация о зарегистрированных методах
  final Map<
      String,
      Map<
          String,
          MethodRegistration<IRpcSerializableMessage,
              IRpcSerializableMessage>>> _methods = {};

  /// Логгер
  final RpcLogger _logger = RpcLogger('RpcServiceRegistry');

  /// Возвращает зарегистрированный контракт сервиса по имени
  @override
  OldIRpcServiceContract<IRpcSerializableMessage>? getServiceContract(
      String serviceName) {
    return _contracts[serviceName];
  }

  /// Возвращает все зарегистрированные контракты
  @override
  Map<String, OldIRpcServiceContract<IRpcSerializableMessage>>
      getAllContracts() {
    return Map.unmodifiable(_contracts);
  }

  /// Регистрирует сервисный контракт и все его методы
  @override
  void registerContract(
      OldIRpcServiceContract<IRpcSerializableMessage> contract) {
    if (_contracts.containsKey(contract.serviceName)) {
      _logger.error(
          'Контракт сервиса ${contract.serviceName} уже зарегистрирован');
      return;
    }

    _logger.debug('Регистрация контракта: ${contract.serviceName}');
    _contracts[contract.serviceName] = contract;

    // Если контракт имеет собственный реестр, объединяем его с текущим
    if (contract is OldRpcServiceContract) {
      // Вызываем setup для инициализации всех методов
      contract.setup();

      // Объединяем реестр контракта с текущим реестром
      contract.mergeInto(this);

      // Рекурсивно регистрируем все подконтракты
      for (final subContract in contract.getSubContracts()) {
        // Избегаем повторной регистрации
        if (!_contracts.containsKey(subContract.serviceName)) {
          registerContract(subContract);
        }
      }
    } else {
      // Для обычных контрактов продолжаем использовать прежнюю логику
      contract.setup();
      _collectAndRegisterMethods(contract);
    }
  }

  /// Собирает и регистрирует все методы контракта
  void _collectAndRegisterMethods(
      OldIRpcServiceContract<IRpcSerializableMessage> contract) {
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

      // Регистрируем метод с указанием типа для правильного создания адаптера
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

    // Создаем запись о методе в реестре, если её ещё нет
    _methods.putIfAbsent(serviceName, () => {});

    // Оборачиваем обработчик в адаптер в зависимости от типа метода
    dynamic adaptedHandler = handler;

    // Ключевой момент: если обработчик уже работает с IRpcContext, мы используем адаптер,
    // а если обработчик принимает IRpcSerializableMessage, мы создаем обертку

    // Определяем тип обработчика - если у нас есть парсер, можем предположить, что это обработчик
    // напрямую работающий с объектом запроса, не с контекстом
    bool usesContextArg = false;
    if (methodType != null && argumentParser != null) {
      try {
        // Используем RpcMethodAdapterFactory для создания нужного адаптера
        switch (methodType) {
          case RpcMethodType.unary:
            adaptedHandler = RpcMethodAdapterFactory.createUnaryHandlerAdapter(
              handler,
              argumentParser as dynamic,
              'RpcMethodRegistry.registerMethod',
            );
            usesContextArg = true;
            break;
          case RpcMethodType.serverStreaming:
            adaptedHandler =
                RpcMethodAdapterFactory.createServerStreamHandlerAdapter(
              handler,
              argumentParser as dynamic,
              'RpcMethodRegistry.registerMethod',
            );
            usesContextArg = true;
            break;
          case RpcMethodType.clientStreaming:
            adaptedHandler =
                RpcMethodAdapterFactory.createClientStreamHandlerAdapter(
              handler,
            );
            usesContextArg = true;
            break;
          case RpcMethodType.bidirectional:
            adaptedHandler =
                RpcMethodAdapterFactory.createBidirectionalHandlerAdapter(
              handler,
            );
            usesContextArg = true;
            break;
        }

        _logger.debug(
            'Handler для $serviceName.$methodName обернут в адаптер для IRpcContext. Тип: $methodType');
      } catch (e, stackTrace) {
        _logger.error(
            'Ошибка при создании адаптера для $serviceName.$methodName: $e',
            error: e,
            stackTrace: stackTrace);
        // Оставляем оригинальный обработчик для дальнейшей обработки
        adaptedHandler = handler;
      }
    }

    // Безопасные обертки для парсеров
    IRpcSerializableMessage safeArgumentParser(dynamic data) {
      try {
        final result = argumentParser!(data);
        if (result is IRpcSerializableMessage) {
          return result;
        }
        _logger.error(
            'Парсер аргументов вернул неверный тип: ${result.runtimeType}');
        throw TypeError();
      } catch (e) {
        _logger.error('Ошибка в парсере аргументов: $e');
        rethrow;
      }
    }

    IRpcSerializableMessage Function(dynamic)? safeResponseParser;
    if (responseParser != null) {
      safeResponseParser = (dynamic data) {
        try {
          final result = responseParser(data);
          if (result is IRpcSerializableMessage) {
            return result;
          }
          _logger.error(
              'Парсер ответов вернул неверный тип: ${result.runtimeType}');
          throw TypeError();
        } catch (e) {
          _logger.error('Ошибка в парсере ответов: $e');
          rethrow;
        }
      };
    }

    // Создаем регистрацию используя типобезопасные конструкторы
    MethodRegistration<IRpcSerializableMessage, IRpcSerializableMessage>
        registration;

    try {
      if (usesContextArg) {
        // Особый путь для обработчиков с IRpcContext
        _logger.debug(
            'Используем адаптированный для IRpcContext обработчик для $serviceName.$methodName');

        switch (methodType ?? RpcMethodType.unary) {
          case RpcMethodType.unary:
            // Создаем обработчик, который сначала получает ответ от адаптера, затем передает его клиенту
            // Тип adaptedHandler здесь: Future<dynamic> Function(IRpcContext)
            // Преобразуем его в Future<IRpcSerializableMessage> Function(IRpcSerializableMessage)
            wrappedHandler(IRpcSerializableMessage request) async {
              // Создаем простой контекст
              final message = RpcMessage(
                type: RpcMessageType.request,
                messageId: 'adapter-${DateTime.now().millisecondsSinceEpoch}',
                serviceName: serviceName,
                methodName: methodName,
                payload: request,
              );

              try {
                final result = await adaptedHandler(message);
                if (result is IRpcSerializableMessage) {
                  return result;
                } else {
                  _logger.error(
                      'Адаптер вернул результат неверного типа: ${result.runtimeType}');
                  throw TypeError();
                }
              } catch (e, stackTrace) {
                _logger.error(
                    'Ошибка при вызове адаптера для $serviceName.$methodName: $e',
                    error: e,
                    stackTrace: stackTrace);
                rethrow;
              }
            }

            registration = MethodRegistration<IRpcSerializableMessage,
                IRpcSerializableMessage>.unary(
              serviceName: serviceName,
              methodName: methodName,
              handler: wrappedHandler,
              argumentParser: safeArgumentParser,
              responseParser: safeResponseParser!,
              methodContract: null,
            );
            break;

          case RpcMethodType.serverStreaming:
            try {
              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.serverStreaming(
                serviceName: serviceName,
                methodName: methodName,
                handler: adaptedHandler as RpcMethodServerStreamHandler<
                    IRpcSerializableMessage, IRpcSerializableMessage>,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser!,
                methodContract: null,
              );
            } catch (e) {
              _logger.debug(
                  'Обработчик $serviceName.$methodName не соответствует сигнатуре стрима: $e');
              // Оборачиваем обработчик в адаптер
              ServerStreamingBidiStream<IRpcSerializableMessage,
                  IRpcSerializableMessage> wrappedHandler(
                      IRpcSerializableMessage request) =>
                  adaptedHandler(request);

              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.serverStreaming(
                serviceName: serviceName,
                methodName: methodName,
                handler: wrappedHandler,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser!,
                methodContract: null,
              );
            }
            break;

          case RpcMethodType.clientStreaming:
            // Обертка для клиентского стрима
            wrappedHandler() {
              try {
                // Просто вызываем обработчик без аргументов
                final result = adaptedHandler();
                if (result is ClientStreamingBidiStream<IRpcSerializableMessage,
                    IRpcSerializableMessage>) {
                  return result;
                } else {
                  _logger.error(
                      'Адаптер вернул стрим неверного типа: ${result.runtimeType}');
                  throw TypeError();
                }
              } catch (e, stackTrace) {
                _logger.error(
                    'Ошибка при создании клиентского стрима для $serviceName.$methodName: $e',
                    error: e,
                    stackTrace: stackTrace);
                rethrow;
              }
            }

            registration = MethodRegistration<IRpcSerializableMessage,
                IRpcSerializableMessage>.clientStreaming(
              serviceName: serviceName,
              methodName: methodName,
              handler: wrappedHandler,
              argumentParser: safeArgumentParser,
              responseParser: safeResponseParser,
              methodContract: null,
            );
            break;

          case RpcMethodType.bidirectional:
            // Обертка для двунаправленного стрима
            wrappedHandler() {
              try {
                // Просто вызываем обработчик без аргументов, который сам должен создать и вернуть стрим
                final result = adaptedHandler();
                if (result is BidiStream<IRpcSerializableMessage,
                    IRpcSerializableMessage>) {
                  return result;
                } else {
                  _logger.error(
                      'Адаптер вернул стрим неверного типа: ${result.runtimeType}');
                  throw TypeError();
                }
              } catch (e, stackTrace) {
                _logger.error(
                    'Ошибка при создании двунаправленного стрима для $serviceName.$methodName: $e',
                    error: e,
                    stackTrace: stackTrace);
                rethrow;
              }
            }

            registration = MethodRegistration<IRpcSerializableMessage,
                IRpcSerializableMessage>.bidirectional(
              serviceName: serviceName,
              methodName: methodName,
              handler: wrappedHandler,
              argumentParser: safeArgumentParser,
              responseParser: safeResponseParser,
              methodContract: null,
            );
            break;
        }
      } else {
        // Стандартный путь для обработчиков с IRpcSerializableMessage
        _logger.debug(
            'Используем обычный обработчик для $serviceName.$methodName');

        switch (methodType ?? RpcMethodType.unary) {
          case RpcMethodType.unary:
            try {
              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.unary(
                serviceName: serviceName,
                methodName: methodName,
                handler: adaptedHandler as RpcMethodUnaryHandler<
                    IRpcSerializableMessage, IRpcSerializableMessage>,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser!,
                methodContract: null,
              );
            } catch (e) {
              _logger.debug(
                  'Обработчик $serviceName.$methodName не соответствует простой сигнатуре: $e');
              // Создаем адаптер для метода в случае ошибки
              dynamicHandler(IRpcSerializableMessage req) async {
                try {
                  return await adaptedHandler(req) as IRpcSerializableMessage;
                } catch (e) {
                  _logger.error('Ошибка при вызове обработчика: $e');
                  rethrow;
                }
              }

              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.unary(
                serviceName: serviceName,
                methodName: methodName,
                handler: dynamicHandler,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser!,
                methodContract: null,
              );
            }
            break;

          case RpcMethodType.serverStreaming:
            try {
              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.serverStreaming(
                serviceName: serviceName,
                methodName: methodName,
                handler: adaptedHandler as RpcMethodServerStreamHandler<
                    IRpcSerializableMessage, IRpcSerializableMessage>,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser!,
                methodContract: null,
              );
            } catch (e) {
              _logger.debug(
                  'Обработчик $serviceName.$methodName не соответствует сигнатуре стрима: $e');
              // Оборачиваем обработчик в адаптер
              ServerStreamingBidiStream<IRpcSerializableMessage,
                  IRpcSerializableMessage> wrappedHandler(
                      IRpcSerializableMessage request) =>
                  adaptedHandler(request);

              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.serverStreaming(
                serviceName: serviceName,
                methodName: methodName,
                handler: wrappedHandler,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser!,
                methodContract: null,
              );
            }
            break;

          case RpcMethodType.clientStreaming:
            try {
              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.clientStreaming(
                serviceName: serviceName,
                methodName: methodName,
                handler: adaptedHandler as RpcMethodClientStreamHandler<
                    IRpcSerializableMessage, IRpcSerializableMessage>,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser,
                methodContract: null,
              );
            } catch (e) {
              _logger.debug(
                  'Обработчик $serviceName.$methodName не соответствует сигнатуре клиентского стрима: $e');

              // Проверяем, не устаревшая ли это сигнатура
              try {
                final typedHandler = adaptedHandler
                    as ClientStreamingBidiStream<IRpcSerializableMessage,
                            IRpcSerializableMessage>
                        Function();
                dynamicHandler() {
                  try {
                    return typedHandler();
                  } catch (e) {
                    _logger.error('Ошибка при создании клиентского стрима: $e');
                    rethrow;
                  }
                }

                registration = MethodRegistration<IRpcSerializableMessage,
                    IRpcSerializableMessage>.clientStreaming(
                  serviceName: serviceName,
                  methodName: methodName,
                  handler: dynamicHandler,
                  argumentParser: safeArgumentParser,
                  responseParser: safeResponseParser,
                  methodContract: null,
                );
              } catch (adaptError) {
                _logger.error(
                    'Не удалось адаптировать обработчик клиентского стрима: $adaptError. Оригинальная ошибка: $e');
                rethrow;
              }
            }
            break;

          case RpcMethodType.bidirectional:
            try {
              registration = MethodRegistration<IRpcSerializableMessage,
                  IRpcSerializableMessage>.bidirectional(
                serviceName: serviceName,
                methodName: methodName,
                handler: adaptedHandler as RpcMethodBidirectionalHandler<
                    IRpcSerializableMessage, IRpcSerializableMessage>,
                argumentParser: safeArgumentParser,
                responseParser: safeResponseParser,
                methodContract: null,
              );
            } catch (e) {
              _logger.debug(
                  'Обработчик $serviceName.$methodName не соответствует сигнатуре двунаправленного стрима: $e');

              // Проверяем, не устаревшая ли это сигнатура
              try {
                final typedHandler = adaptedHandler as BidiStream<
                        IRpcSerializableMessage, IRpcSerializableMessage>
                    Function();
                dynamicHandler() {
                  try {
                    return typedHandler();
                  } catch (e) {
                    _logger.error(
                        'Ошибка при создании двунаправленного стрима: $e');
                    rethrow;
                  }
                }

                registration = MethodRegistration<IRpcSerializableMessage,
                    IRpcSerializableMessage>.bidirectional(
                  serviceName: serviceName,
                  methodName: methodName,
                  handler: dynamicHandler,
                  argumentParser: safeArgumentParser,
                  responseParser: safeResponseParser,
                  methodContract: null,
                );
              } catch (adaptError) {
                _logger.error(
                    'Не удалось адаптировать обработчик двунаправленного стрима: $adaptError. Оригинальная ошибка: $e');
                rethrow;
              }
            }
            break;
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка при создании регистрации для $serviceName.$methodName: $e',
          error: e,
          stackTrace: stackTrace);
      throw ArgumentError(
          'Не удалось создать регистрацию для метода $serviceName.$methodName: $e');
    }

    _methods[serviceName]![methodName] = registration;
    _logger.debug('Метод $serviceName.$methodName успешно зарегистрирован');
  }

  /// Регистрирует напрямую конкретный тип метода
  @override
  void registerDirectMethod<Req extends IRpcSerializableMessage,
      Resp extends IRpcSerializableMessage>({
    required String serviceName,
    required String methodName,
    required RpcMethodType methodType,
    required dynamic handler,
    required Req Function(dynamic) argumentParser,
    Resp Function(dynamic)? responseParser,
    RpcMethodContract<Req, Resp>? methodContract,
  }) {
    _logger.debug(
        'Регистрация метода $serviceName.$methodName (тип: $methodType)');

    // Создаем запись о методе в реестре, если её ещё нет
    _methods.putIfAbsent(serviceName, () => {});

    switch (methodType) {
      case RpcMethodType.unary:
        // Для унарного метода
        final unaryHandler = handler as Future<Resp> Function(Req);
        final registration = MethodRegistration<IRpcSerializableMessage,
            IRpcSerializableMessage>.unary(
          serviceName: serviceName,
          methodName: methodName,
          handler: unaryHandler as RpcMethodUnaryHandler<
              IRpcSerializableMessage, IRpcSerializableMessage>,
          argumentParser:
              argumentParser as IRpcSerializableMessage Function(dynamic),
          responseParser:
              responseParser! as IRpcSerializableMessage Function(dynamic),
          methodContract: methodContract as RpcMethodContract<
              IRpcSerializableMessage, IRpcSerializableMessage>?,
        );
        _methods[serviceName]![methodName] = registration;
        break;

      case RpcMethodType.serverStreaming:
        // Для серверного стриминга
        final streamHandler =
            handler as ServerStreamingBidiStream<Req, Resp> Function(Req);
        final registration = MethodRegistration<IRpcSerializableMessage,
            IRpcSerializableMessage>.serverStreaming(
          serviceName: serviceName,
          methodName: methodName,
          handler: streamHandler as RpcMethodServerStreamHandler<
              IRpcSerializableMessage, IRpcSerializableMessage>,
          argumentParser:
              argumentParser as IRpcSerializableMessage Function(dynamic),
          responseParser:
              responseParser! as IRpcSerializableMessage Function(dynamic),
          methodContract: methodContract as RpcMethodContract<
              IRpcSerializableMessage, IRpcSerializableMessage>?,
        );
        _methods[serviceName]![methodName] = registration;
        break;

      case RpcMethodType.clientStreaming:
        // Для клиентского стриминга
        final clientStreamHandler =
            handler as ClientStreamingBidiStream<Req, Resp> Function();
        final registration = MethodRegistration<IRpcSerializableMessage,
            IRpcSerializableMessage>.clientStreaming(
          serviceName: serviceName,
          methodName: methodName,
          handler: clientStreamHandler as RpcMethodClientStreamHandler<
              IRpcSerializableMessage, IRpcSerializableMessage>,
          argumentParser:
              argumentParser as IRpcSerializableMessage Function(dynamic),
          responseParser:
              responseParser as IRpcSerializableMessage Function(dynamic)?,
          methodContract: methodContract as RpcMethodContract<
              IRpcSerializableMessage, IRpcSerializableMessage>?,
        );
        _methods[serviceName]![methodName] = registration;
        break;

      case RpcMethodType.bidirectional:
        // Для двунаправленного стриминга
        final bidiHandler = handler as BidiStream<Req, Resp> Function();
        final registration = MethodRegistration<IRpcSerializableMessage,
            IRpcSerializableMessage>.bidirectional(
          serviceName: serviceName,
          methodName: methodName,
          handler: bidiHandler as RpcMethodBidirectionalHandler<
              IRpcSerializableMessage, IRpcSerializableMessage>,
          argumentParser:
              argumentParser as IRpcSerializableMessage Function(dynamic),
          responseParser:
              responseParser as IRpcSerializableMessage Function(dynamic)?,
          methodContract: methodContract as RpcMethodContract<
              IRpcSerializableMessage, IRpcSerializableMessage>?,
        );
        _methods[serviceName]![methodName] = registration;
        break;
    }

    _logger.debug('Метод $serviceName.$methodName успешно зарегистрирован');
  }

  /// Находит информацию о методе по имени сервиса и методу
  @override
  MethodRegistration<IRpcSerializableMessage, IRpcSerializableMessage>?
      findMethod(String serviceName, String methodName) {
    return _methods[serviceName]?[methodName];
  }

  /// Возвращает список всех зарегистрированных методов
  @override
  Iterable<MethodRegistration<IRpcSerializableMessage, IRpcSerializableMessage>>
      getAllMethods() {
    return _methods.values.expand((methods) => methods.values);
  }

  /// Возвращает список методов для конкретного сервиса
  @override
  Iterable<MethodRegistration<IRpcSerializableMessage, IRpcSerializableMessage>>
      getMethodsForService(String serviceName) {
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
    print('  • Handler: ${method.getHandler() != null ? 'Есть' : 'Нет!'}');
    print('  • ArgParser: ${method.argumentParser != null ? 'Есть' : 'Нет!'}');
    print('  • RespParser: ${method.responseParser != null ? 'Есть' : 'Нет!'}');
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

    if (contract is OldRpcServiceContract) {
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
