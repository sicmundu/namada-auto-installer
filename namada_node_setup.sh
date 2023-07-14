#!/bin/bash

# Коды цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

NODE='namada'
GO_VERSION=1.20.5
GO_ARCHIVE=go$GO_VERSION.linux-amd64.tar.gz
NAMADA_CHAIN_ID="public-testnet-10.3718993c3648"

# Функция для отображения анимации спиннера
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

# Функция для копирования файлов с обработкой ошибок
copy_with_retry() {
    local src=$1
    local dest=$2
    local retries=5
    for ((i=1; i<=retries; i++)); do
        sudo cp $src $dest && return 0
        echo "Ошибка при копировании. Попытка $i из $retries."
        # Если файл занят, попытаемся остановить процесс, который его использует
        local pid=$(lsof -t $dest)
        if [[ -n $pid ]]; then
            echo_and_log "Остановка процесса $pid, который использует файл $dest." "${RED}"
            sudo kill $pid
            sleep 2
        fi
    done
    echo_and_log "Не удалось скопировать файл после $retries попыток." "${RED}"
    exit 1
}

# Функция для проверки и обновления protoc
check_and_update_protoc() {
    PROTOC_VERSION=$(protoc --version | awk '{print $2}' | awk -F. '{print $1}')
    REQUIRED_PROTOC_VERSION=3

    if [ -z "$PROTOC_VERSION" ]; then
        echo_and_log "Protoc не установлен. Установка..." "${BLUE}"
        update_protoc
    elif [ $PROTOC_VERSION -lt $REQUIRED_PROTOC_VERSION ]; then
        echo_and_log "Protoc установлен, но версия старая ($PROTOC_VERSION). Обновление..." "${BLUE}"
        update_protoc
    else
        echo_and_log "Protoc уже установлен и версия актуальная ($PROTOC_VERSION)." "${BLUE}"
    fi
}

# Функция для обновления protoc
update_protoc() {
    PROTOC_ZIP=protoc-3.19.1-linux-x86_64.zip
    curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.19.1/$PROTOC_ZIP
    sudo unzip -o $PROTOC_ZIP -d /usr/local bin/protoc
    sudo unzip -o $PROTOC_ZIP -d /usr/local 'include/*'
    rm -f $PROTOC_ZIP
    check_success
}

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Успешно!${NC}"
        log "Успешно!"
    else
        echo -e "${RED}Не удалось.${NC}"
        log "Не удалось. Код ошибки: $?"
        exit 1
    fi
}

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

# Обработка ошибок при выполнении команд
set -e

# Обработка сигналов
trap "echo 'Скрипт прерван пользователем.'; exit 1" SIGINT SIGTERM

echo -e "${GREEN}"
echo "┌───────────────────────────────────────────────┐"
echo "|   Добро пожаловать в скрипт настройки ноды    |"
echo "|                   Namada                      |"
echo "└───────────────────────────────────────────────┘"
echo -e "${NC}"
sleep 2

log "Начало установки.."

# ASCII Art
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

# Проверка, запущен ли скрипт с правами root
if [[ $EUID -ne 0 ]]; then
   echo_and_log "Этот скрипт должен быть запущен с правами root" "${RED}"
   sleep 2
   exit 1
fi

# Проверка, что скрипт запущен на Linux
if [[ "$(uname)" != "Linux" ]]; then
    echo_and_log "Этот скрипт должен быть запущен на системе Linux" "${RED}"
    sleep 3
    exit 1
fi

# Проверка интернет-соединения
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo_and_log "Требуется интернет-соединение, но оно недоступно." "${RED}"
    sleep 3
    exit 1
fi

# Установка зависимостей
log "Установка зависимостей..."
echo "┌───────────────────────────────────────────────┐"
echo "|            Установка зависимостей...          |"
echo "└───────────────────────────────────────────────┘"
echo -e "${NC}"
sleep 2
apt-get update
apt-get install -y make git-core libssl-dev pkg-config libclang-12-dev build-essential protobuf-compiler curl wget grep jq &

# Показать спиннер во время установки зависимостей
show_spinner $!
wait $!
check_success

# Проверка и обновление protoc
check_and_update_protoc
sleep 3

# Удаление предыдущей установки Go, если она существует
if [ -d "/usr/local/go" ]; then
    echo_and_log "Удаление предыдущей установки Go..."  "${BLUE}"
    sleep 2
    sudo rm -rf /usr/local/go
fi

# Скачивание и распаковка Go
echo "┌───────────────────────────────────────────────┐"
echo "|            Скачивание и распаковка Go         |"
echo "└───────────────────────────────────────────────┘"
echo -e "${NC}"
log "Скачивание и распаковка Go"
sleep 2
wget -O $GO_ARCHIVE https://dl.google.com/go/$GO_ARCHIVE
sudo tar -C /usr/local -xzf $GO_ARCHIVE
rm $GO_ARCHIVE

# Добавление /usr/local/go/bin в PATH
echo_and_log "Добавление /usr/local/go/bin в PATH..."  "${BLUE}"
sleep 2
echo "export PATH=\$PATH:/usr/local/go/bin" >> $HOME/.profile

# Применение изменений
source $HOME/.profile

# Проверка установки
echo "Проверка установки Go..."
sleep 2
GO_INSTALL_VERSION=$(go version)
if [[ $GO_INSTALL_VERSION == *"$GO_VERSION"* ]]; then
    echo_and_log "Go версия $GO_VERSION установлена успешно." "${GREEN}"
    sleep 2
else
    echo_and_log "Ошибка: установка Go провалилась." "${RED}"
    sleep 2
    exit 1
fi

# Установка или обновление Rust
if command -v rustup &> /dev/null; then
    echo "┌───────────────────────────────────────────────┐"
    echo "|            Обновление Rust...                 |"
    echo "└───────────────────────────────────────────────┘"
    log "Обновление Rust..."
    sleep 2
    rustup update &
else
    echo "┌───────────────────────────────────────────────┐"
    echo "|            Установка Rust...                  |"
    echo "└───────────────────────────────────────────────┘"
    log "Установка Rust..."
    sleep 2
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &
fi

# Показать спиннер во время установки/обновления Rust
show_spinner $!
wait $!
check_success
sleep 2
# Получение NAMADA_TAG из конфигурации
echo_and_log "Получение NAMADA_TAG из конфигурации GitHub..." "${BLUE}"
NAMADA_TAG=$(curl -s https://raw.githubusercontent.com/sicmundu/namada-auto-installer/main/config | grep NAMADA_TAG | cut -d '=' -f 2)
check_success
sleep 1
echo_and_log "Полученная версия Namada из конфига: ${NAMADA_TAG}" "${GREEN}"
sleep 2

# Проверяем, существует ли директория 'namada'
if [ -d "namada" ]; then
    # Если директория существует, переходим в неё
    echo_and_log "Директория 'namada' уже существует. Обновление репозитория..." "${BLUE}"
    sleep 1
    cd namada
    # Выполняем git fetch для обновления информации о репозитории
    git fetch
    # Проверяем, существует ли тег в репозитории
    if git show-ref --tags | egrep -q "refs/tags/$NAMADA_TAG$"
    then
        # Если тег существует, переключаемся на него
        git checkout $NAMADA_TAG
    else
        echo_and_log "Тег $NAMADA_TAG не найден в репозитории." "${RED}"
        exit 1
    fi
    check_success
else
    # Если директория не существует, клонируем репозиторий
    echo_and_log "Клонирование репозитория namada..." "${BLUE}"
    git clone https://github.com/anoma/namada
    check_success
    cd namada
    git checkout $NAMADA_TAG
    check_success
fi


# Переключаемся на нужную версию
echo_and_log "Переключение на версию $NAMADA_TAG..." "${BLUE}"
sleep 1
git checkout $NAMADA_TAG
check_success
sleep 2

# Проверяем существование бинарных файлов и спрашиваем пользователя, нужно ли их пересобирать
if [[ -e ./target/release/namada ]]
then
    echo_and_log "Бинарные файлы уже собраны. Собрать заново? (Y/n)" "${YELLOW}"
    while true; do
        read -p "" -n 1 -r
        echo    # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            # Если пользователь ответил 'y' или 'Y', или просто нажал enter, то пересобираем бинарные файлы
            echo "┌───────────────────────────────────────────────┐"
            echo "|           Сборка бинарных файлов...           |"
            echo "└───────────────────────────────────────────────┘"
            log "Сборка бинарных файлов..."
            sleep 2
            make build-release &
            show_spinner $!
            wait $!
            check_success
            break
        elif [[ $REPLY =~ ^[Nn]$ ]]
        then
            # Если пользователь ответил 'n' или 'N', прекращаем пересборку
            break
        else
            echo_and_log "Неизвестный ответ. Пожалуйста, ответьте 'y' или 'n'" "${RED}"
        fi
    done
fi

# Проверяем, существует ли директория 'cometbft'
if [ -d "cometbft" ]; then
    # Если директория существует, переходим в неё
    echo_and_log "Директория 'cometbft' уже существует. Обновление репозитория..." "${BLUE}"
    sleep 1
    cd cometbft
    # Выполняем git fetch для обновления информации о репозитории
    git fetch
    check_success
else
    # Если директория не существует, клонируем репозиторий
    echo_and_log "Клонирование репозитория cometbft..." "${BLUE}"
    git clone https://github.com/cometbft/cometbft.git
    check_success
    cd cometbft
    check_success
fi

# Проверяем существование CometBFT и спрашиваем пользователя, нужно ли его пересобирать
if [[ -e ./build/cometbft ]]
then
    echo -e "${YELLOW}CometBFT уже собран. Собрать заново? (Y/n)${NC}"
    while true; do
        read -p "" -n 1 -r
        echo    # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            # Если пользователь ответил 'y' или 'Y', или просто нажал enter, то пересобираем CometBFT
            echo "┌───────────────────────────────────────────────┐"
            echo "|           Сборка CometBFT...                  |"
            echo "└───────────────────────────────────────────────┘"
            log "Сборка CometBFT..."
            make build
            check_success
            sleep 2
            break
        elif [[ $REPLY =~ ^[Nn]$ ]]
        then
            # Если пользователь ответил 'n' или 'N', прекращаем пересборку
            break
        else
            echo_and_log "Неизвестный ответ. Пожалуйста, ответьте 'y' или 'n'" "${RED}"
        fi
    done
fi

# Копирование cometbft в /usr/local/bin/
echo_and_log "Копирование cometbft в /usr/local/bin/..." "${BLUE}"
copy_with_retry ./build/cometbft* /usr/local/bin/
check_success
sleep 2


# Проверка версии cometbft
echo_and_log "Проверка установки cometbft..." "${BLUE}"
sleep 1
echo_and_log "Версия CometBFT: $(cometbft version)" "${GREEN}"
check_success
cd ..
sleep 2

# Копирование бинарных файлов namada в /usr/local/bin/
echo_and_log "Копирование бинарных файлов namada в /usr/local/bin/..." "${BLUE}"
sleep 2
copy_with_retry ./target/release/namada* /usr/local/bin/
check_success
sleep 3

# Проверка версии namada
echo_and_log "Проверка версии namada..." "${BLUE}"
sleep 2
namada --version
log $(namada --version)
check_success

echo_and_log "Настройка Namada Node в качестве службы systemd..." "${BLUE}"
sleep 1

cat << EOF > $HOME/namadad.service
[Unit]
Description=Namada Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/.local/share/namada
Type=simple
ExecStart=/usr/local/bin/namada --base-dir=$HOME/.local/share/namada node ledger run
Environment=NAMADA_CMT_STDOUT=true
RemainAfterExit=no
Restart=always
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo_and_log "Перемещение файла службы в /etc/systemd/system..." "${BLUE}"
sleep 1
sudo mv $HOME/namadad.service /etc/systemd/system &
show_spinner $!
wait $!

echo_and_log "Обновление файла конфигурации systemd journald..." "${BLUE}"
sleep 1
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

echo_and_log "Перезагружаем демона systemd..." "${BLUE}"
sleep 1
sudo systemctl daemon-reload
check_success

echo_and_log "Включаем автозапуск службы namadad..." "${BLUE}"
sleep 1
sudo systemctl enable namadad
check_success


echo_and_log "Запускаем службу namadad..." "${BLUE}"
sudo systemctl restart namadad
check_success

# Присоединение клиента к сети
echo -e "${BLUE}Присоединение клиента к сети...${NC}"
cd $HOME

# Проверка существования директории
if [ -d "$HOME/.local/share/namada/${NAMADA_CHAIN_ID}" ]; then
    echo_and_log "Директория сети уже существует. Пропускаем этот шаг." "${GREEN}"
else
    namada client utils join-network --chain-id $NAMADA_CHAIN_ID
    check_success
fi

sleep 2

# Скачиваем check_ports.sh из репозитория GitHub
echo_and_log "Скачиваем check_ports.sh..." "${BLUE}"
cd $HOME
wget -q -O check_ports.sh https://raw.githubusercontent.com/sicmundu/namada-auto-installer/main/check_ports.sh
check_success
sleep 3

# Даем check_ports.sh права на выполнение
chmod +x check_ports.sh

# Спрашиваем пользователя, хочет ли он проверить порты
echo_and_log "Вы хотите проверить порты? (Для этого вам нужен будет другой сервер/компьютер)" "${BLUE}"
read -p "(y/n) " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Если пользователь ответил 'y' или 'Y', то проводим проверку портов
    echo_and_log "Запускаем скрипт проверки портов..." "${GREEN}"
    ./check_ports.sh
else
    echo_and_log "Проверка портов пропущена. Если вы захотите проверить порты в будущем, запустите файл check_ports.sh." "${BLUE}"
fi

# Проверяем, существует ли файл с именем ноды
if [ -f node_name.txt ]; then
    # Загружаем имя ноды из файла
    NODE_NAME=$(cat node_name.txt)
    echo_and_log "Текущее имя ноды: $NODE_NAME" "${BLUE}"
    read -p "Хотите изменить имя ноды? (y/n): " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        read -p "Введите новое имя вашей ноды: " NODE_NAME
        echo $NODE_NAME > node_name.txt &
        show_spinner $!
        wait $!
        check_success
    fi
else
    # Запрашиваем имя ноды у пользователя
    read -p "Введите имя вашей ноды: " NODE_NAME
    echo $NODE_NAME > node_name.txt &
    show_spinner $!
    wait $!
    check_success
fi

# Скачиваем меню управления из репозитория GitHub
echo_and_log "Скачиваем menu.sh..." "${BLUE}"
cd $HOME
wget -q -O menu.sh https://raw.githubusercontent.com/sicmundu/namada-auto-installer/main/menu.sh
check_success
sleep 3

# Даем check_ports.sh права на выполнение
chmod +x menu.sh

echo -e "${BLUE}Вы можете запустить меню управления нодой ./menu.sh${NC}"

echo -e "${GREEN}"
echo "┌───────────────────────────────────────────────┐"
echo "|              Настройка ноды Namada            |"
echo "|                успешно завершена!             |"
echo "└───────────────────────────────────────────────┘"
echo -e "${NC}"
log "Настройка ноды Namada успешно завершена!"
