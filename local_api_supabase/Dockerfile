FROM php:8.3-cli

RUN docker-php-ext-install pdo pdo_mysql pdo_pgsql

WORKDIR /app
COPY . /app

ENV PORT=8080
EXPOSE 8080

CMD ["sh", "-c", "php -S 0.0.0.0:${PORT:-8080} -t /app"]
