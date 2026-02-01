<?php
/**
 * API: Get stop information
 *
 * Parameters:
 *   - stop_id (required): The stop ID
 *   - include_arrivals (optional): If "1", include upcoming arrivals
 *
 * Example: /api/stop.php?stop_id=18848&include_arrivals=1
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
$includeArrivals = isset($_REQUEST['include_arrivals']) && $_REQUEST['include_arrivals'] == '1';

$cConexao->Conecta();

$service = new TransitService($cConexao);
$stop = $service->getStopInfo($stopId);

if ($stop === null) {
    http_response_code(404);
    echo json_encode(['error' => 'Stop not found', 'stopId' => $stopId]);
} else {
    $response = ['stop' => $stop];

    // Optionally include routes at this stop
    $response['routesAtStop'] = $service->getRoutesAtStop($stopId);

    // Optionally include upcoming arrivals
    if ($includeArrivals) {
        $response['arrivals'] = $service->getArrivalsAtStop($stopId, null, null, 10);
    }

    echo json_encode($response);
}

$cConexao->Desconecta();
