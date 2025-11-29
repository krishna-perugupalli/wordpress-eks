<?php
/**
 * Plugin Name: WordPress Prometheus Metrics
 * Description: Collects and exposes WordPress metrics for Prometheus monitoring
 * Version: 1.0.0
 * Author: WordPress EKS Platform
 * 
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class WordPressMetricsPlugin {
    
    private $metrics_data = [];
    private $start_time;
    
    public function __construct() {
        $this->start_time = microtime(true);
        add_action('init', [$this, 'init']);
        add_action('wp_loaded', [$this, 'track_page_load']);
        add_action('wp_footer', [$this, 'track_page_view']);
        add_action('wp_login', [$this, 'track_user_login'], 10, 2);
        add_action('wp_logout', [$this, 'track_user_logout']);
        add_action('comment_post', [$this, 'track_comment']);
        add_action('transition_post_status', [$this, 'track_post_status_change'], 10, 3);
        
        // Hook into plugin execution tracking
        add_action('plugins_loaded', [$this, 'start_plugin_tracking'], 1);
        add_action('wp_loaded', [$this, 'end_plugin_tracking'], 999);
        
        // Database query tracking
        add_filter('query', [$this, 'track_database_query']);
        
        // Cache tracking
        add_action('wp_cache_get', [$this, 'track_cache_get'], 10, 2);
        add_action('wp_cache_set', [$this, 'track_cache_set'], 10, 3);
        
        // Error tracking
        add_action('wp_die_handler', [$this, 'track_error']);
        
        // Performance tracking
        add_action('shutdown', [$this, 'track_performance_metrics']);
    }
    
    public function init() {
        // Initialize metrics storage
        $this->init_metrics_storage();
        
        // Add metrics endpoint
        add_action('template_redirect', [$this, 'handle_metrics_endpoint']);
        
        // Update user activity timestamp
        if (is_user_logged_in()) {
            $this->update_user_activity();
        }
    }
    
    /**
     * Initialize metrics storage in database
     */
    private function init_metrics_storage() {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'prometheus_metrics';
        
        $charset_collate = $wpdb->get_charset_collate();
        
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) NOT NULL AUTO_INCREMENT,
            metric_name varchar(255) NOT NULL,
            metric_value double NOT NULL,
            labels text,
            timestamp datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY metric_name (metric_name),
            KEY timestamp (timestamp)
        ) $charset_collate;";
        
        require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
        dbDelta($sql);
    }
    
    /**
     * Handle metrics endpoint requests
     */
    public function handle_metrics_endpoint() {
        if (strpos($_SERVER['REQUEST_URI'], '/wp-metrics') !== false || 
            (isset($_GET['action']) && $_GET['action'] === 'prometheus_metrics')) {
            
            $this->output_prometheus_metrics();
            exit;
        }
    }
    
    /**
     * Track page load start time
     */
    public function track_page_load() {
        if (!defined('WP_METRICS_START_TIME')) {
            define('WP_METRICS_START_TIME', microtime(true));
        }
    }
    
    /**
     * Track page view completion
     */
    public function track_page_view() {
        if (!is_admin() && !wp_doing_ajax()) {
            $endpoint = $this->get_current_endpoint();
            $method = $_SERVER['REQUEST_METHOD'];
            $status = http_response_code() ?: 200;
            
            $this->increment_counter('wordpress_http_requests_total', [
                'method' => $method,
                'status' => $status,
                'endpoint' => $endpoint
            ]);
            
            // Track response time
            if (defined('WP_METRICS_START_TIME')) {
                $duration = microtime(true) - WP_METRICS_START_TIME;
                $this->record_histogram('wordpress_http_request_duration_seconds', $duration, [
                    'method' => $method,
                    'endpoint' => $endpoint
                ]);
            }
        }
    }
    
    /**
     * Track user login
     */
    public function track_user_login($user_login, $user) {
        $this->increment_counter('wordpress_user_logins_total', [
            'user_role' => implode(',', $user->roles)
        ]);
        
        $this->update_user_activity($user->ID);
    }
    
    /**
     * Track user logout
     */
    public function track_user_logout() {
        $this->increment_counter('wordpress_user_logouts_total');
    }
    
    /**
     * Track comment creation
     */
    public function track_comment($comment_id) {
        $comment = get_comment($comment_id);
        if ($comment) {
            $this->increment_counter('wordpress_comments_created_total', [
                'status' => $comment->comment_approved
            ]);
        }
    }
    
    /**
     * Track post status changes
     */
    public function track_post_status_change($new_status, $old_status, $post) {
        if ($new_status !== $old_status) {
            $this->increment_counter('wordpress_post_status_changes_total', [
                'post_type' => $post->post_type,
                'old_status' => $old_status,
                'new_status' => $new_status
            ]);
        }
    }
    
    /**
     * Start plugin execution tracking
     */
    public function start_plugin_tracking() {
        if (!defined('WP_METRICS_PLUGINS_START')) {
            define('WP_METRICS_PLUGINS_START', microtime(true));
        }
    }
    
    /**
     * End plugin execution tracking
     */
    public function end_plugin_tracking() {
        if (defined('WP_METRICS_PLUGINS_START')) {
            $duration = microtime(true) - WP_METRICS_PLUGINS_START;
            $this->record_histogram('wordpress_plugins_execution_time_seconds', $duration);
        }
    }
    
    /**
     * Track database queries
     */
    public function track_database_query($query) {
        $query_type = $this->get_query_type($query);
        $this->increment_counter('wordpress_database_queries_total', [
            'type' => $query_type
        ]);
        
        return $query;
    }
    
    /**
     * Track cache gets
     */
    public function track_cache_get($key, $found) {
        if ($found) {
            $this->increment_counter('wordpress_cache_hits_total', ['type' => 'object']);
        } else {
            $this->increment_counter('wordpress_cache_misses_total', ['type' => 'object']);
        }
    }
    
    /**
     * Track cache sets
     */
    public function track_cache_set($key, $data, $expire) {
        $this->increment_counter('wordpress_cache_sets_total', ['type' => 'object']);
    }
    
    /**
     * Track errors
     */
    public function track_error($handler) {
        $this->increment_counter('wordpress_errors_total');
        return $handler;
    }
    
    /**
     * Track performance metrics on shutdown
     */
    public function track_performance_metrics() {
        // Memory usage
        $memory_usage = memory_get_usage(true);
        $memory_peak = memory_get_peak_usage(true);
        
        $this->set_gauge('wordpress_memory_usage_bytes', $memory_usage);
        $this->set_gauge('wordpress_memory_peak_bytes', $memory_peak);
        
        // Query count
        $query_count = get_num_queries();
        $this->set_gauge('wordpress_queries_count', $query_count);
        
        // Execution time
        if (defined('WP_METRICS_START_TIME')) {
            $execution_time = microtime(true) - WP_METRICS_START_TIME;
            $this->record_histogram('wordpress_page_generation_time_seconds', $execution_time);
        }
    }
    
    /**
     * Update user activity timestamp
     */
    private function update_user_activity($user_id = null) {
        if (!$user_id) {
            $user_id = get_current_user_id();
        }
        
        if ($user_id) {
            update_user_meta($user_id, 'last_activity', time());
        }
    }
    
    /**
     * Get current endpoint for labeling
     */
    private function get_current_endpoint() {
        global $wp;
        
        if (is_admin()) {
            return 'admin';
        } elseif (is_home() || is_front_page()) {
            return 'home';
        } elseif (is_single()) {
            return 'single';
        } elseif (is_page()) {
            return 'page';
        } elseif (is_category()) {
            return 'category';
        } elseif (is_tag()) {
            return 'tag';
        } elseif (is_archive()) {
            return 'archive';
        } elseif (is_search()) {
            return 'search';
        } elseif (is_404()) {
            return '404';
        } else {
            return 'other';
        }
    }
    
    /**
     * Get query type from SQL query
     */
    private function get_query_type($query) {
        $query = trim(strtoupper($query));
        
        if (strpos($query, 'SELECT') === 0) {
            return 'select';
        } elseif (strpos($query, 'INSERT') === 0) {
            return 'insert';
        } elseif (strpos($query, 'UPDATE') === 0) {
            return 'update';
        } elseif (strpos($query, 'DELETE') === 0) {
            return 'delete';
        } elseif (strpos($query, 'CREATE') === 0) {
            return 'create';
        } elseif (strpos($query, 'ALTER') === 0) {
            return 'alter';
        } elseif (strpos($query, 'DROP') === 0) {
            return 'drop';
        } else {
            return 'other';
        }
    }
    
    /**
     * Increment a counter metric
     */
    private function increment_counter($metric_name, $labels = [], $value = 1) {
        $this->store_metric($metric_name, $value, $labels, 'counter');
    }
    
    /**
     * Set a gauge metric
     */
    private function set_gauge($metric_name, $value, $labels = []) {
        $this->store_metric($metric_name, $value, $labels, 'gauge');
    }
    
    /**
     * Record a histogram metric
     */
    private function record_histogram($metric_name, $value, $labels = []) {
        $this->store_metric($metric_name, $value, $labels, 'histogram');
    }
    
    /**
     * Store metric in database
     */
    private function store_metric($metric_name, $value, $labels = [], $type = 'counter') {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'prometheus_metrics';
        $labels_json = json_encode($labels);
        
        // For counters, we need to increment existing values
        if ($type === 'counter') {
            $existing = $wpdb->get_var($wpdb->prepare(
                "SELECT metric_value FROM $table_name 
                 WHERE metric_name = %s AND labels = %s 
                 ORDER BY timestamp DESC LIMIT 1",
                $metric_name,
                $labels_json
            ));
            
            $value = ($existing ? floatval($existing) : 0) + $value;
        }
        
        $wpdb->insert(
            $table_name,
            [
                'metric_name' => $metric_name,
                'metric_value' => $value,
                'labels' => $labels_json
            ],
            ['%s', '%f', '%s']
        );
    }
    
    /**
     * Output metrics in Prometheus format
     */
    public function output_prometheus_metrics() {
        global $wpdb;
        
        header('Content-Type: text/plain; charset=utf-8');
        
        $table_name = $wpdb->prefix . 'prometheus_metrics';
        
        // Clean old metrics (older than 1 hour)
        $wpdb->query($wpdb->prepare(
            "DELETE FROM $table_name WHERE timestamp < %s",
            date('Y-m-d H:i:s', time() - 3600)
        ));
        
        // Get current metrics
        $metrics = $wpdb->get_results(
            "SELECT metric_name, metric_value, labels 
             FROM $table_name 
             WHERE timestamp > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
             ORDER BY metric_name, timestamp DESC"
        );
        
        $grouped_metrics = [];
        foreach ($metrics as $metric) {
            $key = $metric->metric_name . '|' . $metric->labels;
            if (!isset($grouped_metrics[$key])) {
                $grouped_metrics[$key] = $metric;
            }
        }
        
        $output_metrics = [];
        foreach ($grouped_metrics as $metric) {
            $labels = json_decode($metric->labels, true) ?: [];
            $output_metrics[$metric->metric_name][] = [
                'value' => $metric->metric_value,
                'labels' => $labels
            ];
        }
        
        // Output metrics
        foreach ($output_metrics as $name => $samples) {
            echo "# HELP {$name} WordPress metric\n";
            echo "# TYPE {$name} gauge\n";
            
            foreach ($samples as $sample) {
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
            echo "\n";
        }
        
        // Add exporter metadata
        echo "# HELP wordpress_metrics_plugin_info WordPress metrics plugin information\n";
        echo "# TYPE wordpress_metrics_plugin_info gauge\n";
        echo "wordpress_metrics_plugin_info{version=\"1.0.0\"} 1\n";
    }
}

// Initialize the plugin
new WordPressMetricsPlugin();
?>