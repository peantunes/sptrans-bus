<?php
/**
 * API: Get trip route details
 *
 * Parameters:
 *   - trip_id (required): The trip ID
 *
 * Example: /api/trip.php?trip_id=1012-10-0
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/TransitService.class.php');

// Validate required parameters
if (!isset($_REQUEST['trip_id']) || empty($_REQUEST['trip_id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameter: trip_id']);
    exit;
}

$tripId = $_REQUEST['trip_id'];

$cConexao->Conecta();

$service = new TransitService($cConexao);
$trip = $service->getTripRoute($tripId);

if ($trip === null) {
    http_response_code(404);
    echo json_encode(['error' => 'Trip not found', 'tripId' => $tripId]);
} else {
    echo json_encode([
        'trip' => $trip
    ]);
}

$cConexao->Desconecta();
