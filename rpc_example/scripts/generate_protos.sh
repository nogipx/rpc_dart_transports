#!/bin/bash

# Убедимся, что мы находимся в корневой директории проекта
cd "$(dirname "$0")/.."

# Создаем директорию для сгенерированных файлов
mkdir -p lib/generated

# Запускаем protoc для генерации Dart кода
protoc --dart_out=grpc:lib/generated -Iprotos lib/protos/weather_service.proto

echo "Protobuf код успешно сгенерирован в lib/generated" 