# 🔨 Сборка RPC Dart Router

Быстрое руководство по созданию исполняемых файлов для разных платформ.

## 🚀 GitHub Actions (Рекомендуется)

**Самый простой способ** - автоматическая сборка в облаке:

1. Перейдите в **Actions** → **"Build RPC Dart Router"**
2. Нажмите **"Run workflow"**
3. Настройте параметры:
   ```
   Version: v1.0.0
   Create release: ✅ 
   Platforms: linux-only  (для сервера)
   ```
4. Ждите 3-5 минут
5. Скачивайте готовые бинари!

## 🛠 Локальная сборка

### Быстрая сборка
```bash
cd rpc_dart_transports
./build.sh
```

### Ручная сборка
```bash
cd rpc_dart_transports
dart compile exe bin/rpc_dart_router.dart -o build/rpc_dart_router-linux
```

### Docker сборка (для Linux на Mac/Windows)
```bash
cd rpc_dart_transports
docker build -t rpc-router .
docker run --rm -v $(pwd)/build:/output rpc-router cp rpc_dart_router-linux /output/
```

## 📦 Результат

После сборки получите:
- `rpc_dart_router-linux` - для Linux серверов  
- `rpc_dart_router-macos` - для macOS
- `rpc_dart_router-windows.exe` - для Windows

Размер: ~6MB, работает без зависимостей.

## 🚀 Запуск

```bash
# Сделать исполняемым
chmod +x rpc_dart_router-linux

# Запустить
./rpc_dart_router-linux --help
./rpc_dart_router-linux --port 8080 --host 0.0.0.0
```

---

Подробная документация: [`rpc_dart_transports/README.md`](rpc_dart_transports/README.md) 