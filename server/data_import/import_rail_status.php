<?php
/**
 * Import Metro/CPTM rail status into MySQL snapshots.
 *
 * Usage:
 *   php import_rail_status.php [--source=all|metro|cptm] [--force]
 *
 * Examples:
 *   php import_rail_status.php
 *   php import_rail_status.php --source=metro --force
 */

date_default_timezone_set('America/Sao_Paulo');

require_once(__DIR__ . '/../inc/Conexao.class.php');
require_once(__DIR__ . '/../inc/RailStatusService.class.php');

function parseArgs($argv) {
    $options = [
        'source' => 'all',
        'force' => false
    ];

    foreach ($argv as $arg) {
        if (strpos($arg, '--source=') === 0) {
            $options['source'] = strtolower(trim(substr($arg, strlen('--source='))));
            continue;
        }
        if ($arg === '--force') {
            $options['force'] = true;
            continue;
        }
    }

    if (!in_array($options['source'], ['all', 'metro', 'cptm'], true)) {
        fwrite(STDERR, "Invalid --source value. Use: all, metro, or cptm\n");
        exit(1);
    }

    return $options;
}

$options = parseArgs($argv ?? []);

try {
    $con = new Conexao(INT_MYSQL, "mysql", "lolados_bus", "bus@2013", "lolados_bus");
    $con->Conecta();

    $service = new RailStatusService($con);
    $result = $service->refreshForImportScript($options['source'], $options['force']);

    echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . PHP_EOL;

    $con->Desconecta();
} catch (Throwable $e) {
    error_log('[rail-status][script] ' . $e->getMessage());
    fwrite(STDERR, "Rail status import failed: " . $e->getMessage() . PHP_EOL);
    exit(1);
}

