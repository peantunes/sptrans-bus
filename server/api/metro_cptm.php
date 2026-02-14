<?php
/**
 * API: Metro + CPTM line status
 *
 * Sources:
 * - Metro: https://www.metro.sp.gov.br/wp-content/themes/metrosp/direto-metro.php
 * - CPTM:  https://api.cptm.sp.gov.br/AppCPTM/v1/Linhas/ObterStatus
 *
 * Cache policy:
 * - Uses DB snapshot if latest fetch is <= 30 minutes old
 * - Refreshes remote source when stale (or when refresh=1)
 *
 * Parameters:
 *   - refresh (optional): set to 1 to force refresh
 *
 * Example:
 *   /api/metro_cptm.php
 *   /api/metro_cptm.php?refresh=1
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/RailStatusService.class.php');

$forceRefresh = isset($_REQUEST['refresh']) && (string)$_REQUEST['refresh'] === '1';

$cConexao->Conecta();

try {
    $service = new RailStatusService($cConexao);
    $response = $service->getLatestStatus($forceRefresh);

    $hasMetro = !empty($response['metro']['available']);
    $hasCptm = !empty($response['cptm']['available']);
    if (!$hasMetro && !$hasCptm && !empty($response['errors'])) {
        http_response_code(502);
    }

    echo json_encode($response);
} catch (Throwable $e) {
    error_log('[rail-status][api] ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'error' => 'Failed to retrieve metro/cptm status',
        'message' => $e->getMessage()
    ]);
}

$cConexao->Desconecta();
