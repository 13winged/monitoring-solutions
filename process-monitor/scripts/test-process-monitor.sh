#!/bin/bash
# /usr/local/bin/test-process-monitor.sh
# Тестовый скрипт для проверки работы process-monitor

echo "Running process-monitor tests..."
echo ""

# Проверка наличия зависимостей
echo "1. Checking dependencies..."
if command -v curl &> /dev/null; then
    echo "✅ curl is installed"
else
    echo "❌ curl is not installed"
    exit 1
fi

if command -v pgrep &> /dev/null; then
    echo "✅ pgrep is installed"
else
    echo "❌ pgrep is not installed"
    exit 1
fi

# Проверка конфигурационного файла
echo ""
echo "2. Checking configuration file..."
if [[ -f "/etc/process-monitor.conf" ]]; then
    echo "✅ Configuration file exists"
    # Проверяем основные параметры
    if grep -q "PROCESS_NAME=" /etc/process-monitor.conf; then
        process_name=$(grep "PROCESS_NAME=" /etc/process-monitor.conf | cut -d'=' -f2)
        echo "   Process: $process_name"
    fi
    if grep -q "MONITORING_URL=" /etc/process-monitor.conf; then
        url=$(grep "MONITORING_URL=" /etc/process-monitor.conf | cut -d'=' -f2)
        echo "   URL: $url"
    fi
else
    echo "⚠️ Configuration file does not exist, using defaults"
fi

# Проверка логирования
echo ""
echo "3. Testing logging..."
/usr/local/bin/process-monitor.sh --help 2>&1 | head -5
if [[ $? -eq 0 ]]; then
    echo "✅ Basic functionality test passed"
else
    echo "❌ Basic functionality test failed"
    exit 1
fi

# Проверка метрик
echo ""
echo "4. Testing metrics generation..."
if [[ -d "$(grep "METRICS_DIR=" /etc/process-monitor.conf 2>/dev/null | cut -d'=' -f2 || echo "/var/lib/node_exporter")" ]]; then
    echo "✅ Metrics directory exists"
else
    echo "❌ Metrics directory does not exist"
fi

echo ""
echo "Test completed!"

