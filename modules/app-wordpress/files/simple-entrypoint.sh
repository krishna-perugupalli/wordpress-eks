#!/bin/sh
# Simple WordPress Metrics Exporter Entrypoint

set -e

echo "Starting WordPress metrics exporter..."

# Set WordPress path
export WORDPRESS_PATH=${WORDPRESS_PATH:-/var/www/html}

# Wait for WordPress to be available
echo "Waiting for WordPress to be ready..."
timeout=300
counter=0

while [ $counter -lt $timeout ]; do
    if [ -f "$WORDPRESS_PATH/wp-config.php" ]; then
        echo "WordPress configuration found"
        break
    fi
    echo "WordPress not ready yet, waiting... ($counter/$timeout)"
    sleep 5
    counter=$((counter + 5))
done

if [ $counter -ge $timeout ]; then
    echo "Timeout waiting for WordPress"
    exit 1
fi

# Copy metrics exporter to WordPress directory
if [ -f "/usr/local/bin/metrics-files/simple-metrics-exporter.php" ]; then
    cp /usr/local/bin/metrics-files/simple-metrics-exporter.php $WORDPRESS_PATH/wp-metrics.php
    echo "Metrics exporter installed"
fi

# Start PHP built-in server for metrics endpoint
echo "Starting metrics server on port 9090..."
cd $WORDPRESS_PATH

# Create a simple router script
cat > metrics-router.php << 'EOF'
<?php
$uri = $_SERVER['REQUEST_URI'];
if ($uri === '/metrics' || $uri === '/wp-metrics' || strpos($uri, 'metrics') !== false) {
    include 'wp-metrics.php';
} else {
    http_response_code(404);
    echo "Not Found";
}
?>
EOF

# Start the server
exec php -S 0.0.0.0:9090 metrics-router.php