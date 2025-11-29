<?php
/**
 * Simple WordPress Metrics Exporter
 * Lightweight PHP script that exposes WordPress metrics for Prometheus
 */

// Set content type for Prometheus
header('Content-Type: text/plain; charset=utf-8');

// Basic error handling
error_reporting(E_ERROR | E_PARSE);
ini_set('display_errors', 0);

// WordPress path detection
$wp_path = '/var/www/html';
if (getenv('WORDPRESS_PATH')) {
    $wp_path = getenv('WORDPRESS_PATH');
}

// Try to load WordPress
$wp_config_path = $wp_path . '/wp-config.php';
if (!file_exists($wp_config_path)) {
    echo "# WordPress not found at $wp_path\n";
    echo "wordpress_exporter_error{type=\"config_not_found\"} 1\n";
    exit;
}

// Define WordPress constants
define('ABSPATH', $wp_path . '/');
define('WP_USE_THEMES', false);
define('WP_DEBUG', false);

try {
    // Load WordPress configuration
    require_once($wp_config_path);
    
    // Create database connection
    $mysqli = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, defined('DB_PORT') ? DB_PORT : 3306);
    
    if ($mysqli->connect_error) {
        echo "# Database connection failed\n";
        echo "wordpress_exporter_error{type=\"db_connection\"} 1\n";
        exit;
    }
    
    // Set charset
    $mysqli->set_charset('utf8');
    
    // Collect metrics
    $metrics = [];
    $start_time = microtime(true);
    
    // WordPress version info
    $wp_version = 'unknown';
    $version_file = $wp_path . '/wp-includes/version.php';
    if (file_exists($version_file)) {
        $version_content = file_get_contents($version_file);
        if (preg_match('/\$wp_version\s*=\s*[\'"]([^\'"]+)[\'"]/', $version_content, $matches)) {
            $wp_version = $matches[1];
        }
    }
    
    $metrics[] = "# HELP wordpress_version_info WordPress version information";
    $metrics[] = "# TYPE wordpress_version_info gauge";
    $metrics[] = "wordpress_version_info{version=\"$wp_version\"} 1";
    
    // PHP version info
    $php_version = PHP_VERSION;
    $metrics[] = "# HELP wordpress_php_version_info PHP version information";
    $metrics[] = "# TYPE wordpress_php_version_info gauge";
    $metrics[] = "wordpress_php_version_info{version=\"$php_version\"} 1";
    
    // Posts count by type
    $post_types = ['post', 'page'];
    $metrics[] = "# HELP wordpress_posts_total Total number of published posts by type";
    $metrics[] = "# TYPE wordpress_posts_total gauge";
    
    foreach ($post_types as $post_type) {
        $result = $mysqli->query("SELECT COUNT(*) as count FROM {$mysqli->real_escape_string(DB_NAME)}.wp_posts WHERE post_type = '$post_type' AND post_status = 'publish'");
        if ($result && $row = $result->fetch_assoc()) {
            $metrics[] = "wordpress_posts_total{post_type=\"$post_type\"} " . intval($row['count']);
        }
    }
    
    // Users count
    $result = $mysqli->query("SELECT COUNT(*) as count FROM {$mysqli->real_escape_string(DB_NAME)}.wp_users");
    if ($result && $row = $result->fetch_assoc()) {
        $metrics[] = "# HELP wordpress_users_total Total number of registered users";
        $metrics[] = "# TYPE wordpress_users_total gauge";
        $metrics[] = "wordpress_users_total " . intval($row['count']);
    }
    
    // Comments count by status
    $comment_statuses = ['1' => 'approved', '0' => 'pending', 'spam' => 'spam'];
    $metrics[] = "# HELP wordpress_comments_total Total number of comments by status";
    $metrics[] = "# TYPE wordpress_comments_total gauge";
    
    foreach ($comment_statuses as $status_value => $status_name) {
        $result = $mysqli->query("SELECT COUNT(*) as count FROM {$mysqli->real_escape_string(DB_NAME)}.wp_comments WHERE comment_approved = '$status_value'");
        if ($result && $row = $result->fetch_assoc()) {
            $metrics[] = "wordpress_comments_total{status=\"$status_name\"} " . intval($row['count']);
        }
    }
    
    // Active users (users with recent activity - last 5 minutes)
    $five_minutes_ago = time() - 300;
    $result = $mysqli->query("
        SELECT COUNT(DISTINCT user_id) as count 
        FROM {$mysqli->real_escape_string(DB_NAME)}.wp_usermeta 
        WHERE meta_key = 'last_activity' 
        AND CAST(meta_value AS UNSIGNED) > $five_minutes_ago
    ");
    
    $active_users = 0;
    if ($result && $row = $result->fetch_assoc()) {
        $active_users = intval($row['count']);
    }
    
    $metrics[] = "# HELP wordpress_active_users_total Number of currently active users";
    $metrics[] = "# TYPE wordpress_active_users_total gauge";
    $metrics[] = "wordpress_active_users_total $active_users";
    
    // Database connection count (approximate)
    $result = $mysqli->query("SHOW STATUS LIKE 'Threads_connected'");
    if ($result && $row = $result->fetch_assoc()) {
        $metrics[] = "# HELP wordpress_database_connections Current database connections";
        $metrics[] = "# TYPE wordpress_database_connections gauge";
        $metrics[] = "wordpress_database_connections " . intval($row['Value']);
    }
    
    // Memory usage
    $memory_usage = memory_get_usage(true);
    $memory_peak = memory_get_peak_usage(true);
    
    $metrics[] = "# HELP wordpress_memory_usage_bytes Current memory usage in bytes";
    $metrics[] = "# TYPE wordpress_memory_usage_bytes gauge";
    $metrics[] = "wordpress_memory_usage_bytes $memory_usage";
    
    $metrics[] = "# HELP wordpress_memory_peak_bytes Peak memory usage in bytes";
    $metrics[] = "# TYPE wordpress_memory_peak_bytes gauge";
    $metrics[] = "wordpress_memory_peak_bytes $memory_peak";
    
    // Plugin count
    $plugins_dir = $wp_path . '/wp-content/plugins';
    $plugin_count = 0;
    if (is_dir($plugins_dir)) {
        $plugin_count = count(glob($plugins_dir . '/*', GLOB_ONLYDIR));
    }
    
    $metrics[] = "# HELP wordpress_plugins_total Total number of installed plugins";
    $metrics[] = "# TYPE wordpress_plugins_total gauge";
    $metrics[] = "wordpress_plugins_total $plugin_count";
    
    // Theme count
    $themes_dir = $wp_path . '/wp-content/themes';
    $theme_count = 0;
    if (is_dir($themes_dir)) {
        $theme_count = count(glob($themes_dir . '/*', GLOB_ONLYDIR));
    }
    
    $metrics[] = "# HELP wordpress_themes_total Total number of installed themes";
    $metrics[] = "# TYPE wordpress_themes_total gauge";
    $metrics[] = "wordpress_themes_total $theme_count";
    
    // Exporter metadata
    $duration = microtime(true) - $start_time;
    $metrics[] = "# HELP wordpress_exporter_duration_seconds Time spent collecting metrics";
    $metrics[] = "# TYPE wordpress_exporter_duration_seconds gauge";
    $metrics[] = "wordpress_exporter_duration_seconds $duration";
    
    $metrics[] = "# HELP wordpress_exporter_last_scrape_timestamp_seconds Last time metrics were scraped";
    $metrics[] = "# TYPE wordpress_exporter_last_scrape_timestamp_seconds gauge";
    $metrics[] = "wordpress_exporter_last_scrape_timestamp_seconds " . time();
    
    // Close database connection
    $mysqli->close();
    
    // Output all metrics
    echo implode("\n", $metrics) . "\n";
    
} catch (Exception $e) {
    echo "# Error collecting WordPress metrics: " . $e->getMessage() . "\n";
    echo "wordpress_exporter_error{type=\"collection_error\"} 1\n";
}
?>