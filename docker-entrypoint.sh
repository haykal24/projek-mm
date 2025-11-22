#!/bin/bash
set -e

echo "Starting Laravel application setup..."

# Wait for database to be ready (optional, uncomment if needed)
# echo "Waiting for database..."
# while ! nc -z ${DB_HOST} ${DB_PORT}; do
#   sleep 0.1
# done
# echo "Database is ready!"

# Run migrations
echo "Running migrations..."
php artisan migrate --force

# Run seeders (creates superadmin and roles)
echo "Running seeders..."
php artisan db:seed --force || echo "Warning: Seeding failed or already completed"

# Cache configuration
echo "Caching configuration..."
php artisan config:cache

# Cache routes
echo "Caching routes..."
php artisan route:cache

# Publish Filament assets (if not already published)
echo "Publishing Filament assets..."
php artisan filament:assets || true

# Cache views (skip if fails, views will be compiled on-demand)
echo "Caching views..."
php artisan view:cache || echo "Warning: View cache failed, views will be compiled on-demand"

# Create storage link if it doesn't exist
if [ ! -L public/storage ]; then
    echo "Creating storage link..."
    php artisan storage:link
fi

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache
chmod -R 755 /var/www/storage /var/www/bootstrap/cache

# Clear application cache
echo "Clearing application cache..."
php artisan cache:clear

echo "Setup completed!"

# Start PHP-FPM in background
php-fpm -D

# Start Nginx in foreground
exec nginx -g "daemon off;"

