#!/bin/sh
# Simple WordPress Metrics Exporter Entrypoint

set -e

echo "Starting WordPress metrics exporter..."

# Set WordPress path and port (Bitnami defaults)
WORDPRESS_PATH=${WORDPRESS_PATH:-/bitnami/wordpress}
WP_PORT=${WP_PORT:-8080}

# Wait for WordPress HTTP to be available
echo "Waiting for WordPress to be ready on 127.0.0.1:${WP_PORT}..."
timeout=300
counter=0

until curl -f -s "http://127.0.0.1:${WP_PORT}/wp-admin/install.php" > /dev/null 2>&1 || \
      curl -f -s "http://127.0.0.1:${WP_PORT}/" > /dev/null 2>&1; do
    echo "WordPress not ready yet, waiting... (${counter}s/${timeout}s)"
    sleep 5
    counter=$((counter + 5))
    if [ $counter -ge $timeout ]; then
        echo "Timeout waiting for WordPress HTTP"
        exit 1
    fi
done

# Resolve actual WordPress path (prefer existing path among provided options)
for candidate in "$WORDPRESS_PATH" "/opt/bitnami/wordpress" "/bitnami/wordpress" "/var/www/html"; do
    if [ -f "${candidate}/wp-config.php" ]; then
        WORDPRESS_PATH="$candidate"
        export WORDPRESS_PATH
        break
    fi
done

echo "Using WordPress path: ${WORDPRESS_PATH}"

# Use exporter script in place (avoid writing to WordPress volume)
METRICS_SCRIPT="/usr/local/bin/metrics-files/simple-metrics-exporter.php"
if [ ! -f "${METRICS_SCRIPT}" ]; then
    echo "Metrics script not found at ${METRICS_SCRIPT}"
    exit 1
fi

# Start PHP built-in server for metrics endpoint
echo "Starting metrics server on port 9090..."
cd $WORDPRESS_PATH

# Create a simple router script
cat > metrics-router.php << 'EOF'
<?php
$uri = $_SERVER['REQUEST_URI'];
if ($uri === '/metrics' || $uri === '/wp-metrics' || strpos($uri, 'metrics') !== false) {
    include '/usr/local/bin/metrics-files/simple-metrics-exporter.php';
} else {
    http_response_code(404);
    echo "Not Found";
}
?>
EOF

# Start the server
exec php -S 0.0.0.0:9090 metrics-router.php
