# Port Checker Daemon

Демон для проверки доступности порта 443 на заданных хостах с интеграцией в Prometheus.

## Особенности

- Проверка доступности портов с использованием netcat
- Логирование результатов в файл и syslog
- Генерация метрик в формате Prometheus
- Интеграция с systemd для автоматического запуска
- Гибкая конфигурация через файл настроек

## Установка

1. Клонируйте репозиторий:

```bash
   git clone https://github.com/13winged/port-checker.git
   cd port-checker
```

2. Запустите скрипт установки:

```bash
    chmod +x install-port-checker.sh
    ./install-port-checker.sh
```

3. Настройте конфигурацию в /etc/port-checker.conf

4. Проверьте установку:

```bash
test-port-checker.sh
```