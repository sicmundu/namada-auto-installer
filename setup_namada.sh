#!/bin/bash

# Коды цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета


# Обработка ошибок при выполнении команд
set -e

# Обработка сигналов
trap "echo 'Скрипт прерван пользователем.'; exit 1" SIGINT SIGTERM

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

# Функция для логирования
log() {
    local message="$1"
    local log_file="$HOME/${NODE}_install.log"  # Замените на имя вашего файла лога
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

# Функция для вывода и логирования сообщений
echo_and_log() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${NC}"
    log "${message}"
}

# Функция для отображения индикатора выполнения
show_spinner() {
    local -r FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local -r NUMBER_OF_FRAMES=${#FRAMES}
    local -r INTERVAL=0.1
    local -r CMDS_PID=$1

    local frame=0
    while kill -0 "$CMDS_PID" &>/dev/null; do
        echo -ne "${FRAMES:frame++%NUMBER_OF_FRAMES:1}" > /dev/tty
        sleep $INTERVAL
        echo -ne "\r" > /dev/tty
    done
}

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo_and_log "Успешно!" $GREEN
    else
        echo_and_log "Не удалось." $RED
        exit 1
    fi
}

# Функция для проверки имени ноды
check_node_name() {
    if grep -q "NODE_NAME" "$HOME/.bash_profile"; then
        # Загружаем имя ноды из файла
        NODE_NAME=$(grep "NODE_NAME" "$HOME/.bash_profile" | cut -d'=' -f2)
        echo_and_log "Текущее имя ноды: $NODE_NAME" "${BLUE}"
        read -p "Хотите изменить имя ноды? (y/n): " response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            read -p "Введите новое имя вашей ноды: " NODE_NAME
            sed -i "/NODE_NAME/c\export NODE_NAME=$NODE_NAME" "$HOME/.bash_profile" &
            show_spinner $!
            wait $!
            check_success
        fi
    else
        # Запрашиваем имя ноды у пользователя
        read -p "Введите имя вашей ноды: " NODE_NAME
        echo 'export NODE_NAME ='\"${NODE_NAME}\" >> "$HOME/.bash_profile" &
        show_spinner $!
        wait $!
        check_success
    fi

}

# Функция для проверки статуса синхронизации ноды
check_sync_status() {
    SYNC_STATUS=$(curl -s localhost:26657/status | jq .result.sync_info.catching_up)

    while [ "$SYNC_STATUS" != "false" ]; do
        echo_and_log "Нода не синхронизирована. Проверка статуса синхронизации через 60 секунд..." $YELLOW
        sleep 60 &
        show_spinner $!
        wait $!
        SYNC_STATUS=$(curl -s localhost:26657/status | jq .result.sync_info.catching_up)
    done
}

# Функция для выполнения команд
execute_commands() {
    echo_and_log "Нода синхронизирована. Выполняем следующие команды..." $GREEN
    echo_and_log "1) Создание учетной записи пользователя" $BLUE
    namada wallet address gen --alias my-account
    check_success
    echo_and_log "2) Инициализация учетной записиь валидатора" $BLUE
    namada client init-validator --alias $NODE_NAME --source my-account --commission-rate 0.1 --max-commission-rate-change 0.1
    check_success
    echo_and_log "3) Получение токенов в кране" $BLUE
    namadac transfer --token NAM --amount 1000 --source faucet --target $NODE_NAME --signer $NODE_NAME
    check_success
    echo_and_log "4) Проверка баланса" $BLUE
    namada client balance --token NAM --owner $NODE_NAME
    check_success
    echo_and_log "5) Создание связи токена с вашим валидатором" $BLUE
    namada client bond --validator $NODE_NAME --amount 1000
    check_success
}

# Вызов функций
check_node_name
check_sync_status
execute_commands
