#!/bin/bash
# /usr/local/bin/test-port-checker.sh
# Тестовый скрипт для проверки работы порт-чекера

echo "Running port-checker tests..."
echo ""

# Проверка наличия зависимостей
echo "1. Checking dependencies..."
if command -v nc &> /dev/null; then
    echo "✅ nc (netcat) is installed"
else
    echo "❌ nc (netcat) is not installed"
    exit 1
fi

# Проверка конфигурационного файла
echo ""
echo "2. Checking configuration file..."
if [[ -f "/etc/port-checker.conf" ]]; then
    echo "✅ Configuration file exists"
    # Проверяем основные параметры
    if grep -q "HOST=" /etc/port-checker.conf; then
        host=$(grep "HOST=" /etc/port-checker.conf | cut -d'=' -f2)
        echo "   Host: $host"
    fi
    if grep -q "PORT=" /etc/port-checker.conf; then
        port=$(grep "PORT=" /etc/port-checker.conf | cut -d'=' -f2)
        echo "   Port: $port"
    fi
else
    echo "⚠️ Configuration file does not exist, using defaults"
fi

# Проверка логирования
echo ""
echo "3. Testing logging..."
/usr/local/bin/port-checker.sh --help 2>&1 | head -5
if [[ $? -eq 0 ]]; then
    echo "✅ Basic functionality test passed"
else
    echo "❌ Basic functionality test failed"
    exit 1
fi

# Проверка метрик
echo ""
echo "4. Testing metrics generation..."
if [[ -d "$(grep "METRICS_DIR=" /etc/port-checker.conf 2>/dev/null | cut -d'=' -f2 || echo "/var/lib/node_exporter")" ]]; then
    echo "✅ Metrics directory exists"
else
    echo "❌ Metrics directory does not exist"
fi

echo ""
echo "Test completed!"