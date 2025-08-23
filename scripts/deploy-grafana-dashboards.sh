#!/bin/bash
# /usr/local/bin/deploy-grafana-dashboards.sh
# Скрипт для развертывания дашбордов Grafana

set -e

GRAFANA_URL="http://localhost:3000"
GRAFANA_API_KEY="${GRAFANA_API_KEY}"
DASHBOARDS_DIR="/etc/grafana/dashboards"

# Функция для импорта дашборда
import_dashboard() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)
    
    echo "Importing dashboard: $dashboard_name"
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GRAFANA_API_KEY" \
        --data-binary "@$dashboard_file" \
        "$GRAFANA_URL/api/dashboards/db" > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully imported $dashboard_name"
    else
        echo "❌ Failed to import $dashboard_name"
        return 1
    fi
}

# Основная функция
main() {
    echo "Starting Grafana dashboards deployment..."
    echo ""
    
    # Проверяем доступность Grafana
    if ! curl -s "$GRAFANA_URL/api/health" | grep -q "OK"; then
        echo "Grafana is not available at $GRAFANA_URL"
        exit 1
    fi
    
    # Проверяем наличие API ключа
    if [ -z "$GRAFANA_API_KEY" ]; then
        echo "GRAFANA_API_KEY environment variable is not set"
        exit 1
    fi
    
    # Проверяем наличие директории с дашбордами
    if [ ! -d "$DASHBOARDS_DIR" ]; then
        echo "Dashboards directory $DASHBOARDS_DIR does not exist"
        exit 1
    fi
    
    # Импортируем все дашборды
    for dashboard_file in "$DASHBOARDS_DIR"/*.json; do
        if [ -f "$dashboard_file" ]; then
            import_dashboard "$dashboard_file"
        fi
    done
    
    echo ""
    echo "Dashboard deployment completed!"
    echo "You can access Grafana at: $GRAFANA_URL"
}

# Вызываем основную функцию
main