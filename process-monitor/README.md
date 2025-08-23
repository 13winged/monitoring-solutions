# Process Monitor with Auto-Recovery

Система мониторинга процессов с автоматическим восстановлением и интеграцией в Prometheus.

## Особенности

- Мониторинг состояния процессов с помощью pgrep
- Автоматическое восстановление упавших процессов
- Отправка HTTPS-запросов для проверки работоспособности
- Расширенное логирование в текстовом или JSON-формате
- Генерация метрик в формате Prometheus
- Отказоустойчивость (retry logic, circuit breaker)
- Гибкая конфигурация через файл настроек

## Установка

1. Клонируйте репозиторий:
```bash
   git clone https://github.com/13winged/process-monitor.git
   cd process-monitor
```

2. Запустите скрипт установки:

```bash
    chmod +x install-process-monitor.sh
    ./install-process-monitor.sh
```

3. Настройте конфигурацию в /etc/process-monitor.conf

4. Проверьте установку:

```bash
    test-process-monitor.sh
```

## Конфигурация

Основные параметры конфигурации:

- `PROCESS_NAME`: Имя процесса для мониторинга
- `MONITORING_URL`: URL для отправки healthcheck-запросов
- `LOG_FORMAT`: Формат логов (text или json)
- `AUTO_RESTART_ENABLED`: Включение автоматического восстановления
- `MAX_RESTART_ATTEMPTS`: Максимальное количество попыток перезапуска
- `RESTART_COMMAND`: Команда для перезапуска процесса
- `RESTART_COOLDOWN`: Задержка между попытками перезапуска (в секундах)
- `MAX_RETRIES`: Максимальное количество попыток отправки запроса
- `METRICS_DIR`: Директория для метрик Prometheus

## Использование

Запуск вручную:
```bash
    /usr/local/bin/process-monitor.sh
```

Просмотр логов:
```bash
    tail -f /var/log/process-monitor.log
```

Проверка статуса службы:
```bash
    systemctl status process-monitor.timer
```

## Мониторинг

Система генерирует метрики Prometheus в формате textfile:

- `process_monitor_execution_result`: Результат выполнения скрипта
- `process_monitor_execution_duration_seconds`: Длительность выполнения скрипта
- `process_monitor_process_state`: Состояние процесса (1 = запущен, 0 = не запущен)
- `process_monitor_restart_attempts_total`: Количество попыток перезапуска
- `process_monitor_auto_restart_enabled`: Статус авто-перезапуска
- `process_monitor_last_restart_timestamp_seconds`: Время последнего перезапуска
- `process_monitor_max_restart_attempts`: Максимальное количество попыток перезапуска