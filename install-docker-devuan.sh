#!/bin/bash
set -e

echo "Установка Docker и Docker Compose V2 для Devuan с runit..."

# Обновление пакетов
sudo apt update

# Установка зависимостей
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    runit-services

# Добавление GPG ключа Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Получение кодового имени Devuan -> Debian
DEVUAN_CODENAME=$(lsb_release -cs)
case $DEVUAN_CODENAME in
    chimaera) DEBIAN_CODENAME="bullseye" ;;
    daedalus) DEBIAN_CODENAME="bookworm" ;;
    excalibur) DEBIAN_CODENAME="trixie" ;;
    *) DEBIAN_CODENAME="bookworm" ;; # по умолчанию
esac

# Добавление репозитория Docker для соответствующего Debian
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $DEBIAN_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Создание runit сервиса для Docker
sudo mkdir -p /etc/sv/docker
sudo tee /etc/sv/docker/run > /dev/null << 'EOF'
#!/bin/sh
exec 2>&1
exec /usr/bin/dockerd
EOF

sudo chmod +x /etc/sv/docker/run

# Создание лог-сервиса
sudo mkdir -p /etc/sv/docker/log
sudo tee /etc/sv/docker/log/run > /dev/null << 'EOF'
#!/bin/sh
exec svlogd -tt ./
EOF

sudo chmod +x /etc/sv/docker/log/run

# Включение и запуск Docker через runit
sudo ln -sf /etc/sv/docker /etc/service/

# Ожидание запуска Docker
echo "Ожидание запуска Docker..."
sleep 5

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

# Установка Docker Compose V2
echo "Установка Docker Compose V2..."

# Определение архитектуры
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="x86_64" ;;
    aarch64) ARCH="aarch64" ;;
    armv7l) ARCH="armv7" ;;
    *) echo "Неподдерживаемая архитектура: $ARCH"; exit 1 ;;
esac

# Создание директории для плагинов
mkdir -p ~/.docker/cli-plugins/

# Получение последней версии
LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K[^"]*')

# Скачивание Docker Compose V2
curl -SL "https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-linux-${ARCH}" -o ~/.docker/cli-plugins/docker-compose

chmod +x ~/.docker/cli-plugins/docker-compose

# Установка для всех пользователей (опционально)
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo cp ~/.docker/cli-plugins/docker-compose /usr/local/lib/docker/cli-plugins/

echo ""
echo "✅ Установка завершена!"
echo ""
echo "Управление Docker через runit:"
echo "  sudo sv start docker    # запуск"
echo "  sudo sv stop docker     # остановка" 
echo "  sudo sv restart docker  # перезапуск"
echo "  sudo sv status docker   # статус"
echo ""
echo "Использование Docker Compose V2:"
echo "  docker compose up"
echo "  docker compose down"
echo ""
echo "⚠️  Перезайдите в систему или выполните 'newgrp docker' для применения прав группы"
