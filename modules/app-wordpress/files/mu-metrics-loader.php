<?php
/**
 * MU loader to ensure the WordPress metrics plugin is always active.
 * This avoids manual activation in wp-admin.
 */

if (!defined('WP_CONTENT_DIR')) {
    return;
}

$plugin_path = WP_CONTENT_DIR . '/plugins/wordpress-metrics/wordpress-metrics.php';
if (file_exists($plugin_path)) {
    include_once $plugin_path;
}
