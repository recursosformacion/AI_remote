FROM php:8.2-apache

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		libcurl4-openssl-dev \
		libzip-dev \
		libpng-dev \
		libjpeg-dev \
		libfreetype6-dev \
		unzip \
		git \
	&& rm -rf /var/lib/apt/lists/*

# Configure GD extension
RUN docker-php-ext-configure gd --with-freetype --with-jpeg

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql curl zip gd

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Enable Apache rewrite and set document root to /public
RUN a2enmod rewrite
RUN sed -ri -e 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf
RUN sed -ri 's!AllowOverride None!AllowOverride All!g' /etc/apache2/apache2.conf

WORKDIR /var/www/html

COPY . /var/www/html

# PHP upload config (baked into image - no volume mount needed)
COPY uploads.ini /usr/local/etc/php/conf.d/uploads.ini

# Create storage directory with world-writable permissions for volume mount compatibility
# and ensure all subdirectories will be writable by the web server (www-data)
RUN mkdir -p /var/www/html/storage && \
    chmod 777 /var/www/html/storage && \
    find /var/www/html/storage -type d -exec chmod 777 {} \; && \
    find /var/www/html/storage -type f -exec chmod 666 {} \;

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

EXPOSE 80
