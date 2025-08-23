#!/bin/bash
# /usr/local/bin/ssl-checker.sh
# Демон для проверки SSL сертификатов с расширенными метриками

# Конфигурация
HOST="example.com"
PORT="443"
DAYS_WARNING=30
LOG_FILE="/var/log/ssl-checker.log"
CONFIG_FILE="/etc/ssl-checker.conf"
METRICS_DIR="/var/lib/node_exporter"
METRICS_FILE="${METRICS_DIR}/ssl-checker.prom"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ -z $key || $key =~ ^# ]] && continue
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            case $key in
                HOST) HOST="$value" ;;
                PORT) PORT="$value" ;;
                DAYS_WARNING) DAYS_WARNING="$value" ;;
                LOG_FILE) LOG_FILE="$value" ;;
                METRICS_DIR) METRICS_DIR="$value" ; METRICS_FILE="${METRICS_DIR}/ssl-checker.prom" ;;
            esac
        done < "$CONFIG_FILE"
    fi
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

get_ssl_info() {
    local host=$1
    local port=$2
    
    local ssl_output
    ssl_output=$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null)
    
    if [ -z "$ssl_output" ]; then
        return 1
    fi
    
    # Извлекаем информацию о сертификате
    local expire_date
    expire_date=$(echo "$ssl_output" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    
    local start_date
    start_date=$(echo "$ssl_output" | openssl x509 -noout -startdate 2>/dev/null | cut -d= -f2)
    
    local issuer
    issuer=$(echo "$ssl_output" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')
    
    local subject
    subject=$(echo "$ssl_output" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
    
    local serial
    serial=$(echo "$ssl_output" | openssl x509 -noout -serial 2>/dev/null | sed 's/serial=//')
    
    echo "$expire_date|$start_date|$issuer|$subject|$serial"
    return 0
}

write_metrics() {
    local result=$1
    local days_until_expire=$2
    local start_date=$3
    local issuer=$4
    local subject=$5
    local serial=$6
    
    local metrics_file="${METRICS_FILE}.$$"
    local final_metrics_file="${METRICS_FILE}"

    mkdir -p "$METRICS_DIR"
    
    # Экранируем специальные символы для Prometheus
    issuer=$(echo "$issuer" | sed 's/"/\\"/g')
    subject=$(echo "$subject" | sed 's/"/\\"/g')
    
    cat <<EOF > "$metrics_file"
# HELP ssl_certificate_expiry_days Number of days until SSL certificate expires
# TYPE ssl_certificate_expiry_days gauge
ssl_certificate_expiry_days{host="$HOST",port="$PORT"} $days_until_expire
# HELP ssl_certificate_check_result SSL certificate check result (0=valid, 1=error, 2=expired, 3=warning)
# TYPE ssl_certificate_check_result gauge
ssl_certificate_check_result{host="$HOST",port="$PORT"} $result
# HELP ssl_certificate_start_date_seconds SSL certificate start date in seconds since epoch
# TYPE ssl_certificate_start_date_seconds gauge
ssl_certificate_start_date_seconds{host="$HOST",port="$PORT",issuer="$issuer",subject="$subject",serial="$serial"} $start_date
# HELP ssl_certificate_info SSL certificate information
# TYPE ssl_certificate_info gauge
ssl_certificate_info{host="$HOST",port="$PORT",issuer="$issuer",subject="$subject",serial="$serial"} 1
EOF

    mv "$metrics_file" "$final_metrics_file" 2>/dev/null || true
}

main() {
    load_config
    
    local ssl_info
    ssl_info=$(get_ssl_info "$HOST" "$PORT")
    
    if [ $? -ne 0 ]; then
        log_message "ERROR: Could not retrieve SSL certificate for $HOST:$PORT"
        write_metrics 1 0 0 "" "" ""
        exit 1
    fi
    
    # Разбираем информацию о сертификате
    IFS='|' read -r expire_date start_date issuer subject serial <<< "$ssl_info"
    
    # Преобразуем даты в секунды с начала эпохи
    local expire_seconds
    expire_seconds=$(date -d "$expire_date" +%s 2>/dev/null)
    local start_seconds
    start_seconds=$(date -d "$start_date" +%s 2>/dev/null)
    
    if [ -z "$expire_seconds" ] || [ -z "$start_seconds" ]; then
        log_message "ERROR: Could not parse certificate dates for $HOST:$PORT"
        write_metrics 1 0 0 "$issuer" "$subject" "$serial"
        exit 1
    fi
    
    local current_seconds
    current_seconds=$(date +%s)
    local seconds_until_expire=$((expire_seconds - current_seconds))
    local days_until_expire=$((seconds_until_expire / 86400))
    
    local result=0
    if [ $days_until_expire -lt 0 ]; then
        log_message "CRITICAL: Certificate for $HOST:$PORT has expired"
        result=2
    elif [ $days_until_expire -lt $DAYS_WARNING ]; then
        log_message "WARNING: Certificate for $HOST:$PORT expires in $days_until_expire days"
        result=3
    else
        log_message "INFO: Certificate for $HOST:$PORT is valid for $days_until_expire days"
        result=0
    fi
    
    write_metrics $result $days_until_expire $start_seconds "$issuer" "$subject" "$serial"
}

main