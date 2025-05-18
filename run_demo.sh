#!/bin/bash

# Скрипт для запуска демонстрационного сервера и клиента 
# для наглядной демонстрации работы RPC и диагностики

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Текущая директория
CURRENT_DIR=$(pwd)

# Проверяем, находимся ли мы в директории rpc_dart
if [[ "$CURRENT_DIR" != *"rpc_dart"* ]]; then
  echo -e "${RED}Ошибка: Скрипт должен запускаться из директории rpc_dart${NC}"
  exit 1
fi

echo -e "${GREEN}==========================================${NC}"
echo -e "${CYAN}Демонстрация RPC с диагностикой${NC}"
echo -e "${GREEN}==========================================${NC}"

# Функция для чистого завершения всех процессов
cleanup() {
  echo -e "\n${YELLOW}Завершение работы...${NC}"
  # Убиваем все запущенные процессы
  if [ -n "$DIAGNOSTIC_SERVICE_PID" ]; then
    kill $DIAGNOSTIC_SERVICE_PID 2>/dev/null
  fi
  if [ -n "$DEMO_SERVER_PID" ]; then
    kill $DEMO_SERVER_PID 2>/dev/null
  fi
  if [ -n "$DEMO_CLIENT_PID" ]; then
    kill $DEMO_CLIENT_PID 2>/dev/null
  fi
  exit 0
}

# Перехватываем сигнал прерывания для чистого завершения
trap cleanup SIGINT

# Проверяем, установлен ли tmux
if ! command -v tmux &> /dev/null; then
  echo -e "${YELLOW}Предупреждение: tmux не установлен. Будет использован обычный вывод.${NC}"
  USE_TMUX=false
else
  USE_TMUX=true
fi

# Запускаем диагностический сервис
echo -e "${BLUE}Запуск сервиса диагностики...${NC}"
cd "$CURRENT_DIR/rpc_dart_transports/example"
dart diagnostic_service.dart --host=localhost --port=8080 > diagnostic_service.log 2>&1 &
DIAGNOSTIC_SERVICE_PID=$!
sleep 2

# Проверяем, запустился ли сервис диагностики
if ! ps -p $DIAGNOSTIC_SERVICE_PID > /dev/null; then
  echo -e "${RED}Не удалось запустить сервис диагностики${NC}"
  cat diagnostic_service.log
  cleanup
fi

echo -e "${GREEN}Сервис диагностики запущен (PID: $DIAGNOSTIC_SERVICE_PID)${NC}"

# Запускаем демо-сервер
echo -e "${BLUE}Запуск демо-сервера...${NC}"
cd "$CURRENT_DIR/rpc_dart_transports/example"
dart demo_server.dart --host=localhost --port=8888 --diagnostic-url=ws://localhost:8080 > demo_server.log 2>&1 &
DEMO_SERVER_PID=$!
sleep 2

# Проверяем, запустился ли демо-сервер
if ! ps -p $DEMO_SERVER_PID > /dev/null; then
  echo -e "${RED}Не удалось запустить демо-сервер${NC}"
  cat demo_server.log
  cleanup
fi

echo -e "${GREEN}Демо-сервер запущен (PID: $DEMO_SERVER_PID)${NC}"

# Запускаем демо-клиент
echo -e "${BLUE}Запуск демо-клиента...${NC}"
cd "$CURRENT_DIR/rpc_dart_transports/example"
dart demo_client.dart --server-url=ws://localhost:8888 --diagnostic-url=ws://localhost:8080 > demo_client.log 2>&1 &
DEMO_CLIENT_PID=$!
sleep 2

# Проверяем, запустился ли демо-клиент
if ! ps -p $DEMO_CLIENT_PID > /dev/null; then
  echo -e "${RED}Не удалось запустить демо-клиент${NC}"
  cat demo_client.log
  cleanup
fi

echo -e "${GREEN}Демо-клиент запущен (PID: $DEMO_CLIENT_PID)${NC}"

# В зависимости от доступности tmux, либо используем его, либо обычный хвост логов
if [ "$USE_TMUX" = true ]; then
  # Создаем новую сессию tmux
  tmux new-session -d -s "rpc_demo"
  
  # Разделяем окно на три панели
  tmux split-window -h
  tmux split-window -v
  
  # Запускаем tail в каждой панели
  tmux send-keys -t 0 "tail -f $CURRENT_DIR/rpc_dart_transports/example/diagnostic_service.log" C-m
  tmux send-keys -t 1 "tail -f $CURRENT_DIR/rpc_dart_transports/example/demo_server.log" C-m
  tmux send-keys -t 2 "tail -f $CURRENT_DIR/rpc_dart_transports/example/demo_client.log" C-m
  
  # Добавляем заголовки
  tmux select-pane -t 0
  tmux display-message -p "Диагностика"
  tmux select-pane -t 1
  tmux display-message -p "Сервер"
  tmux select-pane -t 2
  tmux display-message -p "Клиент"
  
  # Подключаемся к сессии
  echo -e "${CYAN}Запускаем tmux с логами всех компонентов${NC}"
  echo -e "${YELLOW}Для завершения нажмите Ctrl+C в этом терминале${NC}"
  tmux attach-session -t "rpc_demo"
else
  # Просто выводим все логи в текущий терминал
  echo -e "${CYAN}Вывод логов всех компонентов:${NC}"
  echo -e "${YELLOW}Для завершения нажмите Ctrl+C${NC}"
  
  # Создаем функцию для вывода логов с префиксом
  tail_with_prefix() {
    local prefix=$1
    local file=$2
    local color=$3
    tail -f "$file" | sed "s/^/${color}[$prefix] ${NC}/"
  }
  
  # Запускаем tail для всех логов параллельно
  tail_with_prefix "ДИАГНОСТИКА" "$CURRENT_DIR/rpc_dart_transports/example/diagnostic_service.log" "${PURPLE}" &
  TAIL_DIAG_PID=$!
  
  tail_with_prefix "СЕРВЕР" "$CURRENT_DIR/rpc_dart_transports/example/demo_server.log" "${GREEN}" &
  TAIL_SERVER_PID=$!
  
  tail_with_prefix "КЛИЕНТ" "$CURRENT_DIR/rpc_dart_transports/example/demo_client.log" "${CYAN}" &
  TAIL_CLIENT_PID=$!
  
  # Ждем завершения основного скрипта
  wait
fi

# Очищаем перед выходом
cleanup 