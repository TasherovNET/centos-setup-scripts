#!/bin/bash

# Функция для подтверждения действия
confirm_action() {
    local prompt="$1"
    while true; do
        read -rp "$prompt [y/n]: " answer
        case "$answer" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Пожалуйста, введите y или n.";;
        esac
    done
}

# Получение списка доступных версий Python
get_python_versions() {
    echo "Получение списка версий Python..."
    curl -s https://www.python.org/ftp/python/ | 
    grep -oP 'href="\K\d+\.\d+\.\d+/' | 
    sed 's/\///g' | 
    sort -Vr | 
    uniq -w4
}

# Проверка версии CentOS
if ! grep -qE "CentOS Linux|CentOS Stream" /etc/centos-release; then
    echo "Этот скрипт поддерживает только CentOS 7 и CentOS 9 Stream."
    exit 1
fi

# Выбор версии Python
PY_VERSIONS=$(get_python_versions)
echo "Доступные версии Python:"
echo "$PY_VERSIONS" | nl -w2 -s") "
while true; do
    read -rp "Введите номер версии Python или полную версию (например 3.9.18): " py_select
    if [[ "$py_select" =~ ^[0-9]+$ ]]; then
        PYTHON_VERSION=$(echo "$PY_VERSIONS" | sed -n "${py_select}p")
        [[ -n "$PYTHON_VERSION" ]] && break
    else
        PYTHON_VERSION=$(echo "$PY_VERSIONS" | grep -w "$py_select")
        [[ -n "$PYTHON_VERSION" ]] && break
    fi
    echo "Неверный выбор, попробуйте снова."
done

SHORT_VERSION=$(echo "$PYTHON_VERSION" | cut -d. -f1-2)
echo "Выбрана версия Python: $PYTHON_VERSION"

# Подтверждение установки CWP
if confirm_action "Установить CentOS Web Panel (CWP)?"; then
    read -rp "set-hostname:" hostname
    hostnamectl set-hostname $hostname
    yum install epel-release -y
    yum -y install wget
    yum -y update
    cd /usr/local/src
    elnum=$(source /etc/os-release && echo "${VERSION_ID%.*}")
    wget http://centos-webpanel.com/cwp-el$elnum-latest
    sh cwp-el$elnum-latest
    reboot
fi

# Подтверждение обновления системы
if confirm_action "Выполнить обновление системы?"; then
    echo "Обновление системы..."
    yum update -y
fi

# Подтверждение установки зависимостей
if confirm_action "Установить необходимые зависимости?"; then
    echo "Установка зависимостей..."
    yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make
fi

# Установка Python
if confirm_action "Установить Python $PYTHON_VERSION?"; then
    echo "Скачивание Python $PYTHON_VERSION..."
    cd /usr/src
    wget "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
    tar xzf "Python-$PYTHON_VERSION.tgz"
    cd "Python-$PYTHON_VERSION"
    
    echo "Компиляция Python..."
    ./configure --enable-optimizations
    make -j$(nproc)
    
    if confirm_action "Продолжить установку Python $PYTHON_VERSION?"; then
        make altinstall
        echo "Проверка версии Python..."
        /usr/local/bin/python${SHORT_VERSION} --version
    else
        echo "Установка Python отменена."
        exit 0
    fi
fi

# Обновление альтернатив
if confirm_action "Обновить системные альтернативы для Python?"; then
    update-alternatives --install /usr/bin/python3 python3 "/usr/local/bin/python${SHORT_VERSION}" 1
    update-alternatives --set python3 "/usr/local/bin/python${SHORT_VERSION}"
    echo "Текущая системная версия Python3:"
    python3 --version
fi

# Установка pip
if confirm_action "Установить pip для Python $SHORT_VERSION?"; then
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    "/usr/local/bin/python${SHORT_VERSION}" get-pip.py
    echo "Проверка версии pip:"
    "/usr/local/bin/pip${SHORT_VERSION}" --version
fi

echo "Установка завершена успешно!"
