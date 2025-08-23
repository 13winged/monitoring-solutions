#!/bin/bash
# /usr/local/bin/install-port-checker.sh
# Скрипт установки порт-чекера

set -e

echo "Installing port-checker..."
echo ""

# Создание директорий
echo "1. Creating directories..."
mkdir -p /usr/local/bin
mkdir -p /etc
mkdir -p /var/lib/node_exporter
mkdir -p /var/log

# Копирование файлов
echo "2. Copying files..."
cp port-checker.sh /usr/local/bin/
cp port-checker.conf /etc/
cp port-checker.service /etc/systemd/system/
cp port-checker.timer /etc/systemd/system/
cp test-port-checker.sh /usr/local/bin/

# Установка прав доступа
echo "3. Setting permissions..."
chmod +x /usr/local/bin/port-checker.sh
chmod +x /usr/local/bin/test-port-checker.sh
chmod 644 /etc/port-checker.conf
chmod 644 /etc/systemd/system/port-checker.service
chmod 644 /etc/systemd/system/port-checker.timer

# Создание файла логов
echo "4. Creating log file..."
touch /var/log/port-checker.log
chown root:root /var/log/port-checker.log
chmod 644 /var/log/port-checker.log

# Перезагрузка systemd
echo "5. Reloading systemd..."
systemctl daemon-reload

# Включение и запуск службы
echo "6. Enabling and starting service..."
systemctl enable port-checker.timer
systemctl start port-checker.timer

# Проверка установки
echo "7. Verifying installation..."
systemctl status port-checker.timer --no-pager

echo ""
echo "Installation completed successfully!"
echo "To test the installation, run: test-port-checker.sh"