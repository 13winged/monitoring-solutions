#!/bin/bash
# /usr/local/bin/install-process-monitor.sh
# Скрипт установки process-monitor

set -e

echo "Installing process-monitor..."
echo ""

# Создание директорий
echo "1. Creating directories..."
mkdir -p /usr/local/bin
mkdir -p /etc
mkdir -p /var/lib/process-monitor
mkdir -p /var/lib/node_exporter
mkdir -p /etc/process-monitor/secrets
mkdir -p /var/log

# Копирование файлов
echo "2. Copying files..."
cp process-monitor.sh /usr/local/bin/
cp process-monitor.conf /etc/
cp process-monitor.service /etc/systemd/system/
cp process-monitor.timer /etc/systemd/system/
cp test-process-monitor.sh /usr/local/bin/

# Установка прав доступа
echo "3. Setting permissions..."
chmod +x /usr/local/bin/process-monitor.sh
chmod +x /usr/local/bin/test-process-monitor.sh
chmod 644 /etc/process-monitor.conf
chmod 644 /etc/systemd/system/process-monitor.service
chmod 644 /etc/systemd/system/process-monitor.timer

# Создание файла логов
echo "4. Creating log file..."
touch /var/log/process-monitor.log
chown root:root /var/log/process-monitor.log
chmod 644 /var/log/process-monitor.log

# Перезагрузка systemd
echo "5. Reloading systemd..."
systemctl daemon-reload

# Включение и запуск службы
echo "6. Enabling and starting service..."
systemctl enable process-monitor.timer
systemctl start process-monitor.timer

# Проверка установки
echo "7. Verifying installation..."
systemctl status process-monitor.timer --no-pager

echo ""
echo "Installation completed successfully!"
echo "To test the installation, run: test-process-monitor.sh"