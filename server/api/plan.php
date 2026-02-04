<?php
/**
 * API: Simple trip planning between two points
 *
 * Parameters:
 *   - origin_lat (required): Origin latitude
 *   - origin_lon (required): Origin longitude
 *   - dest_lat (required): Destination latitude
 *   - dest_lon (required): Destination longitude
 *   - origin_limit (optional): Nearby origin stops to consider (default 5)
 *   - destination_limit (optional): Nearby destination stops to consider (default 5)
 *   - direct_limit (optional): Max direct route suggestions (default 6)
 *   - transfer_limit (optional): Max 1-transfer suggestions (default 6)
 *   - max_transfers (optional): 0 or 1 (default 1)
 *   - max_alternatives (optional): Max combined alternatives (default 5)
 *   - ranking_priority (optional): arrives_first | shortest | fewest_transfers | closest_origin | closest_destination (default arrives_first)
 *
 * Example:
 * /api/plan.php?origin_lat=-23.561&origin_lon=-46.656&dest_lat=-23.55&dest_lon=-46.63
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

ob_start();

try {
    require_once(__DIR__ . '/../inc/Conexao.class.php');
    require_once(__DIR__ . '/../inc/BusInfo.class.php');
    require_once(__DIR__ . '/../inc/TripPlanner.class.php');

    $required = ['origin_lat', 'origin_lon', 'dest_lat', 'dest_lon'];
    foreach ($required as $param) {
        if (!isset($_REQUEST[$param]) || $_REQUEST[$param] === '') {
            ob_end_clean();
            http_response_code(400);
            echo json_encode(['error' => "Missing required parameter: $param"]);
            exit;
        }
    }

    $originLat = (float)$_REQUEST['origin_lat'];
    $originLon = (float)$_REQUEST['origin_lon'];
    $destLat = (float)$_REQUEST['dest_lat'];
    $destLon = (float)$_REQUEST['dest_lon'];

    $originLimit = isset($_REQUEST['origin_limit']) ? (int)$_REQUEST['origin_limit'] : 5;
    $destinationLimit = isset($_REQUEST['destination_limit']) ? (int)$_REQUEST['destination_limit'] : 5;
    $directLimit = isset($_REQUEST['direct_limit']) ? (int)$_REQUEST['direct_limit'] : 6;
    $transferLimit = isset($_REQUEST['transfer_limit']) ? (int)$_REQUEST['transfer_limit'] : 6;
    $maxTransfers = isset($_REQUEST['max_transfers']) ? (int)$_REQUEST['max_transfers'] : 1;
    $maxAlternatives = isset($_REQUEST['max_alternatives']) ? (int)$_REQUEST['max_alternatives'] : 5;
    $rankingPriority = isset($_REQUEST['ranking_priority']) ? $_REQUEST['ranking_priority'] : 'arrives_first';

    date_default_timezone_set('America/Sao_Paulo');
    $cConexao = new Conexao(INT_MYSQL, "mysql", "lolados_bus", "bus@2013", "lolados_bus");
    $cConexao->Conecta();

    $planner = new TripPlanner($cConexao);
    $result = $planner->plan($originLat, $originLon, $destLat, $destLon, [
        'origin_limit' => $originLimit,
        'destination_limit' => $destinationLimit,
        'direct_limit' => $directLimit,
        'transfer_limit' => $transferLimit,
        'max_transfers' => $maxTransfers,
        'max_alternatives' => $maxAlternatives,
        'ranking_priority' => $rankingPriority
    ]);

    ob_end_clean();

    echo json_encode([
        'origin_lat' => $originLat,
        'origin_lon' => $originLon,
        'dest_lat' => $destLat,
        'dest_lon' => $destLon,
        'options' => [
            'origin_limit' => $originLimit,
            'destination_limit' => $destinationLimit,
            'direct_limit' => $directLimit,
            'transfer_limit' => $transferLimit,
            'max_transfers' => $maxTransfers,
            'max_alternatives' => $maxAlternatives,
            'ranking_priority' => $rankingPriority
        ],
        'result' => $result
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
