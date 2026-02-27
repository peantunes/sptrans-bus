<?php
/**
 * API: Rail disruption alert subscriptions by device installation.
 *
 * GET  /api/rail_alert_subscriptions.php?installation_id=<id>
 *   Returns current subscription state for the installation.
 *
 * POST /api/rail_alert_subscriptions.php
 *   JSON payload:
 *   {
 *     "installationId": "<id>",
 *     "action": "set|subscribe|unsubscribe",
 *     "apnsToken": "...",
 *     "notificationsEnabled": true,
 *     "authorizationStatus": "authorized",
 *     "locale": "pt_BR",
 *     "timezone": "America/Sao_Paulo",
 *     "appVersion": "1.0",
 *     "buildVersion": "1",
 *     "lines": [
 *       { "lineId": "metro-1-azul", "source": "metro", "lineNumber": "1", "lineName": "Azul" }
 *     ]
 *   }
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/RailAlertSubscriptionService.class.php');

$cConexao->Conecta();

try {
    $service = new RailAlertSubscriptionService($cConexao);
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

    if ($method === 'GET') {
        $installationId = $_REQUEST['installation_id'] ?? null;
        $state = $service->getStateByInstallationId($installationId);
        echo json_encode([
            'success' => true,
            'state' => $state
        ]);
    } elseif ($method === 'POST') {
        $rawBody = file_get_contents('php://input');
        $payload = json_decode((string)$rawBody, true);
        if (!is_array($payload)) {
            throw new InvalidArgumentException('Invalid JSON payload');
        }
        $response = $service->applyUpdate($payload);
        echo json_encode($response);
    } else {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
    }
} catch (InvalidArgumentException $e) {
    http_response_code(400);
    echo json_encode([
        'error' => 'Invalid request',
        'message' => $e->getMessage()
    ]);
} catch (Throwable $e) {
    error_log('[rail-alert-subscriptions][api] ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'error' => 'Failed to process rail alert subscriptions',
        'message' => $e->getMessage()
    ]);
}

$cConexao->Desconecta();

