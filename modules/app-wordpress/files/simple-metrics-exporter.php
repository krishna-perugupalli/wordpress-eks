<?php
/**
 * Simple WordPress Metrics Exporter (Prometheus-compatible)
 * Collects basic WordPress stats without heavy hooks or database writes.
 */

header('Content-Type: text/plain; charset=utf-8');
error_reporting(E_ERROR | E_PARSE);
ini_set('display_errors', 0);

$wp_path = getenv('WORDPRESS_PATH') ?: '/bitnami/wordpress';
$wp_load = $wp_path . '/wp-load.php';
$wp_config = $wp_path . '/wp-config.php';

if (!file_exists($wp_load) || !file_exists($wp_config)) {
    echo "# HELP wordpress_exporter_error Exporter error flag\n";
    echo "# TYPE wordpress_exporter_error gauge\n";
    echo "wordpress_exporter_error{type=\"config_not_found\"} 1\n";
    exit;
}

define('ABSPATH', $wp_path . '/');
define('WP_USE_THEMES', false);


$start = microtime(true);

require_once $wp_load;

if (!function_exists('wp_count_posts')) {
    echo "# HELP wordpress_exporter_error Exporter error flag\n";
    echo "# TYPE wordpress_exporter_error gauge\n";
    echo "wordpress_exporter_error{type=\"bootstrap_failed\"} 1\n";
    exit;
}

class WP_Prometheus_Exporter {
    private $metrics = [];

    public function __construct() {
        $this->defineMetric('wordpress_version_info', 'gauge', 'WordPress version information');
        $this->defineMetric('wordpress_php_version_info', 'gauge', 'PHP version information');
        $this->defineMetric('wordpress_posts_total', 'gauge', 'Published posts by type');
        $this->defineMetric('wordpress_users_total', 'gauge', 'Users by role');
        $this->defineMetric('wordpress_comments_total', 'gauge', 'Comments by status');
        $this->defineMetric('wordpress_active_users_total', 'gauge', 'Active users (last 5m)');
        $this->defineMetric('wordpress_plugins_total', 'gauge', 'Installed plugins');
        $this->defineMetric('wordpress_themes_total', 'gauge', 'Installed themes');
        $this->defineMetric('wordpress_memory_usage_bytes', 'gauge', 'Current memory usage');
        $this->defineMetric('wordpress_memory_peak_bytes', 'gauge', 'Peak memory usage');
        $this->defineMetric('wordpress_database_connections', 'gauge', 'Current DB connections');
        $this->defineMetric('wordpress_exporter_duration_seconds', 'gauge', 'Time spent collecting metrics');
        $this->defineMetric('wordpress_exporter_last_scrape_timestamp_seconds', 'gauge', 'Last scrape timestamp');
    }

    private function defineMetric($name, $type, $help) {
        $this->metrics[$name] = [
            'type' => $type,
            'help' => $help,
            'samples' => []
        ];
    }

    private function addSample($name, $value, $labels = []) {
        if (!isset($this->metrics[$name])) {
            return;
        }
        $this->metrics[$name]['samples'][] = [
            'labels' => $labels,
            'value' => $value
        ];
    }

    public function collect() {
        global $wpdb, $wp_version;

        $this->addSample('wordpress_version_info', 1, ['version' => $wp_version]);
        $this->addSample('wordpress_php_version_info', 1, ['version' => PHP_VERSION]);

        // Posts by type (public)
        $post_counts = wp_count_posts('post');
        $page_counts = wp_count_posts('page');
        if (isset($post_counts->publish)) {
            $this->addSample('wordpress_posts_total', intval($post_counts->publish), ['post_type' => 'post']);
        }
        if (isset($page_counts->publish)) {
            $this->addSample('wordpress_posts_total', intval($page_counts->publish), ['post_type' => 'page']);
        }

        // Users by role
        $role_counts = count_users();
        if (!empty($role_counts['avail_roles'])) {
            foreach ($role_counts['avail_roles'] as $role => $count) {
                $this->addSample('wordpress_users_total', intval($count), ['role' => $role]);
            }
        }

        // Comments by status
        $comment_counts = wp_count_comments();
        foreach (['approved', 'pending', 'spam', 'trash'] as $status) {
            if (isset($comment_counts->$status)) {
                $this->addSample('wordpress_comments_total', intval($comment_counts->$status), ['status' => $status]);
            }
        }

        // Active users (last 5m) via usermeta last_activity
        $active_users = 0;
        if ($wpdb instanceof wpdb) {
            $threshold = time() - 300;
            $table = $wpdb->usermeta;
            $active_users = intval($wpdb->get_var(
                $wpdb->prepare(
                    "SELECT COUNT(DISTINCT user_id) FROM $table WHERE meta_key = 'last_activity' AND meta_value > %d",
                    $threshold
                )
            ));
        }
        $this->addSample('wordpress_active_users_total', $active_users);

        // Plugins/Themes
        if (!function_exists('get_plugins')) {
            require_once ABSPATH . 'wp-admin/includes/plugin.php';
        }
        $plugins = get_plugins();
        $this->addSample('wordpress_plugins_total', count($plugins));

        $themes = wp_get_themes();
        $this->addSample('wordpress_themes_total', count($themes));

        // Memory
        $this->addSample('wordpress_memory_usage_bytes', memory_get_usage(true));
        $this->addSample('wordpress_memory_peak_bytes', memory_get_peak_usage(true));

        // DB connections (best-effort)
        if ($wpdb instanceof wpdb) {
            $conn = $wpdb->get_var("SHOW STATUS LIKE 'Threads_connected'");
            if ($conn !== null) {
                // When using get_var with SHOW STATUS, the value is in the second column
                $threads = $wpdb->get_row("SHOW STATUS LIKE 'Threads_connected'", ARRAY_N);
                if (isset($threads[1])) {
                    $this->addSample('wordpress_database_connections', intval($threads[1]));
                }
            }
        }
    }

    public function output($duration) {
        $this->addSample('wordpress_exporter_duration_seconds', $duration);
        $this->addSample('wordpress_exporter_last_scrape_timestamp_seconds', time());

        foreach ($this->metrics as $name => $meta) {
            echo "# HELP {$name} {$meta['help']}\n";
            echo "# TYPE {$name} {$meta['type']}\n";
            foreach ($meta['samples'] as $sample) {
                $label_str = '';
                if (!empty($sample['labels'])) {
                    $pairs = [];
                    foreach ($sample['labels'] as $k => $v) {
                        $pairs[] = $k . '="' . addslashes($v) . '"';
                    }
                    $label_str = '{' . implode(',', $pairs) . '}';
                }
                echo "{$name}{$label_str} {$sample['value']}\n";
            }
            echo "\n";
        }
    }
}

$exporter = new WP_Prometheus_Exporter();
$exporter->collect();
$exporter->output(microtime(true) - $start);
