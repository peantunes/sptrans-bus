<?php

class RailAlertSubscriptionService {
    const SOURCE_METRO = 'metro';
    const SOURCE_CPTM = 'cptm';

    const ACTION_SET = 'set';
    const ACTION_SUBSCRIBE = 'subscribe';
    const ACTION_UNSUBSCRIBE = 'unsubscribe';

    private $con;
    private $timezone;

    public function __construct($con) {
        $this->con = $con;
        $this->timezone = new DateTimeZone('America/Sao_Paulo');
    }

    public function getStateByInstallationId($installationId) {
        $this->ensureSchema();
        $normalizedInstallationId = $this->normalizeInstallationId($installationId);
        $device = $this->fetchDeviceByInstallationId($normalizedInstallationId);
        if (!$device) {
            return [
                'installationId' => $normalizedInstallationId,
                'platform' => 'ios',
                'apnsToken' => null,
                'notificationsEnabled' => false,
                'authorizationStatus' => null,
                'locale' => null,
                'timezone' => null,
                'appVersion' => null,
                'buildVersion' => null,
                'lastSeenAt' => null,
                'subscriptions' => []
            ];
        }

        return $this->buildStateFromDeviceRow($device);
    }

    public function applyUpdate($payload) {
        $this->ensureSchema();

        if (!is_array($payload)) {
            throw new InvalidArgumentException('Invalid request payload');
        }

        $installationId = $this->normalizeInstallationId($payload['installationId'] ?? null);
        $action = $this->normalizeAction($payload['action'] ?? self::ACTION_SET);
        $lines = $this->normalizeLines($payload['lines'] ?? []);

        $this->con->BeginTrans();
        try {
            $deviceId = $this->upsertDevice($installationId, $payload);

            if ($action === self::ACTION_SET) {
                $this->deactivateAllLines($deviceId);
                $this->upsertLines($deviceId, $lines);
            } elseif ($action === self::ACTION_SUBSCRIBE) {
                $this->upsertLines($deviceId, $lines);
            } elseif ($action === self::ACTION_UNSUBSCRIBE) {
                if (empty($lines)) {
                    $this->deactivateAllLines($deviceId);
                } else {
                    $this->deactivateLines($deviceId, $lines);
                }
            }

            $this->con->CommitTrans();
            $state = $this->getStateByDeviceId($deviceId);

            return [
                'success' => true,
                'action' => $action,
                'subscriptionCount' => count($state['subscriptions']),
                'state' => $state
            ];
        } catch (Throwable $e) {
            $this->con->RollBackTrans();
            throw $e;
        }
    }

    private function normalizeInstallationId($value) {
        $installationId = trim((string)$value);
        if ($installationId === '') {
            throw new InvalidArgumentException('Missing required field: installationId');
        }
        if (strlen($installationId) > 64) {
            $installationId = substr($installationId, 0, 64);
        }
        return $installationId;
    }

    private function normalizeAction($value) {
        $action = strtolower(trim((string)$value));
        if ($action === '') {
            $action = self::ACTION_SET;
        }
        $allowed = [self::ACTION_SET, self::ACTION_SUBSCRIBE, self::ACTION_UNSUBSCRIBE];
        if (!in_array($action, $allowed, true)) {
            throw new InvalidArgumentException('Invalid action. Allowed values: set, subscribe, unsubscribe');
        }
        return $action;
    }

    private function normalizeLines($linesRaw) {
        if (!is_array($linesRaw)) {
            return [];
        }

        $normalized = [];
        foreach ($linesRaw as $lineRaw) {
            if (!is_array($lineRaw)) {
                continue;
            }

            $source = strtolower(trim((string)($lineRaw['source'] ?? '')));
            if ($source !== self::SOURCE_METRO && $source !== self::SOURCE_CPTM) {
                continue;
            }

            $lineNumber = trim((string)($lineRaw['lineNumber'] ?? ''));
            if (strlen($lineNumber) > 32) {
                $lineNumber = substr($lineNumber, 0, 32);
            }

            $lineName = trim((string)($lineRaw['lineName'] ?? ''));
            if (strlen($lineName) > 128) {
                $lineName = substr($lineName, 0, 128);
            }
            if ($lineName === '') {
                $lineName = $lineNumber !== '' ? ('Linha ' . $lineNumber) : 'Linha';
            }

            $lineId = trim((string)($lineRaw['lineId'] ?? ''));
            if ($lineId === '') {
                $lineId = $source . '-' . ($lineNumber !== '' ? $lineNumber : md5($lineName));
            }
            if (strlen($lineId) > 128) {
                $lineId = substr($lineId, 0, 128);
            }

            $normalized[$lineId] = [
                'lineId' => $lineId,
                'source' => $source,
                'lineNumber' => $lineNumber,
                'lineName' => $lineName
            ];
        }

        return array_values($normalized);
    }

    private function normalizeNullableString($value, $maxLen = 255) {
        if ($value === null) {
            return null;
        }
        $str = trim((string)$value);
        if ($str === '') {
            return null;
        }
        if (strlen($str) > $maxLen) {
            $str = substr($str, 0, $maxLen);
        }
        return $str;
    }

    private function normalizeBoolean($value) {
        if (is_bool($value)) {
            return $value;
        }
        if (is_int($value) || is_float($value)) {
            return ((int)$value) !== 0;
        }
        $str = strtolower(trim((string)$value));
        return in_array($str, ['1', 'true', 'yes', 'on'], true);
    }

    private function upsertDevice($installationId, $payload) {
        $platform = $this->normalizeNullableString($payload['platform'] ?? 'ios', 16);
        if ($platform === null) {
            $platform = 'ios';
        }

        $apnsToken = $this->normalizeNullableString($payload['apnsToken'] ?? null, 255);
        $notificationsEnabled = $this->normalizeBoolean($payload['notificationsEnabled'] ?? false) ? 1 : 0;
        $authorizationStatus = $this->normalizeNullableString($payload['authorizationStatus'] ?? null, 32);
        $locale = $this->normalizeNullableString($payload['locale'] ?? null, 16);
        $timezone = $this->normalizeNullableString($payload['timezone'] ?? null, 64);
        $appVersion = $this->normalizeNullableString($payload['appVersion'] ?? null, 32);
        $buildVersion = $this->normalizeNullableString($payload['buildVersion'] ?? null, 32);

        $now = $this->nowString();

        $this->con->ExecutaPrepared(
            "INSERT INTO sp_transit_alert_devices
                (installation_id, platform, apns_token, notifications_enabled, authorization_status, locale, timezone, app_version, build_version, last_seen_at, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                platform = VALUES(platform),
                apns_token = IF(VALUES(apns_token) IS NULL OR VALUES(apns_token) = '', apns_token, VALUES(apns_token)),
                notifications_enabled = VALUES(notifications_enabled),
                authorization_status = VALUES(authorization_status),
                locale = VALUES(locale),
                timezone = VALUES(timezone),
                app_version = VALUES(app_version),
                build_version = VALUES(build_version),
                last_seen_at = VALUES(last_seen_at),
                updated_at = VALUES(updated_at)",
            "sssissssssss",
            [
                $installationId,
                $platform,
                $apnsToken,
                $notificationsEnabled,
                $authorizationStatus,
                $locale,
                $timezone,
                $appVersion,
                $buildVersion,
                $now,
                $now,
                $now
            ]
        );

        $this->con->ExecutaPrepared(
            "SELECT device_id FROM sp_transit_alert_devices WHERE installation_id = ? LIMIT 1",
            "s",
            [$installationId]
        );
        $row = $this->con->Linha();
        if (!$row || !isset($row['device_id'])) {
            throw new RuntimeException('Failed to resolve alert device after upsert');
        }
        return (int)$row['device_id'];
    }

    private function deactivateAllLines($deviceId) {
        $now = $this->nowString();
        $this->con->ExecutaPrepared(
            "UPDATE sp_transit_alert_line_subscriptions
             SET is_active = 0, updated_at = ?
             WHERE device_id = ? AND is_active = 1",
            "si",
            [$now, (int)$deviceId]
        );
    }

    private function upsertLines($deviceId, $lines) {
        if (empty($lines)) {
            return;
        }

        $now = $this->nowString();
        foreach ($lines as $line) {
            $this->con->ExecutaPrepared(
                "INSERT INTO sp_transit_alert_line_subscriptions
                    (device_id, line_id_key, source, line_number, line_name, is_active, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, 1, ?, ?)
                 ON DUPLICATE KEY UPDATE
                    source = VALUES(source),
                    line_number = VALUES(line_number),
                    line_name = VALUES(line_name),
                    is_active = 1,
                    updated_at = VALUES(updated_at)",
                "issssss",
                [
                    (int)$deviceId,
                    $line['lineId'],
                    $line['source'],
                    $line['lineNumber'],
                    $line['lineName'],
                    $now,
                    $now
                ]
            );
        }
    }

    private function deactivateLines($deviceId, $lines) {
        if (empty($lines)) {
            return;
        }

        $now = $this->nowString();
        foreach ($lines as $line) {
            $this->con->ExecutaPrepared(
                "UPDATE sp_transit_alert_line_subscriptions
                 SET is_active = 0, updated_at = ?
                 WHERE device_id = ? AND line_id_key = ?",
                "sis",
                [$now, (int)$deviceId, $line['lineId']]
            );
        }
    }

    private function fetchDeviceByInstallationId($installationId) {
        $this->con->ExecutaPrepared(
            "SELECT
                device_id,
                installation_id,
                platform,
                apns_token,
                notifications_enabled,
                authorization_status,
                locale,
                timezone,
                app_version,
                build_version,
                last_seen_at
             FROM sp_transit_alert_devices
             WHERE installation_id = ?
             LIMIT 1",
            "s",
            [$installationId]
        );
        return $this->con->Linha();
    }

    private function getStateByDeviceId($deviceId) {
        $this->con->ExecutaPrepared(
            "SELECT
                device_id,
                installation_id,
                platform,
                apns_token,
                notifications_enabled,
                authorization_status,
                locale,
                timezone,
                app_version,
                build_version,
                last_seen_at
             FROM sp_transit_alert_devices
             WHERE device_id = ?
             LIMIT 1",
            "i",
            [(int)$deviceId]
        );
        $device = $this->con->Linha();
        if (!$device) {
            throw new RuntimeException('Alert device not found');
        }
        return $this->buildStateFromDeviceRow($device);
    }

    private function buildStateFromDeviceRow($device) {
        $deviceId = (int)($device['device_id'] ?? 0);
        $subscriptions = [];

        if ($deviceId > 0) {
            $this->con->ExecutaPrepared(
                "SELECT line_id_key, source, line_number, line_name
                 FROM sp_transit_alert_line_subscriptions
                 WHERE device_id = ? AND is_active = 1
                 ORDER BY source, line_number, line_name",
                "i",
                [$deviceId]
            );

            while ($row = $this->con->Linha()) {
                $subscriptions[] = [
                    'lineId' => $row['line_id_key'] ?? '',
                    'source' => $row['source'] ?? '',
                    'lineNumber' => $row['line_number'] ?? '',
                    'lineName' => $row['line_name'] ?? ''
                ];
            }
        }

        return [
            'installationId' => $device['installation_id'] ?? '',
            'platform' => $device['platform'] ?? 'ios',
            'apnsToken' => $device['apns_token'] ?? null,
            'notificationsEnabled' => ((int)($device['notifications_enabled'] ?? 0)) === 1,
            'authorizationStatus' => $device['authorization_status'] ?? null,
            'locale' => $device['locale'] ?? null,
            'timezone' => $device['timezone'] ?? null,
            'appVersion' => $device['app_version'] ?? null,
            'buildVersion' => $device['build_version'] ?? null,
            'lastSeenAt' => $device['last_seen_at'] ?? null,
            'subscriptions' => $subscriptions
        ];
    }

    private function nowString() {
        $dt = new DateTimeImmutable('now', $this->timezone);
        return $dt->format('Y-m-d H:i:s');
    }

    private function ensureSchema() {
        $this->con->Executa("
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
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->con->Executa("
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
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }
}

