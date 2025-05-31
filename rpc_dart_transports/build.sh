#!/bin/bash

# Скрипт для сборки RPC Dart Router для разных платформ

set -e

echo "🚀 Собираем RPC Dart Router..."

# Создаем папку build
mkdir -p build

# Собираем для текущей платформы
echo "📦 Собираем для текущей платформы..."
dart compile exe bin/rpc_dart_router.dart -o "build/rpc_dart_router-$(uname -s | tr '[:upper:]' '[:lower:]')"

echo "✅ Сборка для текущей платформы завершена!"

# Если есть Docker, собираем Linux версию
if command -v docker &> /dev/null; then
    echo "🐳 Собираем Linux версию через Docker..."
    
    # Создаем временный Dockerfile
    cat > Dockerfile.temp << 'EOF'
FROM dart:stable

WORKDIR /app
COPY . .
RUN dart pub get
RUN dart compile exe bin/rpc_dart_router.dart -o rpc_dart_router-linux
EOF

    # Собираем образ и извлекаем бинарь
    docker build -f Dockerfile.temp -t rpc-dart-router-temp .
    docker run --rm -v "$(pwd)/build:/output" rpc-dart-router-temp cp rpc_dart_router-linux /output/
    
    # Убираем временные файлы
    rm Dockerfile.temp
    docker rmi rpc-dart-router-temp 2>/dev/null || true
    
    echo "✅ Linux версия собрана!"
else
    echo "⚠️  Docker не найден, Linux версия не собрана"
fi

echo ""
echo "📂 Собранные файлы:"
ls -lh build/

echo ""
echo "🎉 Готово! Скопируйте нужный файл на целевую платформу:"
echo "  • macOS: build/rpc_dart_router-darwin"
echo "  • Linux: build/rpc_dart_router-linux"
echo "  • Windows: собирайте на Windows машине" 