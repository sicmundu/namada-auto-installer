#!/bin/bash
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

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Успешно!${NC}"
    else
        echo -e "${RED}Не удалось.${NC}"
        exit 1
    fi
}

# Проверяем, существует ли файл с именем ноды
if [ -f node_name.txt ]; then
    # Загружаем имя ноды из файла
    NODE_NAME=$(cat node_name.txt)
    echo "Текущее имя ноды: $NODE_NAME"
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


# Функция для отображения меню
show_menu() {
    echo "Выберите действие:"
    echo "1) Создать учетную запись пользователя"
    echo "2) Инициализировать учетную запись валидатора"
    echo "3) Получить токены в кране"
    echo "4) Проверить баланс"
    echo "5) Связать токен с вашим валидатором"
    echo "6) Проверить логи узла"
    echo "7) Перезапустить узел"
    echo "8) Проверить статус узла"
    echo "9) Проверить синхронизацию узла"
    echo "10) Выход"
}

# Функция для обработки выбора пользователя
handle_choice() {
    case $1 in
        1) namada wallet address gen --alias my-account ;;
        2) namada client init-validator --alias $NODE_NAME --source my-account --commission-rate 0.1 --max-commission-rate-change 0.1 ;;
        3) namadac transfer --token NAM --amount 1000 --source faucet --target $NODE_NAME --signer $NODE_NAME ;;
        4) namada client balance --token NAM --owner $NODE_NAME ;;
        5) namada client bond --validator $NODE_NAME --amount 1000 ;;
        6) journalctl -u namadad -f -o cat ;;
        7) systemctl restart namadad ;;
        8) curl localhost:26657/status ;;
        9) curl -s localhost:26657/status | jq .result.sync_info.catching_up ;;
        10) exit 0 ;;
        *) echo "Неверный выбор. Пожалуйста, выберите действие от 1 до 10." ;;
    esac
}

# Основной цикл программы
while true; do
    show_menu
    read -p "Введите номер действия: " choice
    handle_choice $choice
done
