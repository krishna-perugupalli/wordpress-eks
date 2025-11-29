<?php
/**
 * WordPress Prometheus Metrics Exporter
 * 
 * This script exposes WordPress application metrics in Prometheus format.
 * It collects metrics for page views, response times, active users, and plugin performance.
 * 
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

// Load WordPress configuration
require_once(ABSPATH . 'wp-config.php');

class WordPressPrometheusExporter {
    
    private $metrics = [];
    private $start_time;
    
    public function __construct() {
        $this->start_time = microtime(true);
        $this->initializeMetrics();
    }
    
    /**
     * Initialize metric definitions
     */
    private function initializeMetrics() {
        $this->metrics = [
            'wordpress_http_requests_total' => [
                'type' => 'counter',
                'help' => 'Total number of HTTP requests to WordPress',
                'labels' => ['method', 'status', 'endpoint'],
                'value' => 0
            ],
            'wordpress_http_request_duration_seconds' => [
                'type' => 'histogram',
                'help' => 'HTTP request duration in seconds',
                'labels' => ['method', 'endpoint'],
                'buckets' => [0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
                'value' => 0
            ],
            'wordpress_active_users_total' => [
                'type' => 'gauge',
                'help' => 'Number of currently active users',
                'labels' => [],
                'value' => 0
            ],
            'wordpress_plugin_execution_time_seconds' => [
                'type' => 'histogram',
                'help' => 'Plugin execution time in seconds',
                'labels' => ['plugin'],
                'buckets' => [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5],
                'value' => 0
            ],
            'wordpress_database_queries_total' => [
                'type' => 'counter',
                'help' => 'Total number of database queries',
                'labels' => ['type'],
                'value' => 0
            ],
            'wordpress_cache_hits_total' => [
                'type' => 'counter',
                'help' => 'Total number of cache hits',
                'labels' => ['type'],
                'value' => 0
            ],
            'wordpress_cache_misses_total' => [
                'type' => 'counter',
                'help' => 'Total number of cache misses',
                'labels' => ['type'],
                'value' => 0
            ],
            'wordpress_posts_total' => [
                'type' => 'gauge',
                'help' => 'Total number of published posts',
                'labels' => ['post_type'],
                'value' => 0
            ],
            'wordpress_users_total' => [
                'type' => 'gauge',
                'help' => 'Total number of registered users',
                'labels' => ['role'],
                'value' => 0
            ],
            'wordpress_comments_total' => [
                'type' => 'gauge',
                'help' => 'Total number of comments',
                'labels' => ['status'],
                'value' => 0
            ],
            'wordpress_memory_usage_bytes' => [
                'type' => 'gauge',
                'help' => 'Current memory usage in bytes',
                'labels' => [],
                'value' => 0
            ],
            'wordpress_php_version_info' => [
                'type' => 'gauge',
                'help' => 'PHP version information',
                'labels' => ['version'],
                'value' => 1
            ],
            'wordpress_version_info' => [
                'type' => 'gauge',
                'help' => 'WordPress version information',
                'labels' => ['version'],
                'value' => 1
            ]
        ];
    }
    
    /**
     * Collect all metrics
     */
    public function collectMetrics() {
        global $wpdb;
        
        try {
            // Collect basic WordPress metrics
            $this->collectWordPressInfo();
            $this->collectPostMetrics();
            $this->collectUserMetrics();
            $this->collectCommentMetrics();
            $this->collectActiveUsers();
            $this->collectDatabaseMetrics();
            $this->collectCacheMetrics();
            $this->collectPluginMetrics();
            $this->collectMemoryMetrics();
            
        } catch (Exception $e) {
            error_log("WordPress Exporter Error: " . $e->getMessage());
        }
    }
    
    /**
     * Collect WordPress version information
     */
    private function collectWordPressInfo() {
        global $wp_version;
        
        $this->setMetricValue('wordpress_version_info', 1, ['version' => $wp_version]);
        $this->setMetricValue('wordpress_php_version_info', 1, ['version' => PHP_VERSION]);
    }
    
    /**
     * Collect post-related metrics
     */
    private function collectPostMetrics() {
        global $wpdb;
        
        $post_types = get_post_types(['public' => true], 'names');
        
        foreach ($post_types as $post_type) {
            $count = $wpdb->get_var($wpdb->prepare(
                "SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_type = %s AND post_status = 'publish'",
                $post_type
            ));
            
            $this->setMetricValue('wordpress_posts_total', intval($count), ['post_type' => $post_type]);
        }
    }
    
    /**
     * Collect user-related metrics
     */
    private function collectUserMetrics() {
        global $wpdb;
        
        $roles = wp_roles()->get_names();
        
        foreach ($roles as $role_key => $role_name) {
            $users = get_users(['role' => $role_key, 'count_total' => true]);
            $this->setMetricValue('wordpress_users_total', intval($users), ['role' => $role_key]);
        }
    }
    
    /**
     * Collect comment-related metrics
     */
    private function collectCommentMetrics() {
        global $wpdb;
        
        $statuses = ['approved', 'pending', 'spam', 'trash'];
        
        foreach ($statuses as $status) {
            $count = $wpdb->get_var($wpdb->prepare(
                "SELECT COUNT(*) FROM {$wpdb->comments} WHERE comment_approved = %s",
                $status === 'approved' ? '1' : $status
            ));
            
            $this->setMetricValue('wordpress_comments_total', intval($count), ['status' => $status]);
        }
    }
    
    /**
     * Collect active user metrics (users active in last 5 minutes)
     */
    private function collectActiveUsers() {
        global $wpdb;
        
        // Count users with recent activity (last 5 minutes)
        $active_users = $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(DISTINCT user_id) FROM {$wpdb->usermeta} 
             WHERE meta_key = 'session_tokens' 
             AND meta_value != '' 
             AND user_id IN (
                 SELECT user_id FROM {$wpdb->usermeta} 
                 WHERE meta_key = 'last_activity' 
                 AND meta_value > %d
             )",
            time() - 300 // 5 minutes ago
        ));
        
        $this->setMetricValue('wordpress_active_users_total', intval($active_users));
    }
    
    /**
     * Collect database query metrics
     */
    private function collectDatabaseMetrics() {
        global $wpdb;
        
        // Get query count from WordPress
        $query_count = get_num_queries();
        $this->setMetricValue('wordpress_database_queries_total', $query_count, ['type' => 'total']);
        
        // Collect slow query information if available
        if (defined('SAVEQUERIES') && SAVEQUERIES) {
            $slow_queries = 0;
            foreach ($wpdb->queries as $query) {
                if ($query[1] > 0.1) { // Queries taking more than 100ms
                    $slow_queries++;
                }
            }
            $this->setMetricValue('wordpress_database_queries_total', $slow_queries, ['type' => 'slow']);
        }
    }
    
    /**
     * Collect cache metrics
     */
    private function collectCacheMetrics() {
        global $wp_object_cache;
        
        if (is_object($wp_object_cache)) {
            // Object cache statistics
            if (method_exists($wp_object_cache, 'get_stats')) {
                $stats = $wp_object_cache->get_stats();
                if (isset($stats['cache_hits'])) {
                    $this->setMetricValue('wordpress_cache_hits_total', $stats['cache_hits'], ['type' => 'object']);
                }
                if (isset($stats['cache_misses'])) {
                    $this->setMetricValue('wordpress_cache_misses_total', $stats['cache_misses'], ['type' => 'object']);
                }
            }
        }
        
        // W3 Total Cache integration
        if (function_exists('w3_instance')) {
            try {
                $w3_config = w3_instance('W3_Config');
                if ($w3_config && $w3_config->get_boolean('pgcache.enabled')) {
                    // Page cache metrics would be collected here
                    $this->setMetricValue('wordpress_cache_hits_total', 0, ['type' => 'page']);
                }
            } catch (Exception $e) {
                // W3TC not available or configured
            }
        }
    }
    
    /**
     * Collect plugin performance metrics
     */
    private function collectPluginMetrics() {
        if (!function_exists('get_plugins')) {
            require_once(ABSPATH . 'wp-admin/includes/plugin.php');
        }
        
        $active_plugins = get_option('active_plugins', []);
        
        foreach ($active_plugins as $plugin) {
            $plugin_data = get_plugin_data(WP_PLUGIN_DIR . '/' . $plugin);
            $plugin_name = sanitize_title($plugin_data['Name']);
            
            // Measure plugin execution time (simplified approach)
            $start_time = microtime(true);
            
            // This is a placeholder - in a real implementation, you'd hook into
            // plugin execution to measure actual execution time
            $execution_time = 0.001; // Default minimal time
            
            $this->setMetricValue('wordpress_plugin_execution_time_seconds', $execution_time, ['plugin' => $plugin_name]);
        }
    }
    
    /**
     * Collect memory usage metrics
     */
    private function collectMemoryMetrics() {
        $memory_usage = memory_get_usage(true);
        $this->setMetricValue('wordpress_memory_usage_bytes', $memory_usage);
    }
    
    /**
     * Set metric value with labels
     */
    private function setMetricValue($metric_name, $value, $labels = []) {
        if (!isset($this->metrics[$metric_name])) {
            return;
        }
        
        $this->metrics[$metric_name]['samples'][] = [
            'labels' => $labels,
            'value' => $value,
            'timestamp' => time() * 1000 // Prometheus expects milliseconds
        ];
    }
    
    /**
     * Output metrics in Prometheus format
     */
    public function outputMetrics() {
        header('Content-Type: text/plain; charset=utf-8');
        
        foreach ($this->metrics as $name => $metric) {
            // Output HELP line
            echo "# HELP {$name} {$metric['help']}\n";
            
            // Output TYPE line
            echo "# TYPE {$name} {$metric['type']}\n";
            
            // Output samples
            if (isset($metric['samples'])) {
                foreach ($metric['samples'] as $sample) {
                    $labels_str = '';
                    if (!empty($sample['labels'])) {
                        $label_pairs = [];
                        foreach ($sample['labels'] as $key => $value) {
                            $label_pairs[] = $key . '="' . addslashes($value) . '"';
                        }
                        $labels_str = '{' . implode(',', $label_pairs) . '}';
                    }
                    
                    echo "{$name}{$labels_str} {$sample['value']}\n";
                }
            } else {
                // Default value if no samples
                echo "{$name} {$metric['value']}\n";
            }
            
            echo "\n";
        }
        
        // Add exporter metadata
        $duration = microtime(true) - $this->start_time;
        echo "# HELP wordpress_exporter_duration_seconds Time spent collecting metrics\n";
        echo "# TYPE wordpress_exporter_duration_seconds gauge\n";
        echo "wordpress_exporter_duration_seconds {$duration}\n\n";
        
        echo "# HELP wordpress_exporter_last_scrape_timestamp_seconds Last time metrics were scraped\n";
        echo "# TYPE wordpress_exporter_last_scrape_timestamp_seconds gauge\n";
        echo "wordpress_exporter_last_scrape_timestamp_seconds " . time() . "\n";
    }
}

// Handle the metrics endpoint
if (isset($_GET['metrics']) || strpos($_SERVER['REQUEST_URI'], '/metrics') !== false) {
    $exporter = new WordPressPrometheusExporter();
    $exporter->collectMetrics();
    $exporter->outputMetrics();
    exit;
}

// If not a metrics request, return 404
http_response_code(404);
echo "Not Found";
exit;
?>