#!/bin/bash
set -e

echo "Installing ssl-checker..."
echo ""

# Создание директорий
echo "1. Creating directories..."
sudo mkdir -p /usr/local/bin
sudo mkdir -p /etc
sudo mkdir -p /var/lib/node_exporter
sudo mkdir -p /var/log

# Копирование файлов
echo "2. Copying files..."
sudo cp src/ssl-checker.sh /usr/local/bin/
sudo cp examples/ssl-checker.conf /etc/
sudo cp systemd/ssl-checker.service /etc/systemd/system/
sudo cp systemd/ssl-checker.timer /etc/systemd/system/

# Установка прав доступа
echo "3. Setting permissions..."
sudo chmod +x /usr/local/bin/ssl-checker.sh
sudo chmod 644 /etc/ssl-checker.conf
sudo chmod 644 /etc/systemd/system/ssl-checker.service
sudo chmod 644 /etc/systemd/system/ssl-checker.timer

# Создание файла логов
echo "4. Creating log file..."
sudo touch /var/log/ssl-checker.log
sudo chown root:root /var/log/ssl-checker.log
sudo chmod 644 /var/log/ssl-checker.log

# Перезагрузка systemd
echo "5. Reloading systemd..."
sudo systemctl daemon-reload

# Включение и запуск службы
echo "6. Enabling and starting service..."
sudo systemctl enable ssl-checker.timer
sudo systemctl start ssl-checker.timer

# Проверка установки
echo "7. Verifying installation..."
sudo systemctl status ssl-checker.timer --no-pager

echo ""
echo "Installation completed successfully!"