<?php
/**
 * API: Get bus arrivals at a stop
 *
 * Parameters:
 *   - stop_id (required): The stop ID
 *   - time (optional): Reference time in HH:MM:SS format (defaults to current Sao Paulo time)
 *   - date (optional): Reference date in YYYY-MM-DD format (defaults to current Sao Paulo date)
 *   - direction (optional): next (default) or previous
 *   - cursor_time (optional): Cursor time in HH:MM:SS format for pagination
 *   - cursor_date (optional): Cursor date in YYYY-MM-DD format for pagination
 *   - limit (optional): Maximum results (default 20)
 *
 * Example: /api/arrivals.php?stop_id=18848&limit=10
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/TransitService.class.php');

// Validate required parameters
if (!isset($_REQUEST['stop_id']) || empty($_REQUEST['stop_id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameter: stop_id']);
    exit;
}

$stopId = $_REQUEST['stop_id'];
$time = $_REQUEST['time'] ?? null;
$date = $_REQUEST['date'] ?? null;
$direction = $_REQUEST['direction'] ?? 'next';
$cursorTime = $_REQUEST['cursor_time'] ?? null;
$cursorDate = $_REQUEST['cursor_date'] ?? null;
$limit = isset($_REQUEST['limit']) ? (int)$_REQUEST['limit'] : 20;

$direction = strtolower(trim((string)$direction));
if ($direction !== 'next' && $direction !== 'previous') {
    $direction = 'next';
}

$cConexao->Conecta();

$service = new TransitService($cConexao);
$arrivals = $service->getArrivalsAtStop($stopId, $time, $date, $limit, $direction, $cursorTime, $cursorDate);

$queryTime = $time ?? date('H:i:s');
$queryDate = $date ?? date('Y-m-d');

echo json_encode([
    'stopId' => $stopId,
    'queryTime' => $queryTime,
    'queryDate' => $queryDate,
    'queryTimezone' => 'America/Sao_Paulo',
    'direction' => $direction,
    'cursorTime' => $cursorTime,
    'cursorDate' => $cursorDate,
    'count' => count($arrivals),
    'arrivals' => $arrivals
]);

$cConexao->Desconecta();
