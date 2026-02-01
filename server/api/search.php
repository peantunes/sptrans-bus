<?php
/**
 * API: Search stops by name
 *
 * Parameters:
 *   - q (required): Search query
 *   - limit (optional): Maximum results (default 20)
 *
 * Example: /api/search.php?q=Paulista&limit=10
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

ob_start();

try {
    require_once(__DIR__ . '/../inc/Conexao.class.php');
    require_once(__DIR__ . '/../inc/TransitService.class.php');

    // Validate required parameters
    if (!isset($_REQUEST['q']) || empty($_REQUEST['q'])) {
        ob_end_clean();
        http_response_code(400);
        echo json_encode(['error' => 'Missing required parameter: q']);
        exit;
    }

    $query = $_REQUEST['q'];
    $limit = isset($_REQUEST['limit']) ? (int)$_REQUEST['limit'] : 20;

    date_default_timezone_set('America/Sao_Paulo');
    $cConexao = new Conexao(INT_MYSQL, "mysql", "lolados_bus", "bus@2013", "lolados_bus");
    $cConexao->Conecta();

    $service = new TransitService($cConexao);
    $stops = $service->searchStops($query, $limit);

    ob_end_clean();

    echo json_encode([
        'query' => $query,
        'count' => count($stops),
        'stops' => $stops
    ], JSON_UNESCAPED_UNICODE);

    $cConexao->Desconecta();

} catch (Exception $e) {
    $buffered = ob_get_clean();
    http_response_code(500);
    echo json_encode([
        'error' => 'Server error',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
} catch (Error $e) {
    $buffered = ob_get_clean();
    http_response_code(500);
    echo json_encode([
        'error' => 'PHP Error',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
