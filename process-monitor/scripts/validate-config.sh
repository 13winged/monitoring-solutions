#!/bin/bash
CONFIG_FILE=${1:-/etc/process-monitor.conf}

echo "Validating configuration file: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file does not exist"
    exit 1
fi

if [ ! -s "$CONFIG_FILE" ]; then
    echo "❌ Configuration file is empty"
    exit 1
fi

required_params=("PROCESS_NAME" "MONITORING_URL")
for param in "${required_params[@]}"; do
    if ! grep -q "^$param=" "$CONFIG_FILE"; then
        echo "❌ Missing required parameter: $param"
        exit 1
    fi
done

url=$(grep "^MONITORING_URL=" "$CONFIG_FILE" | cut -d'=' -f2-)
if [[ ! $url =~ ^https?:// ]]; then
    echo "❌ MONITORING_URL must start with http:// or https://"
    exit 1
fi

if grep -q "^AUTO_RESTART_ENABLED=" "$CONFIG_FILE"; then
    auto_restart=$(grep "^AUTO_RESTART_ENABLED=" "$CONFIG_FILE" | cut -d'=' -f2-)
    if [[ ! $auto_restart =~ ^(true|false)$ ]]; then
        echo "❌ AUTO_RESTART_ENABLED must be 'true' or 'false'"
        exit 1
    fi
fi

echo "✅ Configuration file is valid"