<?php
/**
 * API: Get route information
 *
 * Parameters:
 *   - route_id (required): The route ID
 *
 * Example: /api/route.php?route_id=1012-10
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/TransitService.class.php');

// Validate required parameters
if (!isset($_REQUEST['route_id']) || empty($_REQUEST['route_id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameter: route_id']);
    exit;
}

$routeId = $_REQUEST['route_id'];

$cConexao->Conecta();

$service = new TransitService($cConexao);
$route = $service->getRouteInfo($routeId);

if ($route === null) {
    http_response_code(404);
    echo json_encode(['error' => 'Route not found', 'routeId' => $routeId]);
} else {
    // Also get fare information
    $fare = $service->getFare($routeId);
    echo json_encode([
        'route' => $route,
        'fare' => $fare
    ]);
}

$cConexao->Desconecta();
