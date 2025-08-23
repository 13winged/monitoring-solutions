#!/bin/bash
# /usr/local/bin/port-checker.sh
# Демон для проверки доступности порта 443 на заданном хосте с метриками Prometheus

# Конфигурация по умолчанию
HOST="example.com"
PORT=443
CHECK_INTERVAL=60
LOG_FILE="/var/log/port-checker.log"
CONFIG_FILE="/etc/port-checker.conf"
METRICS_DIR="/var/lib/node_exporter"
METRICS_FILE="${METRICS_DIR}/port-checker.prom"

# Коды ошибок
ERR_NC_MISSING=1
ERR_METRICS_DIR_NOT_CREATED=2

# Загрузка конфигурации из файла
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Безопасная загрузка конфигурации
        while IFS='=' read -r key value; do
            # Пропускаем комментарии и пустые строки
            [[ -z $key || $key =~ ^# ]] && continue
            
            # Убираем кавычки вокруг значения
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            
            case $key in
                HOST)
                    HOST="$value"
                    ;;
                PORT)
                    PORT="$value"
                    ;;
                CHECK_INTERVAL)
                    CHECK_INTERVAL="$value"
                    ;;
                LOG_FILE)
                    LOG_FILE="$value"
                    ;;
                METRICS_DIR)
                    METRICS_DIR="$value"
                    METRICS_FILE="${METRICS_DIR}/port-checker.prom"
                    ;;
            esac
        done < "$CONFIG_FILE"
    fi
}

# Функция для логирования с timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    # Дублируем в syslog
    logger -t port-checker "$1"
}

# Функция проверки доступности порта
check_port() {
    local host=$1
    local port=$2
    
    # Используем nc для проверки доступности порта
    if nc -z -w 5 "$host" "$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Функция для записи метрик Prometheus
write_metrics() {
    local result=$1
    local duration=$2
    local metrics_file="${METRICS_FILE}.$$"
    local final_metrics_file="${METRICS_FILE}"

    mkdir -p "$METRICS_DIR"
    
    cat <<EOF > "$metrics_file"
# HELP port_checker_up Port availability check result (1 = up, 0 = down)
# TYPE port_checker_up gauge
port_checker_up{host="$HOST",port="$PORT"} $result
# HELP port_checker_last_check_timestamp_seconds Timestamp of last port check
# TYPE port_checker_last_check_timestamp_seconds gauge
port_checker_last_check_timestamp_seconds $(date +%s)
# HELP port_checker_check_duration_seconds Duration of port check in seconds
# TYPE port_checker_check_duration_seconds gauge
port_checker_check_duration_seconds $duration
EOF

    mv "$metrics_file" "$final_metrics_file" 2>/dev/null || true
}

# Проверка зависимостей
check_dependencies() {
    if ! command -v nc &> /dev/null; then
        log_message "CRITICAL ERROR: 'nc' (netcat) is not installed. Exiting."
        exit $ERR_NC_MISSING
    fi
}

# Основная функция
main() {
    local start_time
    local end_time
    local duration
    local result
    
    # Загружаем конфигурацию
    load_config
    
    # Проверяем зависимости
    check_dependencies
    
    # Создаем директорию для метрик
    if ! mkdir -p "$METRICS_DIR"; then
        log_message "ERROR: Failed to create metrics directory '$METRICS_DIR'. Exiting."
        exit $ERR_METRICS_DIR_NOT_CREATED
    fi
    
    log_message "Port checker daemon started"
    log_message "Monitoring host: $HOST, port: $PORT, interval: ${CHECK_INTERVAL}s"
    
    while true; do
        start_time=$(date +%s)
        
        if check_port "$HOST" "$PORT"; then
            result=1
            log_message "Port $PORT on $HOST is available"
        else
            result=0
            log_message "Port $PORT on $HOST is NOT available"
        fi
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        # Записываем метрики
        write_metrics $result $duration
        
        sleep "$CHECK_INTERVAL"
    done
}

# Обработка сигналов для graceful shutdown
trap 'log_message "Port checker daemon stopped"; exit 0' INT TERM

# Запуск основной функции
main