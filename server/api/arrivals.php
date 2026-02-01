<?php
/**
 * API: Get bus arrivals at a stop
 *
 * Parameters:
 *   - stop_id (required): The stop ID
 *   - time (optional): Time in HH:MM:SS format (defaults to current time)
 *   - date (optional): Date in YYYY-MM-DD format (defaults to today)
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
$limit = isset($_REQUEST['limit']) ? (int)$_REQUEST['limit'] : 20;

$cConexao->Conecta();

$service = new TransitService($cConexao);
$arrivals = $service->getArrivalsAtStop($stopId, $time, $date, $limit);

echo json_encode([
    'stopId' => $stopId,
    'queryTime' => $time ?? date('H:i:s'),
    'queryDate' => $date ?? date('Y-m-d'),
    'count' => count($arrivals),
    'arrivals' => $arrivals
]);

$cConexao->Desconecta();
