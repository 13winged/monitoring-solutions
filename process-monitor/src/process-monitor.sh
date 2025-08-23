#!/bin/bash
# /usr/local/bin/process-monitor.sh
# Скрипт мониторинга процесса с автоматическим восстановлением и метриками Prometheus

# Конфигурация по умолчанию
PROCESS_NAME="test"
MONITORING_URL="https://test.com/monitoring/test/api"
LOG_FILE="/var/log/process-monitor.log"
STATE_DIR="/var/lib/process-monitor"
PREVIOUS_STATE_FILE="${STATE_DIR}/state"
METRICS_DIR="/var/lib/node_exporter"
CONFIG_FILE="/etc/process-monitor.conf"
SECRETS_DIR="/etc/process-monitor/secrets"
LOG_FORMAT="text"

# Настройки отказоустойчивости
MAX_RETRIES=3
INITIAL_RETRY_DELAY=2
CIRCUIT_BREAKER_THRESHOLD=5
CIRCUIT_BREAKER_TIMEOUT=300

# Настройки автоматического восстановления
AUTO_RESTART_ENABLED=false
MAX_RESTART_ATTEMPTS=3
RESTART_COMMAND="systemctl restart test.service"
RESTART_COOLDOWN=60

# Коды ошибок
ERR_HEALTHCHECK_FAILED=1
ERR_CURL_MISSING=2
ERR_PGREP_MISSING=3
ERR_STATE_DIR_NOT_CREATED=4
ERR_LOG_FILE_NOT_WRITABLE=5
ERR_CONFIG_INVALID=6
ERR_SECRETS_NOT_AVAILABLE=7
ERR_RESTART_FAILED=8

# Debug режим
DEBUG=${DEBUG:-false}

# Глобальные переменные
CIRCUIT_BREAKER_FILE="${STATE_DIR}/circuit_breaker"
RESTART_COUNT_FILE="${STATE_DIR}/restart_count"
LAST_RESTART_FILE="${STATE_DIR}/last_restart"

# Инициализация
START_TIME=$(date +%s)
SCRIPT_NAME=$(basename "$0")
HOSTNAME=$(hostname)

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
                PROCESS_NAME)
                    PROCESS_NAME="$value"
                    ;;
                MONITORING_URL)
                    MONITORING_URL="$value"
                    ;;
                LOG_FILE)
                    LOG_FILE="$value"
                    ;;
                LOG_FORMAT)
                    LOG_FORMAT="$value"
                    ;;
                MAX_RETRIES)
                    MAX_RETRIES="$value"
                    ;;
                AUTO_RESTART_ENABLED)
                    AUTO_RESTART_ENABLED="$value"
                    ;;
                MAX_RESTART_ATTEMPTS)
                    MAX_RESTART_ATTEMPTS="$value"
                    ;;
                RESTART_COMMAND)
                    RESTART_COMMAND="$value"
                    ;;
                RESTART_COOLDOWN)
                    RESTART_COOLDOWN="$value"
                    ;;
                METRICS_DIR)
                    METRICS_DIR="$value"
                    ;;
                SECRETS_DIR)
                    SECRETS_DIR="$value"
                    ;;
            esac
        done < "$CONFIG_FILE"
    fi
}

# Функция для логирования с поддержкой разных форматов
log_message() {
    local level="$1"
    local message="$2"
    local fields="${3:-{}}"
    
    if [[ "$LOG_FORMAT" == "json" ]]; then
        local log_entry="{\"timestamp\":\"$(date '+%Y-%m-%dT%H:%M:%S%z')\",\"level\":\"$level\",\"message\":\"$message\",\"script\":\"$SCRIPT_NAME\",\"host\":\"$HOSTNAME\",\"fields\":$fields}"
        
        if [[ "$DEBUG" == "true" ]]; then
            echo "$log_entry" | tee -a "$LOG_FILE"
        else
            echo "$log_entry" >> "$LOG_FILE"
        fi
    else
        local log_entry="$(date '+%Y-%m-%d %H:%M:%S') - $level - $message"
        
        if [[ "$fields" != "{}" ]]; then
            log_entry="$log_entry - $(echo "$fields" | sed 's/^{//;s/}$//')"
        fi
        
        if [[ "$DEBUG" == "true" ]]; then
            echo "$log_entry" | tee -a "$LOG_FILE"
        else
            echo "$log_entry" >> "$LOG_FILE"
        fi
    fi
}

# Debug logging
debug_log() {
    if [[ "$DEBUG" == "true" ]]; then
        if [[ "$LOG_FORMAT" == "json" ]]; then
            log_message "DEBUG" "$1" "$2"
        else
            if [[ -n "$2" && "$2" != "{}" ]]; then
                log_message "DEBUG" "$1 - $(echo "$2" | sed 's/^{//;s/}$//;s/":"/=/g;s/","/, /g')"
            else
                log_message "DEBUG" "$1"
            fi
        fi
    fi
}

# Comprehensive HealthCheck функция
healthcheck() {
    local exit_code=0

    # 1. Проверяем наличие утилит
    if ! command -v curl &> /dev/null; then
        log_message "ERROR" "curl is not installed" '{"error_code":2}'
        exit_code=$ERR_CURL_MISSING
    fi

    if ! command -v pgrep &> /dev/null; then
        log_message "ERROR" "pgrep is not installed" '{"error_code":3}'
        exit_code=$ERR_PGREP_MISSING
    fi

    # 2. Проверяем, что можем писать в лог-файл
    if [[ -e "$LOG_FILE" && ! -w "$LOG_FILE" ]]; then
        log_message "ERROR" "Log file exists but is not writable" "{\"file\":\"$LOG_FILE\",\"error_code\":5}"
        exit_code=$ERR_LOG_FILE_NOT_WRITABLE
    fi

    if [[ ! -e "$LOG_FILE" ]]; then
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        if [[ ! -w "$log_dir" ]]; then
            log_message "ERROR" "Log directory is not writable" "{\"directory\":\"$log_dir\",\"error_code\":5}"
            exit_code=$ERR_LOG_FILE_NOT_WRITABLE
        fi
    fi

    # 3. Проверяем, что можем создать/писать state директорию
    if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
        log_message "ERROR" "Failed to create state directory" "{\"directory\":\"$STATE_DIR\",\"error_code\":4}"
        exit_code=$ERR_STATE_DIR_NOT_CREATED
    elif [[ ! -w "$STATE_DIR" ]]; then
        log_message "ERROR" "State directory is not writable" "{\"directory\":\"$STATE_DIR\",\"error_code\":4}"
        exit_code=$ERR_STATE_DIR_NOT_CREATED
    fi

    # 4. Проверяем доступность сети
    if ! ping -c 1 -W 1 8.8.8.8 &> /dev/null; then
        log_message "WARN" "Network connectivity check failed" '{"check_type":"network_connectivity"}'
    fi

    # 5. Проверяем, что можем разрешить DNS имя мониторингового сервера
    local domain
    domain=$(echo "$MONITORING_URL" | awk -F/ '{print $3}')
    if ! getent ahosts "$domain" &> /dev/null; then
        log_message "WARN" "Cannot resolve domain" "{\"domain\":\"$domain\",\"check_type\":\"dns_resolution\"}"
    fi

    if [[ $exit_code -ne 0 ]]; then
        log_message "ERROR" "Healthcheck failed" "{\"exit_code\":$exit_code}"
    fi

    return $exit_code
}

# Функция для чтения секретов
read_secret() {
    local secret_name="$1"
    local secret_file="${SECRETS_DIR}/${secret_name}"
    local encrypted_file="${secret_file}.enc"
    
    # Попытка расшифровать с помощью sops
    if command -v sops &> /dev/null && [[ -f "$encrypted_file" ]]; then
        debug_log "Reading encrypted secret" "{\"secret\":\"$secret_name\",\"method\":\"sops\"}"
        sops --decrypt "$encrypted_file" 2>/dev/null && return 0
    fi
    
    # Fallback: читаем из обычного файла
    if [[ -f "$secret_file" ]]; then
        debug_log "Reading plaintext secret" "{\"secret\":\"$secret_name\",\"method\":\"plaintext\"}"
        cat "$secret_file" 2>/dev/null && return 0
    fi
    
    log_message "ERROR" "Secret not available" "{\"secret\":\"$secret_name\",\"error_code\":7}"
    return $ERR_SECRETS_NOT_AVAILABLE
}

# Функция для записи метрик Prometheus
write_metrics() {
    local result=$1
    local duration=$2
    local metrics_file="${METRICS_DIR}/process-monitor.prom.$$"
    local final_metrics_file="${METRICS_DIR}/process-monitor.prom"

    mkdir -p "$METRICS_DIR"
    
    # Читаем счетчик попыток перезапуска
    local restart_count=0
    if [[ -f "$RESTART_COUNT_FILE" ]]; then
        restart_count=$(cat "$RESTART_COUNT_FILE")
    fi
    
    # Читаем время последнего перезапуска
    local last_restart_time=0
    if [[ -f "$LAST_RESTART_FILE" ]]; then
        last_restart_time=$(cat "$LAST_RESTART_FILE")
    fi
    
    # Определяем текущее состояние процесса
    local process_state=0
    if is_process_running; then
        process_state=1
    fi
    
    # Определяем статус авторестарта (включен/выключен)
    local auto_restart_status=0
    if [[ "$AUTO_RESTART_ENABLED" == "true" ]]; then
        auto_restart_status=1
    fi
    
    cat <<EOF > "$metrics_file"
# HELP process_monitor_execution_result Result of script execution (0=success, 1=error)
# TYPE process_monitor_execution_result gauge
process_monitor_execution_result $result
# HELP process_monitor_execution_duration_seconds Script execution duration in seconds
# TYPE process_monitor_execution_duration_seconds gauge
process_monitor_execution_duration_seconds $duration
# HELP process_monitor_last_execution_timestamp_seconds Script last execution timestamp
# TYPE process_monitor_last_execution_timestamp_seconds gauge
process_monitor_last_execution_timestamp_seconds $(date +%s)
# HELP process_monitor_process_state Current state of monitored process (1=running, 0=not running)
# TYPE process_monitor_process_state gauge
process_monitor_process_state $process_state
# HELP process_monitor_restart_attempts_total Total number of restart attempts
# TYPE process_monitor_restart_attempts_total counter
process_monitor_restart_attempts_total $restart_count
# HELP process_monitor_auto_restart_enabled Whether auto-restart is enabled (1=enabled, 0=disabled)
# TYPE process_monitor_auto_restart_enabled gauge
process_monitor_auto_restart_enabled $auto_restart_status
# HELP process_monitor_last_restart_timestamp_seconds Timestamp of last restart attempt
# TYPE process_monitor_last_restart_timestamp_seconds gauge
process_monitor_last_restart_timestamp_seconds $last_restart_time
# HELP process_monitor_max_restart_attempts Maximum allowed restart attempts
# TYPE process_monitor_max_restart_attempts gauge
process_monitor_max_restart_attempts $MAX_RESTART_ATTEMPTS
EOF

    mv "$metrics_file" "$final_metrics_file" 2>/dev/null || true
}

# Проверяем, запущен ли процесс
is_process_running() {
    pgrep -x "$PROCESS_NAME" > /dev/null 2>&1
}

# Circuit breaker проверка
check_circuit_breaker() {
    if [[ -f "$CIRCUIT_BREAKER_FILE" ]]; then
        local breaker_time=$(cat "$CIRCUIT_BREAKER_FILE")
        local current_time=$(date +%s)
        if (( current_time - breaker_time < CIRCUIT_BREAKER_TIMEOUT )); then
            debug_log "Circuit breaker active" "{\"breaker_time\":$breaker_time,\"current_time\":$current_time,\"timeout\":$CIRCUIT_BREAKER_TIMEOUT}"
            return 1
        else
            debug_log "Circuit breaker timeout expired, resetting" "{\"breaker_time\":$breaker_time,\"current_time\":$current_time}"
            rm -f "$CIRCUIT_BREAKER_FILE"
        fi
    fi
    return 0
}

# Активация circuit breaker
trigger_circuit_breaker() {
    echo $(date +%s) > "$CIRCUIT_BREAKER_FILE"
    log_message "WARN" "Circuit breaker activated" "{\"threshold\":$CIRCUIT_BREAKER_THRESHOLD,\"timeout\":$CIRCUIT_BREAKER_TIMEOUT}"
}

# Retry механизм для HTTPS запросов
ping_server_with_retry() {
    local max_retries=$MAX_RETRIES
    local retry_delay=$INITIAL_RETRY_DELAY
    local attempt=1
    local result=1
    
    # Проверяем circuit breaker
    if ! check_circuit_breaker; then
        log_message "WARN" "Skipping server ping due to active circuit breaker" '{}'
        return 1
    fi
    
    # Читаем секреты для аутентификации
    local api_key
    api_key=$(read_secret "api_key") || {
        log_message "ERROR" "Failed to read API key secret" '{}'
        return 1
    }
    
    while [ $attempt -le $max_retries ]; do
        debug_log "Attempting server ping" "{\"attempt\":$attempt,\"max_retries\":$max_retries,\"url\":\"$MONITORING_URL\"}"
        
        local http_code
        local curl_error_file
        local curl_exit_code
        
        curl_error_file=$(mktemp)
        
        # Выполняем запрос с использованием секретов
        http_code=$(curl \
            --silent \
            --max-time 10 \
            --output /dev/null \
            --write-out '%{http_code}' \
            --cacert "${SECRETS_DIR}/ca-certificate.crt" \
            --header "Authorization: Bearer $api_key" \
            "$MONITORING_URL" 2>"$curl_error_file")
        
        curl_exit_code=$?
        
        if [[ "$http_code" =~ ^[23][0-9]{2}$ ]]; then
            debug_log "Server ping successful" "{\"attempt\":$attempt,\"http_code\":$http_code}"
            rm -f "$curl_error_file"
            result=0
            break
        else
            if [[ $curl_exit_code -ne 0 ]]; then
                log_message "WARN" "CURL error during server ping" "{\"attempt\":$attempt,\"exit_code\":$curl_exit_code,\"error\":\"$(cat "$curl_error_file")\"}"
            else
                log_message "WARN" "Server returned error HTTP code" "{\"attempt\":$attempt,\"http_code\":$http_code}"
            fi
            rm -f "$curl_error_file"
            
            if [ $attempt -lt $max_retries ]; then
                debug_log "Retrying server ping" "{\"attempt\":$attempt,\"delay\":$retry_delay}"
                sleep $retry_delay
                retry_delay=$((retry_delay * 2)) # Exponential backoff
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    # Если все попытки неуспешны, активируем circuit breaker
    if [ $result -ne 0 ]; then
        trigger_circuit_breaker
    fi
    
    return $result
}

# Функция автоматического восстановления
auto_restart_process() {
    local current_state="$1"
    
    # Если авторестарт отключен или процесс запущен, ничего не делаем
    if [[ "$AUTO_RESTART_ENABLED" != "true" || "$current_state" == "running" ]]; then
        # Сбрасываем счетчик рестартов, если процесс запущен
        if [[ "$current_state" == "running" && -f "$RESTART_COUNT_FILE" ]]; then
            echo 0 > "$RESTART_COUNT_FILE"
            debug_log "Reset restart counter" "{\"process_name\":\"$PROCESS_NAME\"}"
        fi
        return 0
    fi
    
    # Проверяем cooldown период
    local current_time=$(date +%s)
    local last_restart_time=0
    
    if [[ -f "$LAST_RESTART_FILE" ]]; then
        last_restart_time=$(cat "$LAST_RESTART_FILE")
    fi
    
    if (( current_time - last_restart_time < RESTART_COOLDOWN )); then
        debug_log "Skipping restart due to cooldown" "{\"process_name\":\"$PROCESS_NAME\",\"cooldown_remaining\":$((RESTART_COOLDOWN - (current_time - last_restart_time)))}"
        return 0
    fi
    
    # Проверяем максимальное количество попыток
    local restart_count=0
    if [[ -f "$RESTART_COUNT_FILE" ]]; then
        restart_count=$(cat "$RESTART_COUNT_FILE")
    fi
    
    if (( restart_count >= MAX_RESTART_ATTEMPTS )); then
        log_message "ERROR" "Maximum restart attempts reached" "{\"process_name\":\"$PROCESS_NAME\",\"max_attempts\":$MAX_RESTART_ATTEMPTS,\"current_attempts\":$restart_count}"
        return $ERR_RESTART_FAILED
    fi
    
    # Пытаемся перезапустить процесс
    log_message "INFO" "Attempting to restart process" "{\"process_name\":\"$PROCESS_NAME\",\"attempt\":$((restart_count + 1)),\"max_attempts\":$MAX_RESTART_ATTEMPTS,\"command\":\"$RESTART_COMMAND\"}"
    
    # Выполняем команду перезапуска
    if eval "$RESTART_COMMAND"; then
        log_message "INFO" "Process restart command executed successfully" "{\"process_name\":\"$PROCESS_NAME\",\"command\":\"$RESTART_COMMAND\"}"
        
        # Обновляем счетчик и время последнего рестарта
        echo $((restart_count + 1)) > "$RESTART_COUNT_FILE"
        echo $current_time > "$LAST_RESTART_FILE"
        
        # Даем процессу время на запуск
        sleep 5
        
        # Проверяем, запустился ли процесс
        if is_process_running; then
            log_message "INFO" "Process successfully restarted" "{\"process_name\":\"$PROCESS_NAME\"}"
            return 0
        else
            log_message "WARN" "Restart command executed but process is still not running" "{\"process_name\":\"$PROCESS_NAME\"}"
            return 1
        fi
    else
        log_message "ERROR" "Failed to execute restart command" "{\"process_name\":\"$PROCESS_NAME\",\"command\":\"$RESTART_COMMAND\"}"
        echo $((restart_count + 1)) > "$RESTART_COUNT_FILE"
        echo $current_time > "$LAST_RESTART_FILE"
        return $ERR_RESTART_FAILED
    fi
}

# Валидация конфигурации
validate_config() {
    local errors=0
    
    # Проверка URL
    if [[ ! "$MONITORING_URL" =~ ^https?:// ]]; then
        log_message "ERROR" "Invalid monitoring URL format" "{\"url\":\"$MONITORING_URL\"}"
        errors=$((errors + 1))
    fi
    
    # Проверка имени процесса
    if [[ -z "$PROCESS_NAME" || "${#PROCESS_NAME}" -gt 50 ]]; then
        log_message "ERROR" "Invalid process name" "{\"process_name\":\"$PROCESS_NAME\"}"
        errors=$((errors + 1))
    fi
    
    # Проверка формата логов
    if [[ "$LOG_FORMAT" != "text" && "$LOG_FORMAT" != "json" ]]; then
        log_message "ERROR" "Invalid log format" "{\"log_format\":\"$LOG_FORMAT\"}"
        errors=$((errors + 1))
    fi
    
    # Проверка параметров авторестарта
    if [[ "$AUTO_RESTART_ENABLED" != "true" && "$AUTO_RESTART_ENABLED" != "false" ]]; then
        log_message "ERROR" "Invalid AUTO_RESTART_ENABLED value" "{\"value\":\"$AUTO_RESTART_ENABLED\"}"
        errors=$((errors + 1))
    fi
    
    if [[ ! "$MAX_RESTART_ATTEMPTS" =~ ^[0-9]+$ || "$MAX_RESTART_ATTEMPTS" -lt 1 ]]; then
        log_message "ERROR" "Invalid MAX_RESTART_ATTEMPTS value" "{\"value\":\"$MAX_RESTART_ATTEMPTS\"}"
        errors=$((errors + 1))
    fi
    
    if [[ ! "$RESTART_COOLDOWN" =~ ^[0-9]+$ || "$RESTART_COOLDOWN" -lt 1 ]]; then
        log_message "ERROR" "Invalid RESTART_COOLDOWN value" "{\"value\":\"$RESTART_COOLDOWN\"}"
        errors=$((errors + 1))
    fi
    
    # Проверка существования конфигурационного файла
    if [[ -n "$CONFIG_FILE" && ! -f "$CONFIG_FILE" ]]; then
        log_message "WARN" "Configuration file not found" "{\"config_file\":\"$CONFIG_FILE\"}"
    fi
    
    # Проверка существования директории секретов
    if [[ ! -d "$SECRETS_DIR" ]]; then
        log_message "WARN" "Secrets directory not found" "{\"secrets_dir\":\"$SECRETS_DIR\"}"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_message "ERROR" "Configuration validation failed" "{\"error_count\":$errors}"
        return $ERR_CONFIG_INVALID
    fi
    
    debug_log "Configuration validation passed" "{}"
    return 0
}

# Основная логика
main() {
    local current_state
    local previous_state
    local start_time
    local end_time
    local duration
    local exit_code=0

    # Загружаем конфигурацию
    load_config

    # Включаем профилирование если в debug режиме
    if [[ "$DEBUG" == "true" ]]; then
        PS4='+ $(date "+%s.%N") ${BASH_SOURCE}:${LINENO}: '
        exec 3>&2 2>/tmp/process-monitor-debug.log
        set -x
    fi

    start_time=$(date +%s)

    # Валидация конфигурации
    validate_config || {
        end_time=$(date +%s)
        duration=$(($end_time - $start_time))
        write_metrics $ERR_CONFIG_INVALID $duration
        exit $ERR_CONFIG_INVALID
    }

    # Выполняем healthcheck
    if ! healthcheck; then
        end_time=$(date +%s)
        duration=$(($end_time - $start_time))
        write_metrics $ERR_HEALTHCHECK_FAILED $duration
        exit $ERR_HEALTHCHECK_FAILED
    fi

    # Определяем текущее состояние процесса
    if is_process_running; then
        current_state="running"
        debug_log "Process is running" "{\"process_name\":\"$PROCESS_NAME\"}"
    else
        current_state="not running"
        debug_log "Process is not running" "{\"process_name\":\"$PROCESS_NAME\"}"
    fi

    # Читаем предыдущее состояние из файла
    if [[ -f "$PREVIOUS_STATE_FILE" ]]; then
        previous_state=$(cat "$PREVIOUS_STATE_FILE")
        debug_log "Read previous state" "{\"previous_state\":\"$previous_state\"}"
    else
        previous_state="not running"
        debug_log "No previous state found, using default" "{\"previous_state\":\"$previous_state\"}"
    fi

    # Если процесс запущен сейчас, но не был запущен в прошлый раз - это рестарт
    if [[ "$current_state" == "running" && "$previous_state" == "not running" ]]; then
        log_message "INFO" "Process was restarted" "{\"process_name\":\"$PROCESS_NAME\",\"previous_state\":\"$previous_state\",\"current_state\":\"$current_state\"}"
    fi

    # Автоматическое восстановление (если процесс не запущен)
    if [[ "$current_state" == "not running" ]]; then
        auto_restart_process "$current_state" || {
            # Если авторестарт не удался, продолжаем выполнение
            debug_log "Auto-restart failed or was skipped" "{\"process_name\":\"$PROCESS_NAME\"}"
        }
        
        # После попытки рестарта снова проверяем состояние процесса
        if is_process_running; then
            current_state="running"
            debug_log "Process is now running after restart attempt" "{\"process_name\":\"$PROCESS_NAME\"}"
        fi
    fi

    # Если процесс запущен, стучимся на сервер
    if [[ "$current_state" == "running" ]]; then
        if ping_server_with_retry; then
            debug_log "Server ping successful" "{\"url\":\"$MONITORING_URL\"}"
        else
            log_message "ERROR" "Monitoring server is unreachable after retries" "{\"url\":\"$MONITORING_URL\",\"max_retries\":$MAX_RETRIES}"
        fi
    fi

    # Сохраняем текущее состояние для следующего запуска
    echo "$current_state" > "$PREVIOUS_STATE_FILE"
    debug_log "Saved current state" "{\"current_state\":\"$current_state\"}"

    end_time=$(date +%s)
    duration=$(($end_time - $start_time))
    write_metrics 0 $duration

    # Выключаем профилирование если в debug режиме
    if [[ "$DEBUG" == "true" ]]; then
        set +x
        exec 2>&3 3>&-
    fi
}

# Обработка сигналов для graceful shutdown
trap 'log_message "WARN" "Script interrupted" "{\"signal\":\"SIGINT\"}"; exit 1' INT
trap 'log_message "WARN" "Script terminated" "{\"signal\":\"SIGTERM\"}"; exit 1' TERM

# Вызываем main
main
exit 0