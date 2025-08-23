# Настройка Grafana для мониторинга

## Вариант 1: Docker Compose (рекомендуемый)

1. **Установите Docker и Docker Compose**
2. **Склонируйте репозиторий:**

```bash
   git clone https://github.com/your-username/monitoring-solutions.git
   cd monitoring-solutions/docker
```

3. **Запустите стек мониторинга:**

```bash
    docker-compose up -d
```

4. **Откройте Grafana:**

http://localhost:3000
Логин: admin
Пароль: admin

## Вариант 2: Ручная установка

### Установка Prometheus
- Скачайте и установите Prometheus
- Настройте сбор метрик с Node Exporter
- Добавьте job для сбора textfile метрик

### Установка Grafana 
- Установите Grafana
- Добавьте источник данных Prometheus
- Импортируйте дашборды из папки grafana/

### Настройка Node Exporter
- Установите Node Exporter
- Настройте сбор метрик из директории /var/lib/node_exporter
- Убедитесь, что скрипты мониторинга записывают метрики в эту директорию

### Импорт дашбордов
Автоматический импорт

```bash
export GRAFANA_API_KEY="your-api-key"
./scripts/deploy-grafana-dashboards.sh
```

### Ручной импорт
- Откройте Grafana
- Перейдите в раздел Dashboards → Import
- Загрузите JSON-файлы дашбордов из папок process-monitor/grafana/ и port-checker/grafana/

### Настройка алертинга
- Настройте Alertmanager для получения уведомлений от Prometheus
- Добавьте правила алертинга в конфигурацию Prometheus
- Настройте уведомления в Grafana (если нужно)

## Автоматическая настройка Grafana с Provisioning

Проект включает автоматическую настройку Grafana через provisioning. При запуске Docker Compose:

1. **Автоматически настраивается источник данных** Prometheus
2. **Автоматически импортируются дашборды** из папки `docker/grafana-dashboards/`
3. **Дашборды автоматически обновляются** при изменении файлов

### Ручная настройка provisioning

Если вы разворачиваете Grafana вручную:

1. Скопируйте папку `grafana-provisioning` в `/etc/grafana/provisioning`
2. Скопируйте дашборды в `/var/lib/grafana/dashboards`
3. Перезапустите Grafana

### Кастомизация дашбордов

Для изменения дашбордов:

1. Отредактируйте JSON-файлы в `docker/grafana-dashboards/`
2. Перезапустите Grafana для применения изменений
3. Изменения сохранятся даже при пересоздании контейнера

### Добавление новых дашбордов

Чтобы добавить новый дашборд:

1. Поместите JSON-файл в `docker/grafana-dashboards/`
2. Перезапустите Grafana
3. Дашборд автоматически появится в интерфейсе

Benefits of This Approach

Автоматическая настройка - Grafana автоматически настраивается при запуске
Persistent конфигурация - настройки сохраняются между перезапусками
Легкое обновление - дашборды легко обновлять через файлы
Версионность - конфигурации хранятся в git
Воспроизводимость - идентичная настройка на всех environment'ах