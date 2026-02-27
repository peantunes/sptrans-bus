<?php
/**
 * API: Rail status historical report
 *
 * Parameters:
 *   - period_days (optional): 7, 14, 30 (default: 7)
 *   - source (optional): metro|cptm
 *   - line_number (optional): exact line number filter
 *
 * Examples:
 *   /api/rail_status_report.php
 *   /api/rail_status_report.php?period_days=14
 *   /api/rail_status_report.php?period_days=30&source=metro
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/RailStatusService.class.php');

$periodDays = isset($_REQUEST['period_days']) ? (int)$_REQUEST['period_days'] : 7;
if (!in_array($periodDays, [7, 14, 30], true)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid parameter: period_days (allowed: 7, 14, 30)']);
    exit;
}

$source = isset($_REQUEST['source']) ? strtolower(trim((string)$_REQUEST['source'])) : null;
if ($source === '') {
    $source = null;
}
if ($source !== null && $source !== RailStatusService::SOURCE_METRO && $source !== RailStatusService::SOURCE_CPTM) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid parameter: source (allowed: metro, cptm)']);
    exit;
}

$lineNumber = isset($_REQUEST['line_number']) ? trim((string)$_REQUEST['line_number']) : null;
if ($lineNumber === '') {
    $lineNumber = null;
}

$cConexao->Conecta();

try {
    $service = new RailStatusService($cConexao);
    $response = $service->getHistoricalReport($periodDays, $source, $lineNumber);
    echo json_encode($response);
} catch (Throwable $e) {
    error_log('[rail-status][report] ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'error' => 'Failed to build rail status report',
        'message' => $e->getMessage()
    ]);
}

$cConexao->Desconecta();

