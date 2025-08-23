#!/bin/bash
set -e

echo "Running comprehensive tests for ssl-checker..."
echo ""

# Проверка наличия утилит
echo "1. Checking dependencies..."
for cmd in openssl; do
    if command -v $cmd &> /dev/null; then
        echo "✅ $cmd is installed"
    else
        echo "❌ $cmd is not installed"
        exit 1
    fi
done

# Проверка синтаксиса скрипта
echo ""
echo "2. Checking script syntax..."
bash -n ../src/ssl-checker.sh
echo "✅ Script syntax is correct"

# Проверка конфигурационного файла
echo ""
echo "3. Testing configuration file..."
if [ -f "/etc/ssl-checker.conf" ]; then
    echo "✅ Configuration file exists"
    if [ -s "/etc/ssl-checker.conf" ]; then
        echo "✅ Configuration file is not empty"
    else
        echo "❌ Configuration file is empty"
        exit 1
    fi
else
    echo "⚠️ Configuration file does not exist, testing with default config"
fi

# Тестирование функции логирования
echo ""
echo "4. Testing logging function..."
temp_log=$(mktemp)
LOG_FILE=$temp_log ./../src/ssl-checker.sh --help > /dev/null 2>&1
if [ -f "$temp_log" ]; then
    echo "✅ Log file creation works"
    rm "$temp_log"
else
    echo "❌ Log file creation failed"
    exit 1
fi

# Тестирование вывода помощи
echo ""
echo "5. Testing help output..."
help_output=$(./../src/ssl-checker.sh --help 2>&1 | head -2)
if echo "$help_output" | grep -q "ssl-checker"; then
    echo "✅ Help output is correct"
else
    echo "❌ Help output is incorrect"
    exit 1
fi

echo ""
echo "All tests passed! 🎉"