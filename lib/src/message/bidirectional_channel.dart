import 'dart:async';

import '../endpoint/_index.dart';

/// Класс для удобного управления двунаправленным каналом связи
///
/// [_BidirectionalChannel] предоставляет удобный интерфейс для отправки и получения
/// сообщений через двунаправленный стрим, абстрагируя все детали низкоуровневой
/// обработки стримов.
class _BidirectionalChannel<TRequest, TResponse> {
  /// RPC-эндпоинт, через который осуществляется коммуникация
  final RpcEndpoint _endpoint;

  /// Имя сервиса
  final String _serviceName;

  /// Имя метода
  final String _methodName;

  /// Идентификатор стрима
  final String _streamId;

  /// Контроллер для отправки исходящих сообщений
  final StreamController<TRequest> _outgoingController;

  /// Стрим входящих сообщений
  final Stream<TResponse> _incomingStream;

  /// Подписка на входящие сообщения
  StreamSubscription<TResponse>? _subscription;

  /// Возвращает стрим входящих сообщений
  Stream<TResponse> get incoming => _incomingStream;

  /// Внутренний конструктор
  _BidirectionalChannel._({
    required RpcEndpoint endpoint,
    required String serviceName,
    required String methodName,
    required String streamId,
    required StreamController<TRequest> outgoingController,
    required Stream<TResponse> incomingStream,
  })  : _endpoint = endpoint,
        _serviceName = serviceName,
        _methodName = methodName,
        _streamId = streamId,
        _outgoingController = outgoingController,
        _incomingStream = incomingStream;

  /// Создает новый двунаправленный канал
  ///
  /// Этот конструктор должен использоваться только внутри библиотеки.
  /// Рекомендуется использовать методы из расширения BidirectionalRpcEndpoint.
  _BidirectionalChannel({
    required RpcEndpoint endpoint,
    required String serviceName,
    required String methodName,
    required String streamId,
    required StreamController<TRequest> outgoingController,
    required Stream<TResponse> incomingStream,
  }) : this._(
          endpoint: endpoint,
          serviceName: serviceName,
          methodName: methodName,
          streamId: streamId,
          outgoingController: outgoingController,
          incomingStream: incomingStream,
        );

  /// Отправляет сообщение через канал
  void send(TRequest message) {
    if (_outgoingController.isClosed) {
      throw StateError('Канал закрыт, отправка невозможна');
    }
    _outgoingController.add(message);
  }

  /// Подписывается на входящие сообщения
  StreamSubscription<TResponse> listen(
    void Function(TResponse message)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_subscription != null) {
      throw StateError('Уже подписан на канал');
    }

    _subscription = _incomingStream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );

    return _subscription!;
  }

  /// Закрывает канал
  Future<void> close() async {
    // Отправляем маркер завершения
    if (!_outgoingController.isClosed) {
      try {
        // Проверяем доступность транспорта перед отправкой
        if (_endpoint.isActive) {
          await _endpoint.sendStreamData(
            _streamId,
            {'_clientStreamEnd': true},
            serviceName: _serviceName,
            methodName: _methodName,
          );
        }
      } catch (e) {
        // Игнорируем ошибку если транспорт уже закрыт
      } finally {
        // В любом случае закрываем контроллер
        await _outgoingController.close();
      }
    }

    // Отменяем подписку
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Проверяет, закрыт ли канал
  bool get isClosed => _outgoingController.isClosed;
}

/// Класс для создания типизированного двунаправленного канала
class TypedBidirectionalChannel<RequestT, ResponseT>
    extends _BidirectionalChannel<RequestT, ResponseT> {
  /// Функции для парсинга запросов и ответов
  final RequestT Function(Map<String, dynamic>)? _requestParser;
  final ResponseT Function(Map<String, dynamic>)? _responseParser;

  /// Внутренний конструктор
  TypedBidirectionalChannel._({
    required RpcEndpoint endpoint,
    required String serviceName,
    required String methodName,
    required String streamId,
    required StreamController<RequestT> outgoingController,
    required Stream<ResponseT> incomingStream,
    RequestT Function(Map<String, dynamic>)? requestParser,
    ResponseT Function(Map<String, dynamic>)? responseParser,
  })  : _requestParser = requestParser,
        _responseParser = responseParser,
        super._(
          endpoint: endpoint,
          serviceName: serviceName,
          methodName: methodName,
          streamId: streamId,
          outgoingController: outgoingController,
          incomingStream: incomingStream,
        );

  /// Создает новый типизированный двунаправленный канал
  ///
  /// Этот конструктор должен использоваться только внутри библиотеки.
  /// Рекомендуется использовать методы из расширения BidirectionalRpcEndpoint.
  TypedBidirectionalChannel({
    required RpcEndpoint endpoint,
    required String serviceName,
    required String methodName,
    required String streamId,
    required StreamController<RequestT> outgoingController,
    required Stream<ResponseT> incomingStream,
    RequestT Function(Map<String, dynamic>)? requestParser,
    ResponseT Function(Map<String, dynamic>)? responseParser,
  }) : this._(
          endpoint: endpoint,
          serviceName: serviceName,
          methodName: methodName,
          streamId: streamId,
          outgoingController: outgoingController,
          incomingStream: responseParser != null
              ? incomingStream.map((data) {
                  if (data is Map<String, dynamic>) {
                    try {
                      return responseParser(data);
                    } catch (e) {
                      endpoint.sendStreamData(
                        streamId,
                        null,
                        metadata: {
                          '_error': 'Ошибка парсинга входящих данных: $e',
                          '_level': 'warning'
                        },
                        serviceName: serviceName,
                        methodName: methodName,
                      );
                      return data as ResponseT;
                    }
                  }
                  return data;
                })
              : incomingStream,
          requestParser: requestParser,
          responseParser: responseParser,
        );

  /// Отправляет сообщение через канал
  ///
  /// Преобразует сообщение в формат JSON, если оно не соответствует ожидаемому типу
  @override
  void send(RequestT message) {
    if (_outgoingController.isClosed) {
      throw StateError('Канал закрыт, отправка невозможна');
    }

    // Выполняем проверку соответствия типу
    if (message is Map<String, dynamic> && _requestParser != null) {
      try {
        // Попытка преобразовать Map в правильный тип, если это необходимо
        final typedMessage = _requestParser!(message);
        _outgoingController.add(typedMessage);
        return;
      } catch (e) {
        // Отправляем ошибку через метаданные
        _endpoint.sendStreamData(
          _streamId,
          null,
          metadata: {
            '_error': 'Не удалось преобразовать исходящее сообщение: $e',
            '_level': 'warning'
          },
          serviceName: _serviceName,
          methodName: _methodName,
        );
      }
    }

    _outgoingController.add(message);
  }

  /// Возвращает тип запроса в виде строки (для отладки)
  String get requestTypeName => RequestT.toString();

  /// Возвращает тип ответа в виде строки (для отладки)
  String get responseTypeName => ResponseT.toString();

  /// Проверяет соответствие объекта ожидаемому типу запроса
  bool isValidRequestType(dynamic obj) {
    if (obj is RequestT) return true;
    if (obj is Map<String, dynamic> && _requestParser != null) {
      try {
        _requestParser!(obj);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Проверяет соответствие объекта ожидаемому типу ответа
  bool isValidResponseType(dynamic obj) {
    if (obj is ResponseT) return true;
    if (obj is Map<String, dynamic> && _responseParser != null) {
      try {
        _responseParser!(obj);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }
}
