#!/bin/bash
CONFIG_FILE=${1:-/etc/ssl-checker.conf}

echo "Validating configuration file: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file does not exist"
    exit 1
fi

if [ ! -s "$CONFIG_FILE" ]; then
    echo "❌ Configuration file is empty"
    exit 1
fi

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

if grep -q "^DAYS_WARNING=" "$CONFIG_FILE"; then
    days_warning=$(grep "^DAYS_WARNING=" "$CONFIG_FILE" | cut -d'=' -f2-)
    if [[ ! $days_warning =~ ^[0-9]+$ ]]; then
        echo "❌ DAYS_WARNING must be a number"
        exit 1
    fi
fi

echo "✅ Configuration file is valid"