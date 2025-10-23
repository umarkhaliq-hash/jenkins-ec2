FROM php:8.1-apache

# Install required PHP extensions for PrestaShop
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip \
    libpng-dev libjpeg-dev libfreetype6-dev \
    libicu-dev libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip intl xml

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Copy PrestaShop application from GitHub repo
COPY prestashop-app/ /var/www/html/

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html/ \
    && chmod -R 755 /var/www/html/

EXPOSE 80

CMD ["apache2-foreground"]