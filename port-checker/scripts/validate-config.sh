#!/bin/bash
CONFIG_FILE=${1:-/etc/port-checker.conf}

echo "Validating configuration file: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file does not exist"
    exit 1
fi

if [ ! -s "$CONFIG_FILE" ]; then
    echo "❌ Configuration file is empty"
    exit 1
fi

# Для advanced конфигов проверяем только синтаксис, но не обязательные параметры
if [[ "$CONFIG_FILE" == *.advanced ]]; then
    echo "⚠️ Advanced config detected - skipping required parameter checks"
    
    # Проверяем только синтаксис чисел для порта и интервала
    if grep -q "^PORT=" "$CONFIG_FILE"; then
        port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2-)
        if [[ ! $port =~ ^[0-9]+$ ]]; then
            echo "❌ PORT must be a number"
            exit 1
        fi
    fi

    if grep -q "^CHECK_INTERVAL=" "$CONFIG_FILE"; then
        interval=$(grep "^CHECK_INTERVAL=" "$CONFIG_FILE" | cut -d'=' -f2-)
        if [[ ! $interval =~ ^[0-9]+$ ]]; then
            echo "❌ CHECK_INTERVAL must be a number"
            exit 1
        fi
    fi
    
    echo "✅ Advanced configuration file is valid"
    exit 0
fi

# Стандартная проверка для обычных конфигов
required_params=("HOST" "PORT")
for param in "${required_params[@]}"; do
    if ! grep -q "^$param=" "$CONFIG_FILE"; then
        echo "❌ Missing required parameter: $param"
        exit 1
    fi
done

port=$(grep "^PORT=" "$CONFIG_FILE" | cut -d'=' -f2-)
if [[ ! $port =~ ^[0-9]+$ ]]; then
    echo "❌ PORT must be a number"
    exit 1
fi

if grep -q "^CHECK_INTERVAL=" "$CONFIG_FILE"; then
    interval=$(grep "^CHECK_INTERVAL=" "$CONFIG_FILE" | cut -d'=' -f2-)
    if [[ ! $interval =~ ^[0-9]+$ ]]; then
        echo "❌ CHECK_INTERVAL must be a number"
        exit 1
    fi
fi

echo "✅ Configuration file is valid"