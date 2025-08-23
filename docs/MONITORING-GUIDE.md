# Руководство по мониторингу

Это руководство описывает работу системы мониторинга, включая метрики, дашборды и настройку оповещений.

## Архитектура системы мониторинга

[Processes] -> [Process Monitor] -> [Metrics] -> [Node Exporter] -> [Prometheus] -> [Grafana]
[Network]  -> [Port Checker]   -> [Metrics] -> [Node Exporter] -> [Prometheus] -> [Grafana]

## Метрики Process Monitor

### Основные метрики

1. **process_monitor_process_state**
   - Тип: Gauge
   - Описание: Состояние процесса (1 = запущен, 0 = не запущен)
   - Метки: instance (имя хоста)

2. **process_monitor_restart_attempts_total**
   - Тип: Counter
   - Описание: Общее количество попыток перезапуска
   - Метки: instance (имя хоста)

3. **process_monitor_auto_restart_enabled**
   - Тип: Gauge
   - Описание: Статус авто-перезапуска (1 = включен, 0 = выключен)
   - Метки: instance (имя хоста)

4. **process_monitor_execution_duration_seconds**
   - Тип: Gauge
   - Описание: Длительность выполнения проверки
   - Метки: instance (имя хоста)

### Пример запросов PromQL

# Текущее состояние процессов
process_monitor_process_state

# Количество перезапусков за последний час
increase(process_monitor_restart_attempts_total[1h])

# Среднее время выполнения за последние 5 минут
avg_over_time(process_monitor_execution_duration_seconds[5m])

## Метрики Port Checker

### Основные метрики

1. **port_checker_up**
   - Тип: Gauge
   - Описание: Доступность порта (1 = доступен, 0 = недоступен)
   - Метки: host, port, instance

2. **port_checker_check_duration_seconds**
   - Тип: Gauge
   - Описание: Длительность проверки порта
   - Метки: host, port, instance

3. **port_checker_last_check_timestamp_seconds**
   - Тип: Gauge
   - Описание: Время последней проверки
   - Метки: host, port, instance

### Пример запросов PromQL

# Текущая доступность портов
port_checker_up

# Время ответа портов
port_checker_check_duration_seconds

# История доступности порта 443 на example.com
port_checker_up{host="example.com", port="443"}

## Дашборды Grafana

### Process Monitor Dashboard

Панели:
1. **Process State** - текущее состояние процесса
2. **Restart Attempts** - количество попыток перезапуска
3. **Execution Duration** - время выполнения проверки
4. **Auto-Restart Status** - статус авто-перезапуска

### Port Checker Dashboard

Панели:
1. **Port Availability** - текущая доступность портов
2. **Check Duration** - время проверки портов
3. **Availability History** - история доступности

## Настройка оповещений

### Примеры правил алертинга

1. **Процесс не запущен более 5 минут**
   ```yaml
   - alert: ProcessDown
     expr: process_monitor_process_state == 0
     for: 5m
     labels:
       severity: critical
     annotations:
       summary: "Процесс {{ $labels.instance }} не запущен"
   ```

2. **Порт недоступен более 3 минут**
   ```yaml
   - alert: PortDown
     expr: port_checker_up == 0
     for: 3m
     labels:
       severity: warning
     annotations:
       summary: "Порт {{ $labels.port }} на {{ $labels.host }} недоступен"
   ```

3. **Частые перезапуски процесса**
   ```yaml
   - alert: FrequentRestarts
     expr: increase(process_monitor_restart_attempts_total[1h]) > 5
     for: 0m
     labels:
       severity: warning
     annotations:
       summary: "Частые перезапуски процесса на {{ $labels.instance }}"
   ```

### Интеграция с Alertmanager

1. **Настройка получателей**
   ```yaml
   receivers:
     - name: 'email-alerts'
       email_configs:
         - to: 'admin@example.com'
           from: 'alertmanager@example.com'
           smarthost: 'smtp.example.com:587'
           auth_username: 'alertmanager'
           auth_password: 'password'
   ```

2. **Маршрутизация оповещений**
   ```yaml
   route:
     group_by: ['alertname', 'cluster']
     group_wait: 30s
     group_interval: 5m
     repeat_interval: 1h
     receiver: 'email-alerts'
   ```

## Best Practices

### Настройка Process Monitor

1. **Выбор интервала проверки**
   - Критичные процессы: 30-60 секунд
   - Не критичные процессы: 2-5 минут

2. **Настройка авто-перезапуска**
   ```ini
   # Для критичных процессов
   AUTO_RESTART_ENABLED=true
   MAX_RESTART_ATTEMPTS=5
   RESTART_COOLDOWN=30

   # Для некритичных процессов
   AUTO_RESTART_ENABLED=false
   ```

3. **Настройка логирования**
   ```ini
   # Для продакшена
   LOG_FORMAT=json

   # Для разработки
   LOG_FORMAT=text
   ```

### Настройка Port Checker

1. **Выбор интервала проверки**
   - Критичные сервисы: 15-30 секунд
   - Не критичные сервисы: 1-2 минуты

2. **Настройка таймаутов**
   ```ini
   # Для быстрых проверок
   CHECK_INTERVAL=15

   # Для проверок с высоким временем ответа
   CHECK_INTERVAL=60
   ```

## Расширенные сценарии

### Мониторинг нескольких процессов

1. **Создание отдельных конфигураций**

   ```bash
   cp /etc/process-monitor.conf /etc/process-monitor-nginx.conf
   cp /etc/process-monitor.conf /etc/process-monitor-mysql.conf
   ```

2. **Создание отдельных служб**
   ```ini
   # /etc/systemd/system/process-monitor-nginx.service
   ExecStart=/usr/local/bin/process-monitor.sh --config /etc/process-monitor-nginx.conf
   ```

### Мониторинг нескольких портов

1. **Использование групп хостов**
   ```ini
   # /etc/port-checker.conf
   HOSTS=web1:443,web2:443,db1:5432
   CHECK_INTERVAL=30
   ```

2. **Индивидуальные настройки**
   ```ini
   # Для каждого порта отдельная конфигурация
   HOST=web1.example.com
   PORT=443
   CHECK_INTERVAL=15
   ```

## Устранение неполадок

### Общие проблемы

1. **Метрики не появляются в Prometheus**
   - Проверьте, что Node Exporter запущен
   - Проверьте права на запись в /var/lib/node_exporter
   - Проверьте конфигурацию Prometheus

2. **Процессы не перезапускаются**
   - Проверьте настройки AUTO_RESTART_ENABLED
   - Проверьте права на выполнение RESTART_COMMAND
   - Проверьте логи процесса

3. **Оповещения не работают**
   - Проверьте конфигурацию Alertmanager
   - Проверьте сетевые настройки
   - Проверьте логи Prometheus и Alertmanager

### Отладка

1. **Включение debug режима**

   ```bash
   DEBUG=true /usr/local/bin/process-monitor.sh
   DEBUG=true /usr/local/bin/port-checker.sh
   ```

2. **Проверка конфигурации**

   ```bash
      # Process Monitor
   /usr/local/bin/process-monitor.sh --validate
   ```

   ```bash
      # Port Checker
   /usr/local/bin/port-checker.sh --validate
   ```

3. **Тестирование метрик**

   ```bash
        # Проверка генерации метрик
   curl http://localhost:9100/metrics | grep -E "(process_monitor|port_checker)"
   ```

## Дополнительные ресурсы

- [Prometheus Querying](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)