<?php
/**
 * API: Get shape points for drawing route on map
 *
 * Parameters:
 *   - shape_id (required): The shape ID
 *   - format (optional): "geojson" for GeoJSON format, default is array
 *
 * Example: /api/shape.php?shape_id=84609
 * Example: /api/shape.php?shape_id=84609&format=geojson
 */

include(__DIR__ . '/../config.php');
require_once(__DIR__ . '/../inc/TransitService.class.php');

// Validate required parameters
if (!isset($_REQUEST['shape_id']) || empty($_REQUEST['shape_id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameter: shape_id']);
    exit;
}

$shapeId = $_REQUEST['shape_id'];
$format = $_REQUEST['format'] ?? 'array';

$cConexao->Conecta();

$service = new TransitService($cConexao);
$points = $service->getShape($shapeId);

if (empty($points)) {
    http_response_code(404);
    echo json_encode(['error' => 'Shape not found', 'shapeId' => $shapeId]);
} else {
    if ($format === 'geojson') {
        // Return as GeoJSON LineString
        $coordinates = array_map(function($point) {
            return [$point->lon, $point->lat];
        }, $points);

        echo json_encode([
            'type' => 'Feature',
            'properties' => [
                'shapeId' => $shapeId
            ],
            'geometry' => [
                'type' => 'LineString',
                'coordinates' => $coordinates
            ]
        ]);
    } else {
        echo json_encode([
            'shapeId' => $shapeId,
            'count' => count($points),
            'points' => $points
        ]);
    }
}

$cConexao->Desconecta();
