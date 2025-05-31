# Dockerfile для сборки Linux версии RPC Dart Router
FROM dart:stable

WORKDIR /app

# Копируем только необходимые файлы для установки зависимостей
COPY pubspec.yaml pubspec.lock ./
COPY ../rpc_dart ./rpc_dart/
RUN dart pub get

# Копируем исходный код и собираем
COPY bin/ ./bin/
COPY lib/ ./lib/
RUN dart compile exe bin/rpc_dart_router.dart -o rpc_dart_router-linux

# Этап запуска (опционально)
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=0 /app/rpc_dart_router-linux .
EXPOSE 11111
CMD ["./rpc_dart_router-linux"] 