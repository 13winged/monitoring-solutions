FROM alpine:3.18

# Установка необходимых утилит для мониторинга
RUN apk add --no-cache \
    bash \
    netcat-openbsd \
    curl \
    openssl \
    procps

# Создание директории приложения
WORKDIR /app

# Копирование всех компонентов мониторинга
COPY port-checker/ ./port-checker/
COPY ssl-checker/ ./ssl-checker/
COPY process-monitor/ ./process-monitor/
COPY scripts/ ./scripts/

# Установка прав на выполнение для всех скриптов
RUN find . -name "*.sh" -exec chmod +x {} \;

# Настройка здоровья проверки
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Команда по умолчанию (может быть переопределена)
CMD ["bash", "-c", "echo 'Monitoring solutions container started' && sleep infinity"]
