<?php
/**
 * API: Get all routes (paginated)
 *
 * Parameters:
 *   - limit (optional): Maximum results (default 100)
 *   - offset (optional): Offset for pagination (default 0)
 *
 * Example: /api/routes.php?limit=50&offset=0
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/TransitService.class.php');

$limit = isset($_REQUEST['limit']) ? (int)$_REQUEST['limit'] : 100;
$offset = isset($_REQUEST['offset']) ? (int)$_REQUEST['offset'] : 0;

$cConexao->Conecta();

$service = new TransitService($cConexao);
$routes = $service->getAllRoutes($limit, $offset);

echo json_encode([
    'limit' => $limit,
    'offset' => $offset,
    'count' => count($routes),
    'routes' => $routes
]);

$cConexao->Desconecta();
