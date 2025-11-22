FROM php:8.3-fpm

# Install system dependencies, Node.js, and Nginx
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    libzip-dev \
    zip \
    unzip \
    git \
    curl \
    nginx \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd intl zip

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy composer files
COPY composer.json composer.lock ./

# Install PHP dependencies (no dev dependencies for production)
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

# Copy package files
COPY package.json package-lock.json ./

# Install Node dependencies (include devDependencies for build)
RUN npm ci

# Copy application files
COPY --chown=www-data:www-data . /var/www

# Generate optimized autoloader
RUN composer dump-autoload --optimize --classmap-authoritative

# Build assets
RUN npm run build

# Remove node_modules to reduce image size (keep package.json for reference)
RUN rm -rf node_modules

# Copy Nginx configuration
COPY nginx/conf.d/app.conf /etc/nginx/conf.d/default.conf

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set proper permissions
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage \
    && chmod -R 755 /var/www/bootstrap/cache

# Expose port 80 for HTTP (Nginx)
EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]