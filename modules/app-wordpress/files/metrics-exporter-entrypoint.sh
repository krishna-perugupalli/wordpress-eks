#!/bin/sh
# WordPress Metrics Exporter Entrypoint Script

set -e

# Wait for WordPress to be available (Bitnami WordPress listens on 8080 by default)
WP_PORT="${WP_PORT:-8080}"

echo "Waiting for WordPress to be ready..."
until curl -f -s "http://127.0.0.1:${WP_PORT}/wp-admin/install.php" > /dev/null 2>&1 || \
      curl -f -s "http://127.0.0.1:${WP_PORT}/" > /dev/null 2>&1; do
    echo "WordPress not ready yet, waiting..."
    sleep 5
done

echo "WordPress is ready, starting metrics exporter..."

# Create PHP-FPM configuration for metrics endpoint
cat > /usr/local/etc/php-fpm.d/metrics.conf << 'EOF'
[metrics]
user = wordpress
group = wordpress
listen = 127.0.0.1:9090
listen.owner = wordpress
listen.group = wordpress
listen.mode = 0660
pm = static
pm.max_children = 2
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 1
pm.max_requests = 1000
php_admin_value[error_log] = /var/log/php-fpm-metrics.log
php_admin_flag[log_errors] = on
catch_workers_output = yes
EOF

# Create nginx configuration for metrics endpoint
cat > /etc/nginx/conf.d/metrics.conf << 'EOF'
server {
    listen 9090;
    server_name localhost;
    
    root /var/www/html;
    index wp-metrics.php;
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    
    # Metrics endpoint
    location /metrics {
        try_files $uri $uri/ /wp-metrics.php?$args;
        
        # Only allow GET requests
        limit_except GET {
            deny all;
        }
        
        # Rate limiting
        limit_req zone=metrics burst=10 nodelay;
    }
    
    # WordPress metrics endpoint
    location /wp-metrics {
        try_files $uri $uri/ /wp-metrics.php?$args;
        limit_except GET {
            deny all;
        }
        limit_req zone=metrics burst=10 nodelay;
    }
    
    # PHP processing
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9090;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        
        # Security
        fastcgi_param HTTP_PROXY "";
        fastcgi_read_timeout 300;
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ wp-config\.php {
        deny all;
    }
}

# Rate limiting zone
http {
    limit_req_zone $binary_remote_addr zone=metrics:10m rate=1r/s;
}
EOF

# Create log directory
mkdir -p /var/log
touch /var/log/php-fpm-metrics.log
chown wordpress:wordpress /var/log/php-fpm-metrics.log

# Function to check if WordPress database is accessible
check_wordpress_db() {
    php -r "
    define('ABSPATH', '/var/www/html/');
    if (file_exists('/var/www/html/wp-config.php')) {
        require_once('/var/www/html/wp-config.php');
        try {
            \$connection = new PDO('mysql:host=' . DB_HOST . ';port=3306;dbname=' . DB_NAME, DB_USER, DB_PASSWORD);
            echo 'Database connection successful';
            exit(0);
        } catch (Exception \$e) {
            echo 'Database connection failed: ' . \$e->getMessage();
            exit(1);
        }
    } else {
        echo 'wp-config.php not found';
        exit(1);
    }
    "
}

# Wait for database connection
echo "Checking WordPress database connection..."
until check_wordpress_db; do
    echo "Database not ready, waiting..."
    sleep 5
done

echo "Database connection established"

# Install WordPress metrics plugin if not already installed
if [ -f "/var/www/html/wp-config.php" ]; then
    echo "Installing WordPress metrics plugin..."
    
    # Create plugin directory if it doesn't exist
    mkdir -p /var/www/html/wp-content/plugins/wordpress-metrics
    
    # Copy plugin file
    cp /var/www/html/wp-content/plugins/wordpress-metrics/wordpress-metrics.php \
       /var/www/html/wp-content/plugins/wordpress-metrics/wordpress-metrics.php
    
    # Activate plugin via WP-CLI if available, otherwise via database
    if command -v wp > /dev/null 2>&1; then
        wp plugin activate wordpress-metrics --path=/var/www/html --allow-root || true
    else
        # Activate plugin by adding to active_plugins option
        php -r "
        define('ABSPATH', '/var/www/html/');
        require_once('/var/www/html/wp-config.php');
        \$wpdb = new wpdb(DB_USER, DB_PASSWORD, DB_NAME, DB_HOST);
        \$active_plugins = get_option('active_plugins', array());
        if (!in_array('wordpress-metrics/wordpress-metrics.php', \$active_plugins)) {
            \$active_plugins[] = 'wordpress-metrics/wordpress-metrics.php';
            update_option('active_plugins', \$active_plugins);
            echo 'Plugin activated successfully';
        }
        "
    fi
fi

# Start PHP-FPM in background
echo "Starting PHP-FPM for metrics..."
php-fpm --daemonize --fpm-config /usr/local/etc/php-fpm.conf

# Start nginx for metrics endpoint
if command -v nginx > /dev/null 2>&1; then
    echo "Starting nginx for metrics endpoint..."
    nginx -g "daemon off;" &
else
    # Fallback: use PHP built-in server for metrics
    echo "Starting PHP built-in server for metrics..."
    cd /var/www/html
    php -S 0.0.0.0:9090 wp-metrics.php &
fi

# Keep container running and monitor processes
while true; do
    # Check if PHP-FPM is running
    if ! pgrep -f "php-fpm: master process" > /dev/null; then
        echo "PHP-FPM died, restarting..."
        php-fpm --daemonize --fpm-config /usr/local/etc/php-fpm.conf
    fi
    
    # Check if nginx is running (if available)
    if command -v nginx > /dev/null 2>&1 && ! pgrep nginx > /dev/null; then
        echo "Nginx died, restarting..."
        nginx -g "daemon off;" &
    fi
    
    sleep 30
done
