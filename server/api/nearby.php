<?php
/**
 * API: Get nearby stops based on coordinates
 *
 * Parameters:
 *   - lat (required): Latitude
 *   - lon (required): Longitude
 *   - limit (optional): Maximum results (default 20)
 *   - include_arrivals (optional): If "1", include upcoming arrivals for each stop
 *
 * Example: /api/nearby.php?lat=-23.554022&lon=-46.671108&limit=10
 */

// Disable error display, capture instead
error_reporting(E_ALL);
ini_set('display_errors', 0);

// Set JSON header
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Output buffer to catch any unexpected output
ob_start();

try {
    require_once(__DIR__ . '/../inc/Conexao.class.php');
    require_once(__DIR__ . '/../inc/TransitService.class.php');
    require_once(__DIR__ . '/../inc/BusInfo.class.php');

    // Validate required parameters
    if (!isset($_REQUEST['lat']) || !isset($_REQUEST['lon'])) {
        ob_end_clean();
        http_response_code(400);
        echo json_encode(['error' => 'Missing required parameters: lat, lon']);
        exit;
    }

    $lat = (float)$_REQUEST['lat'];
    $lon = (float)$_REQUEST['lon'];
    $limit = isset($_REQUEST['limit']) ? (int)$_REQUEST['limit'] : 20;
    $includeArrivals = isset($_REQUEST['include_arrivals']) && $_REQUEST['include_arrivals'] == '1';

    // Create connection
    date_default_timezone_set('America/Sao_Paulo');
    $cConexao = new Conexao(INT_MYSQL, "mysql", "lolados_bus", "bus@2013", "lolados_bus");
    $cConexao->Conecta();

    // Use existing BusInfo for nearby stops
    $busInfo = new BusInfo($cConexao);
    $stops = $busInfo->listStopsByGeo($lat, $lon);

    // Limit results
    $stops = array_slice($stops, 0, $limit);

    // Optionally include arrivals
    if ($includeArrivals && count($stops) > 0) {
        $service = new TransitService($cConexao);
        foreach ($stops as &$stop) {
            $stop->arrivals = $service->getArrivalsAtStop($stop->id, null, null, 5);
        }
    }

    // Clear any buffered output
    ob_end_clean();

    echo json_encode([
        'lat' => $lat,
        'lon' => $lon,
        'count' => count($stops),
        'stops' => $stops
    ], JSON_UNESCAPED_UNICODE);

    $cConexao->Desconecta();

} catch (Exception $e) {
    $buffered = ob_get_clean();
    http_response_code(500);
    echo json_encode([
        'error' => 'Server error',
        'message' => $e->getMessage(),
        'file' => basename($e->getFile()),
        'line' => $e->getLine(),
        'buffered_output' => $buffered ? substr($buffered, 0, 500) : null
    ], JSON_UNESCAPED_UNICODE);
} catch (Error $e) {
    $buffered = ob_get_clean();
    http_response_code(500);
    echo json_encode([
        'error' => 'PHP Error',
        'message' => $e->getMessage(),
        'file' => basename($e->getFile()),
        'line' => $e->getLine(),
        'buffered_output' => $buffered ? substr($buffered, 0, 500) : null
    ], JSON_UNESCAPED_UNICODE);
}
