# RPC Dart Router - Daemon Mode

Полное руководство по использованию daemon режима RPC Dart Router в production среде.

## 🚀 Быстрый старт

### Локальное тестирование

```bash
# Запуск daemon
dart run bin/rpc_dart_router.dart --daemon-start --port 11112 --verbose

# Проверка статуса
dart run bin/rpc_dart_router.dart --daemon-status

# Перезагрузка конфигурации
dart run bin/rpc_dart_router.dart --daemon-reload

# Остановка daemon
dart run bin/rpc_dart_router.dart --daemon-stop
```

### Production установка

```bash
# Клонируем репозиторий
git clone https://github.com/nogipx/rpc_dart_transports.git
cd rpc_dart_transports

# Запускаем установку (требуются права root)
sudo bash scripts/install-production.sh

# Проверяем статус
systemctl status rpc-dart-router
```

## 📋 Команды управления

### Daemon команды

| Команда | Описание |
|---------|----------|
| `--daemon-start` | Запускает daemon в фоне |
| `--daemon-stop` | Останавливает daemon (SIGTERM → SIGKILL) |
| `--daemon-status` | Показывает детальный статус daemon |
| `--daemon-reload` | Перезагружает конфигурацию (SIGHUP) |

### Systemd команды (production)

```bash
# Управление service
systemctl start rpc-dart-router     # Запуск
systemctl stop rpc-dart-router      # Остановка
systemctl restart rpc-dart-router   # Перезапуск
systemctl reload rpc-dart-router    # Перезагрузка конфигурации
systemctl status rpc-dart-router    # Статус

# Логи
journalctl -u rpc-dart-router -f    # Следить за логами
journalctl -u rpc-dart-router -n 50 # Последние 50 строк
```

## 🔧 Конфигурация

### Примеры конфигурации

```bash
# Простой запуск с базовыми настройками
dart run bin/rpc_dart_router.dart --daemon-start

# Настройка хоста и порта
dart run bin/rpc_dart_router.dart --daemon-start --host 127.0.0.1 --port 9090

# С логированием в файл
dart run bin/rpc_dart_router.dart --daemon-start --log-file /var/log/router.log --verbose

# С мониторингом
dart run bin/rpc_dart_router.dart --daemon-start --stats --metrics --metrics-port 9090
```

### Конфигурация через CLI

Все настройки задаются через параметры командной строки:

```bash
# Базовые настройки
dart run bin/rpc_dart_router.dart \
  --host 0.0.0.0 \
  --port 8080 \
  --max-connections 10000

# Логирование
dart run bin/rpc_dart_router.dart \
  --log-level info \
  --log-file /var/log/rpc-dart-router/router.log \
  --verbose

# Мониторинг
dart run bin/rpc_dart_router.dart \
  --stats \
  --metrics \
  --metrics-port 9090

# Daemon режим
dart run bin/rpc_dart_router.dart \
  --daemon-start \
  --pid-file /var/run/rpc-dart-router/rpc_dart_router.pid

# Полная конфигурация
dart run bin/rpc_dart_router.dart \
  --daemon-start \
  --host 0.0.0.0 \
  --port 8080 \
  --max-connections 10000 \
  --log-level info \
  --log-file /var/log/rpc-dart-router/router.log \
  --stats \
  --metrics \
  --metrics-port 9090 \
  --pid-file /var/run/rpc-dart-router/rpc_dart_router.pid
```

## 📊 Мониторинг

### Статус daemon

```bash
$ dart run bin/rpc_dart_router.dart --daemon-status

✅ Daemon запущен с PID: 12345
📄 PID файл: /tmp/rpc_dart_router.pid
📝 Логи: /tmp/rpc_dart_router.log
📊 Размер лог-файла: 1.2 MB
🕐 Последнее изменение: 2025-06-14 21:30:15
📝 Последние записи лога:
   2025-06-14T21:30:15: [INFO] HTTP/2 gRPC server ready
   2025-06-14T21:30:15: [INFO] Listening on 0.0.0.0:8080
💾 Использование памяти: 267.9MB
⏱️  Время работы: 01:23:45
🔌 Открытые порты:
   • *:8080
   • *:9090
```

### Логирование

Daemon создает детальные логи:

```
2025-06-14T21:30:10: ===== RPC Dart Router Daemon Startup =====
2025-06-14T21:30:10: Version: 2.0.0
2025-06-14T21:30:10: Platform: linux x86_64
2025-06-14T21:30:10: Dart: 3.7.2
2025-06-14T21:30:10: PID: 12345
2025-06-14T21:30:10: Working Directory: /opt/rpc-dart-router
2025-06-14T21:30:10: ================================================
2025-06-14T21:30:12: [INFO] RPC Dart Router daemon starting
2025-06-14T21:30:12: [INFO] Configuration: host=0.0.0.0, port=11112
2025-06-14T21:30:12: [INFO] Log level: info
2025-06-14T21:30:15: [INFO] RPC Dart Router daemon ready
2025-06-14T21:30:15: [INFO] HTTP/2 gRPC server listening on 0.0.0.0:11112
2025-06-14T21:30:15: [INFO] Ready to accept connections
```

### Сигналы Unix

| Сигнал | Действие |
|--------|----------|
| `SIGTERM` | Graceful shutdown (10 сек таймаут) |
| `SIGKILL` | Принудительное завершение |
| `SIGHUP` | Перезагрузка конфигурации |
| `SIGUSR1` | Вывод статистики в лог |
| `SIGUSR2` | Переключение debug режима |

```bash
# Отправка сигналов вручную
kill -HUP 12345    # Перезагрузка
kill -USR1 12345   # Статистика
kill -TERM 12345   # Graceful stop
```

## 🔒 Безопасность

### Права доступа

Production установка создает:

- Пользователь: `rpc-router` (system user)
- Группа: `rpc-router`
- Домашняя директория: `/var/lib/rpc-dart-router`

### Директории и права

```
/opt/rpc-dart-router/          # 755 root:root (исполняемые файлы)
/etc/rpc-dart-router/          # 755 root:root (конфигурация)
/var/log/rpc-dart-router/      # 750 rpc-router:rpc-router (логи)
/var/run/rpc-dart-router/      # 750 rpc-router:rpc-router (PID файлы)
/var/lib/rpc-dart-router/      # 750 rpc-router:rpc-router (данные)
```

### Systemd безопасность

Service файл включает:

```ini
# Ограничения безопасности
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/rpc-dart-router /var/run/rpc-dart-router

# Capabilities
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

# Ресурсы
LimitNOFILE=65536
LimitNPROC=4096
MemoryMax=1G
CPUQuota=200%
```

## 🚨 Устранение неполадок

### Daemon не запускается

1. **Проверьте права доступа:**
   ```bash
   ls -la /tmp/rpc_dart_router.*
   ps aux | grep rpc_dart_router
   ```

2. **Проверьте логи:**
   ```bash
   cat /tmp/rpc_dart_router.log
   journalctl -u rpc-dart-router -n 50
   ```

3. **Проверьте порт:**
   ```bash
   lsof -i :8080
   netstat -tlnp | grep 8080
   ```

### Daemon не останавливается

```bash
# Принудительная остановка
sudo pkill -f rpc_dart_router

# Очистка PID файла
sudo rm -f /tmp/rpc_dart_router.pid
sudo rm -f /var/run/rpc-dart-router/rpc_dart_router.pid
```

### Проблемы с памятью

```bash
# Мониторинг памяти
ps -o pid,ppid,cmd,%mem,%cpu --sort=-%mem -C dart

# Ограничение памяти в systemd
systemctl edit rpc-dart-router
# Добавить: MemoryMax=512M
```

### Отладка

```bash
# Запуск в foreground для отладки
dart run bin/rpc_dart_router.dart --port 8080 --verbose

# Включение debug логов
export ROUTER_LOG_LEVEL=debug
dart run bin/rpc_dart_router.dart --daemon-start --verbose
```

## 📈 Production рекомендации

### Мониторинг

1. **Настройте мониторинг метрик:**
   ```bash
   curl http://localhost:9090/metrics
   ```

2. **Настройте алерты на:**
   - Использование памяти > 80%
   - CPU > 90%
   - Количество соединений > 8000
   - Ошибки в логах

3. **Логирование:**
   - Используйте centralized logging (ELK, Loki)
   - Настройте log rotation
   - Мониторьте размер логов

### Производительность

1. **Настройте лимиты:**
   ```bash
   # /etc/security/limits.conf
   rpc-router soft nofile 65536
   rpc-router hard nofile 65536
   ```

2. **Оптимизируйте сеть:**
   ```bash
   # /etc/sysctl.conf
   net.core.somaxconn = 65536
   net.ipv4.tcp_max_syn_backlog = 65536
   ```

3. **Мониторьте метрики:**
   - Latency (p50, p95, p99)
   - Throughput (requests/sec)
   - Error rate
   - Connection count

### Backup и восстановление

```bash
# Backup конфигурации
tar -czf rpc-router-config-$(date +%Y%m%d).tar.gz \
    /etc/rpc-dart-router/ \
    /var/lib/rpc-dart-router/

# Восстановление
systemctl stop rpc-dart-router
tar -xzf rpc-router-config-20250614.tar.gz -C /
systemctl start rpc-dart-router
```

## 🔄 Обновление

```bash
# Остановка service
systemctl stop rpc-dart-router

# Backup текущей версии
cp -r /opt/rpc-dart-router /opt/rpc-dart-router.backup

# Установка новой версии
bash scripts/install-production.sh

# Проверка
systemctl status rpc-dart-router
```

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи: `journalctl -u rpc-dart-router -f`
2. Проверьте статус: `systemctl status rpc-dart-router`
3. Создайте issue с логами и конфигурацией
4. Используйте debug режим для детальной диагностики 