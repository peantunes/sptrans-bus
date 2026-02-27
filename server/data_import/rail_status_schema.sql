-- Rail status tables (Metro + CPTM)
-- Run in MySQL database: lolados_bus

CREATE TABLE IF NOT EXISTS sp_transit_status_snapshots (
    snapshot_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    source ENUM('metro','cptm') NOT NULL,
    fetched_at DATETIME NOT NULL,
    source_updated_at DATETIME NULL,
    line_count INT UNSIGNED NOT NULL DEFAULT 0,
    raw_hash CHAR(64) NULL,
    PRIMARY KEY (snapshot_id),
    KEY idx_status_snapshots_source_fetched (source, fetched_at),
    KEY idx_status_snapshots_source_updated (source, source_updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sp_transit_status_lines (
    line_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    snapshot_id BIGINT UNSIGNED NOT NULL,
    source ENUM('metro','cptm') NOT NULL,
    line_number VARCHAR(32) NOT NULL,
    line_name VARCHAR(128) NOT NULL,
    status_text VARCHAR(255) NOT NULL,
    status_detail VARCHAR(512) NULL,
    status_color VARCHAR(16) NULL,
    source_updated_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (line_id),
    KEY idx_status_lines_snapshot (snapshot_id),
    KEY idx_status_lines_source_line (source, line_number),
    CONSTRAINT fk_status_lines_snapshot
        FOREIGN KEY (snapshot_id) REFERENCES sp_transit_status_snapshots(snapshot_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sp_transit_status_errors (
    source ENUM('metro','cptm') NOT NULL,
    first_failed_at DATETIME NULL,
    last_failed_at DATETIME NULL,
    last_success_at DATETIME NULL,
    last_email_sent_at DATETIME NULL,
    consecutive_failures INT UNSIGNED NOT NULL DEFAULT 0,
    last_error_message TEXT NULL,
    PRIMARY KEY (source)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Device notification subscriptions for rail disruption alerts
CREATE TABLE IF NOT EXISTS sp_transit_alert_devices (
    device_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    installation_id VARCHAR(64) NOT NULL,
    platform VARCHAR(16) NOT NULL DEFAULT 'ios',
    apns_token VARCHAR(255) NULL,
    notifications_enabled TINYINT(1) NOT NULL DEFAULT 0,
    authorization_status VARCHAR(32) NULL,
    locale VARCHAR(16) NULL,
    timezone VARCHAR(64) NULL,
    app_version VARCHAR(32) NULL,
    build_version VARCHAR(32) NULL,
    last_seen_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (device_id),
    UNIQUE KEY uniq_alert_devices_installation (installation_id),
    KEY idx_alert_devices_apns_token (apns_token),
    KEY idx_alert_devices_platform (platform)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sp_transit_alert_line_subscriptions (
    subscription_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    device_id BIGINT UNSIGNED NOT NULL,
    line_id_key VARCHAR(128) NOT NULL,
    source ENUM('metro','cptm') NOT NULL,
    line_number VARCHAR(32) NOT NULL,
    line_name VARCHAR(128) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (subscription_id),
    UNIQUE KEY uniq_alert_device_line (device_id, line_id_key),
    KEY idx_alert_line_source_number (source, line_number),
    KEY idx_alert_line_active (is_active),
    CONSTRAINT fk_alert_line_device
        FOREIGN KEY (device_id) REFERENCES sp_transit_alert_devices(device_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
