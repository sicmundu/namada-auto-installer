#!/bin/bash

# Коды цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

NODE=namada
METHOD=genesis
NAMADA_VERSION="namada-v0.20.0-Linux-x86_64"

# Обработка ошибок при выполнении команд
set -e

# Обработка сигналов
trap "echo 'Скрипт прерван пользователем.'; exit 1" SIGINT SIGTERM

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"
sleep 1

echo -e "${GREEN}"
cat << "EOF"
 /$$   /$$  /$$$$$$  /$$      /$$  /$$$$$$  /$$$$$$$   /$$$$$$ 
| $$$ | $$ /$$__  $$| $$$    /$$$ /$$__  $$| $$__  $$ /$$__  $$
| $$$$| $$| $$  \ $$| $$$$  /$$$$| $$  \ $$| $$  \ $$| $$  \ $$
| $$ $$ $$| $$$$$$$$| $$ $$/$$ $$| $$$$$$$$| $$  | $$| $$$$$$$$
| $$  $$$$| $$__  $$| $$  $$$| $$| $$__  $$| $$  | $$| $$__  $$
| $$\  $$$| $$  | $$| $$\  $ | $$| $$  | $$| $$  | $$| $$  | $$
| $$ \  $$| $$  | $$| $$ \/  | $$| $$  | $$| $$$$$$$/| $$  | $$
|__/  \__/|__/  |__/|__/     |__/|__/  |__/|_______/ |__/  |__/
EOF
echo -e "${NC}"
sleep 2

# Функция для логирования
log() {
    local message="$1"
    local log_file="$HOME/${NODE}_install.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

# Функция для вывода и логирования сообщений
echo_and_log() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${NC}"
    log "${message}"
}

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo_and_log "Успешно!" "$GREEN"
    else
        echo_and_log "Не удалось." "$RED"
        exit 1
    fi
}

# Запросить имя ноды у пользователя
while [ -z "$ALIAS" ]; do
    echo_and_log "Введите имя вашей ноды:" "$BLUE"
    read ALIAS
done
sleep 1

# Запросить имя пользователя на GitHub
while [ -z "$USERNAME" ]; do
    echo_and_log "Введите ваше имя пользователя на GitHub:" "$BLUE"
    read USERNAME
done
sleep 1

# Запросить персональный токен доступа на GitHub
while [ -z "$TOKEN" ]; do
    echo_and_log "Пожалуйста, создайте Personal Access Token на GitHub по адресу: https://github.com/settings/tokens?type=beta и введите его" "$BLUE"
    read TOKEN
done
sleep 1

echo_and_log "Проверка и установка пакетов.." "$BLUE"
sudo apt update
sudo apt install git wget curl
check_success
sleep 1

# Получить публичный IP-адрес
echo_and_log "Получение публичного IP..." "$BLUE"
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)
check_success
sleep 1

echo_and_log "Публичный IP - $PUBLIC_IP" "$GREEN"
sleep 1

# Скачать и распаковать Namada
echo_and_log "Скачивание и распаковка Namada..." "$BLUE"
if [ ! -f "$HOME/$NAMADA_VERSION.tar.gz" ]; then
    wget -P $HOME https://github.com/anoma/namada/releases/download/v0.20.0/$NAMADA_VERSION.tar.gz
    check_success
    sleep 1
else
    echo_and_log "Файл уже существует, пропускаем загрузку." "$YELLOW"
fi

tar -zxvf $HOME/$NAMADA_VERSION.tar.gz -C $HOME || echo_and_log "Не удалось распаковать файл. Возможно, он уже распакован." "$YELLOW"
check_success
sleep 1

# Выполнить команду init-genesis-validator
echo_and_log "Инициализация валидатора genesis..." "$BLUE"
$HOME/$NAMADA_VERSION/namada client utils init-genesis-validator --alias $ALIAS --max-commission-rate-change 0.01 --commission-rate 0.05 --net-address $PUBLIC_IP:26656
check_success
sleep 1

# Клонировать форкнутый репозиторий на GitHub
echo_and_log "Клонирование репозитория GitHub..." "$BLUE"
if [ ! -d "$HOME/namada-testnets" ]; then
    cd $HOME
    git clone https://github.com/$USERNAME/namada-testnets $HOME/namada-testnets
    check_success
else
    echo_and_log "Репозиторий уже клонирован, пропускаем этот шаг." "$YELLOW"
fi
sleep 1

# Копировать файл validator.toml в namada-public-testnet-11
echo_and_log "Копирование файла validator.toml..." "$BLUE"
cp $HOME/.local/share/namada/pre-genesis/$ALIAS/validator.toml $HOME/namada-testnets/namada-public-testnet-11/$ALIAS.toml
check_success
sleep 1

# Добавить валидатор toml на GitHub
echo_and_log "Добавление validator.toml на GitHub..." "$BLUE"
cd $HOME/namada-testnets
git config credential.helper 'store --file=.git/credentials'
echo "https://$USERNAME:$TOKEN@github.com" > .git/credentials
git add .
git commit -m "Create $ALIAS.toml"
git push origin main
check_success
sleep 1

echo_and_log "Готово! Теперь перейдите на https://github.com/$USERNAME/namada-testnets/tree/main и создайте Pull Request." "$GREEN"
