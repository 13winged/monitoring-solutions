# Установка и настройка системы мониторинга

Это руководство поможет вам установить и настроить систему мониторинга, включающую:
- Мониторинг процессов с автоматическим восстановлением
- Проверку доступности сетевых портов
- Визуализацию метрик через Grafana
- Сбор метрик через Prometheus и Node Exporter

## Вариант 1: Быстрая установка с Docker Compose (рекомендуется)

### Предварительные требования
- Docker Engine 20.10+
- Docker Compose 2.0+

### Шаги установки

1. **Клонирование репозитория**
   ```bash
   git clone https://github.com/your-username/monitoring-solutions.git
   cd monitoring-solutions/docker
   ```

2. **Запуск стека мониторинга**
   ```bash
   docker-compose up -d
   ```

3. **Проверка работы**
   ```bash
   docker-compose ps
   ```

4. **Доступ к интерфейсам**
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090

5. **Импорт дашбордов**
   ```bash
   # Создайте API ключ в Grafana (Configuration -> API Keys)
   export GRAFANA_API_KEY="your-api-key"
   ./scripts/deploy-grafana-dashboards.sh
   ```

## Вариант 2: Установка на существующую систему

### Предварительные требования
- Linux-система (Ubuntu/CentOS)
- Systemd
- curl, pgrep, nc (netcat)

### Установка компонентов мониторинга

1. **Установка Node Exporter**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install prometheus-node-exporter

   # CentOS/RHEL
   sudo yum install prometheus-node-exporter

   # Включение и запуск
   sudo systemctl enable node-exporter
   sudo systemctl start node-exporter
   ```

2. **Установка Process Monitor**
   ```bash
   cd monitoring-solutions/process-monitor
   sudo ./scripts/install-process-monitor.sh
   ```

3. **Установка Port Checker**
   ```bash
   cd monitoring-solutions/port-checker
   sudo ./scripts/install-port-checker.sh
   ```

4. **Настройка конфигурации**
   ```bash
   # Отредактируйте конфигурационные файлы
   sudo nano /etc/process-monitor.conf
   sudo nano /etc/port-checker.conf
   ```

5. **Перезапуск служб**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart process-monitor.timer
   sudo systemctl restart port-checker.timer
   ```

### Установка Prometheus и Grafana

1. **Установка Prometheus**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install prometheus

   # CentOS/RHEL
   sudo yum install prometheus
   ```

2. **Настройка Prometheus**
   Добавьте в `/etc/prometheus/prometheus.yml`:
   ```yaml
   scrape_configs:
     - job_name: 'node'
       static_configs:
         - targets: ['localhost:9100']
   ```

3. **Установка Grafana**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install grafana

   # CentOS/RHEL
   sudo yum install grafana
   ```

4. **Запуск служб**
   ```bash
   sudo systemctl enable prometheus grafana-server
   sudo systemctl start prometheus grafana-server
   ```

## Настройка мониторинга

### Настройка Process Monitor

1. **Редактирование конфигурации**
   ```bash
   sudo nano /etc/process-monitor.conf
   ```

2. **Пример конфигурации**
   ```ini
   PROCESS_NAME=nginx
   MONITORING_URL=https://example.com/health
   LOG_FORMAT=json
   AUTO_RESTART_ENABLED=true
   MAX_RESTART_ATTEMPTS=3
   RESTART_COMMAND=systemctl restart nginx
   ```

### Настройка Port Checker

1. **Редактирование конфигурации**
   ```bash
   sudo nano /etc/port-checker.conf
   ```

2. **Пример конфигурации**
   ```ini
   HOST=example.com
   PORT=443
   CHECK_INTERVAL=30
   ```

## Проверка установки

1. **Проверка работы Process Monitor**
   ```bash
   sudo systemctl status process-monitor.timer
   journalctl -u process-monitor.service -n 10
   tail -f /var/log/process-monitor.log
   ```

2. **Проверка работы Port Checker**
   ```bash
   sudo systemctl status port-checker.timer
   journalctl -u port-checker.service -n 10
   tail -f /var/log/port-checker.log
   ```

3. **Проверка метрик**
   ```bash
   curl http://localhost:9100/metrics | grep -E "(process_monitor|port_checker)"
   ```

## Обновление

1. **Остановка служб**
   ```bash
   sudo systemctl stop process-monitor.timer port-checker.timer
   ```

2. **Копирование новых версий**
   ```bash
   cp process-monitor.sh /usr/local/bin/
   cp port-checker.sh /usr/local/bin/
   ```

3. **Перезапуск служб**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl start process-monitor.timer port-checker.timer
   ```

## Устранение неполадок

1. **Проверка зависимостей**
   ```bash
   # Проверка наличия утилит
   command -v curl && echo "curl found" || echo "curl missing"
   command -v pgrep && echo "pgrep found" || echo "pgrep missing"
   command -v nc && echo "nc found" || echo "nc missing"
   ```

2. **Проверка прав доступа**
   ```bash
   ls -la /usr/local/bin/process-monitor.sh
   ls -la /usr/local/bin/port-checker.sh
   ls -la /var/log/process-monitor.log
   ls -la /var/log/port-checker.log
   ```

3. **Проверка конфигурации**
   ```bash
   sudo /usr/local/bin/process-monitor.sh --help
   sudo /usr/local/bin/port-checker.sh --help
   ```

## Дополнительные ресурсы

- [Документация Prometheus](https://prometheus.io/docs/)
- [Документация Grafana](https://grafana.com/docs/)
- [Документация Node Exporter](https://github.com/prometheus/node_exporter)