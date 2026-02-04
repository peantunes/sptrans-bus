<?php

require_once(__DIR__ . '/TransitService.class.php');

class TripPlanner {
    private $con;
    private $busInfo;
    private $transitService;

    public function __construct($con) {
        $this->con = $con;
        $this->busInfo = new BusInfo($con);
        $this->transitService = new TransitService($con);
    }

    public function plan($originLat, $originLon, $destLat, $destLon, $options = []) {
        $maxAlternatives = $this->clampInt($options['max_alternatives'] ?? 5, 1, 10, 5);
        $originLimit = $this->clampInt($options['origin_limit'] ?? 5, 1, 20, 5);
        $destinationLimit = $this->clampInt($options['destination_limit'] ?? 5, 1, 20, 5);
        $directLimit = $this->clampInt($options['direct_limit'] ?? 6, 0, 20, 6);
        $transferLimit = $this->clampInt($options['transfer_limit'] ?? 6, 0, 20, 6);
        $maxTransfers = $this->clampInt($options['max_transfers'] ?? 1, 0, 1, 1);
        $legSearchLimit = $this->clampInt($options['leg_search_limit'] ?? 400, 50, 2000, 400);
        $rankingPriority = $this->normalizePriority($options['ranking_priority'] ?? 'arrives_first');

        $directLimit = min($directLimit, $maxAlternatives);
        $transferLimit = min($transferLimit, $maxAlternatives);

        $originStops = array_slice($this->busInfo->listStopsByGeo($originLat, $originLon), 0, $originLimit);
        $destinationStops = array_slice($this->busInfo->listStopsByGeo($destLat, $destLon), 0, $destinationLimit);

        $originStopMap = $this->mapStopsById($originStops);
        $destinationStopMap = $this->mapStopsById($destinationStops);

        $originStopIds = array_keys($originStopMap);
        $destinationStopIds = array_keys($destinationStopMap);

        $directRoutes = $this->findDirectRoutes($originStopIds, $destinationStopIds, $directLimit, $originStopMap, $destinationStopMap);

        $transferRoutes = [];
        if ($maxTransfers > 0) {
            $transferRoutes = $this->findTransferRoutes(
                $originStopIds,
                $destinationStopIds,
                $originStopMap,
                $destinationStopMap,
                $transferLimit,
                $legSearchLimit
            );
        }

        $alternatives = $this->buildAlternatives($directRoutes, $transferRoutes, $maxAlternatives, $rankingPriority);

        return [
            'origin' => [
                'lat' => (float)$originLat,
                'lon' => (float)$originLon
            ],
            'destination' => [
                'lat' => (float)$destLat,
                'lon' => (float)$destLon
            ],
            'originStops' => array_values($originStops),
            'destinationStops' => array_values($destinationStops),
            'direct' => array_values($directRoutes),
            'transfers' => array_values($transferRoutes),
            'alternatives' => $alternatives,
            'rankingPriority' => $rankingPriority,
            'stats' => [
                'originStopCount' => count($originStops),
                'destinationStopCount' => count($destinationStops),
                'directCount' => count($directRoutes),
                'transferCount' => count($transferRoutes),
                'alternativeCount' => count($alternatives),
                'maxAlternatives' => $maxAlternatives
            ]
        ];
    }

    private function findDirectRoutes($originStopIds, $destinationStopIds, $limit, $originStopMap, $destinationStopMap) {
        if (empty($originStopIds) || empty($destinationStopIds) || $limit === 0) {
            return [];
        }

        $params = [];
        $types = '';
        $originPlaceholders = $this->buildInClause($originStopIds, 's', $types, $params);
        $destinationPlaceholders = $this->buildInClause($destinationStopIds, 's', $types, $params);

        $sql = "SELECT
                    t.route_id,
                    r.route_short_name,
                    r.route_long_name,
                    r.route_color,
                    r.route_text_color,
                    t.trip_id,
                    st1.stop_id AS origin_stop_id,
                    st2.stop_id AS destination_stop_id,
                    st1.stop_sequence AS origin_sequence,
                    st2.stop_sequence AS destination_sequence
                FROM sp_stop_times st1
                JOIN sp_stop_times st2 ON st1.trip_id = st2.trip_id
                JOIN sp_trip t ON t.trip_id = st1.trip_id
                JOIN sp_routes r ON r.route_id = t.route_id
                WHERE st1.stop_id IN ($originPlaceholders)
                  AND st2.stop_id IN ($destinationPlaceholders)
                  AND st1.stop_sequence < st2.stop_sequence
                ORDER BY (st2.stop_sequence - st1.stop_sequence) ASC
                LIMIT ?";

        $types .= 'i';
        $params[] = $limit;

        $this->con->ExecutaPrepared($sql, $types, $params);

        $directRoutes = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;
            $key = $rs['route_id'] . '|' . $rs['origin_stop_id'] . '|' . $rs['destination_stop_id'];
            if (isset($directRoutes[$key])) {
                continue;
            }

            $directRoutes[$key] = [
                'route' => [
                    'routeId' => $rs['route_id'],
                    'shortName' => $rs['route_short_name'] ?? '',
                    'longName' => $rs['route_long_name'] ?? '',
                    'color' => $rs['route_color'] ?? '',
                    'textColor' => $rs['route_text_color'] ?? ''
                ],
                'tripId' => $rs['trip_id'],
                'originStopId' => $rs['origin_stop_id'],
                'destinationStopId' => $rs['destination_stop_id'],
                'originSequence' => (int)$rs['origin_sequence'],
                'destinationSequence' => (int)$rs['destination_sequence'],
                'originStop' => $originStopMap[$rs['origin_stop_id']] ?? null,
                'destinationStop' => $destinationStopMap[$rs['destination_stop_id']] ?? null
            ];
        }

        return array_values($directRoutes);
    }

    private function findTransferRoutes($originStopIds, $destinationStopIds, $originStopMap, $destinationStopMap, $limit, $legSearchLimit) {
        if (empty($originStopIds) || empty($destinationStopIds) || $limit === 0) {
            return [];
        }

        $originLegs = $this->findOriginLegs($originStopIds, $legSearchLimit);
        $destinationLegs = $this->findDestinationLegs($destinationStopIds, $legSearchLimit);

        if (empty($originLegs) || empty($destinationLegs)) {
            return [];
        }

        $destinationByTransfer = [];
        foreach ($destinationLegs as $leg) {
            $destinationByTransfer[$leg['transfer_stop_id']][] = $leg;
        }

        $transferStopIds = [];
        $connections = [];

        foreach ($originLegs as $originLeg) {
            $transferStopId = $originLeg['transfer_stop_id'];
            if (!isset($destinationByTransfer[$transferStopId])) {
                continue;
            }

            foreach ($destinationByTransfer[$transferStopId] as $destinationLeg) {
                if ($originLeg['origin_stop_id'] === $transferStopId || $destinationLeg['destination_stop_id'] === $transferStopId) {
                    continue;
                }

                if ($originLeg['origin_route_id'] === $destinationLeg['destination_route_id']) {
                    continue;
                }

                $key = implode('|', [
                    $originLeg['origin_route_id'],
                    $destinationLeg['destination_route_id'],
                    $originLeg['origin_stop_id'],
                    $destinationLeg['destination_stop_id'],
                    $transferStopId
                ]);

                if (isset($connections[$key])) {
                    continue;
                }

                $connections[$key] = [
                    'originRoute' => [
                        'routeId' => $originLeg['origin_route_id'],
                        'shortName' => $originLeg['origin_route_short_name'] ?? '',
                        'longName' => $originLeg['origin_route_long_name'] ?? '',
                        'color' => $originLeg['origin_route_color'] ?? '',
                        'textColor' => $originLeg['origin_route_text_color'] ?? ''
                    ],
                    'destinationRoute' => [
                        'routeId' => $destinationLeg['destination_route_id'],
                        'shortName' => $destinationLeg['destination_route_short_name'] ?? '',
                        'longName' => $destinationLeg['destination_route_long_name'] ?? '',
                        'color' => $destinationLeg['destination_route_color'] ?? '',
                        'textColor' => $destinationLeg['destination_route_text_color'] ?? ''
                    ],
                    'originStopId' => $originLeg['origin_stop_id'],
                    'destinationStopId' => $destinationLeg['destination_stop_id'],
                    'transferStopId' => $transferStopId,
                    'originStop' => $originStopMap[$originLeg['origin_stop_id']] ?? null,
                    'destinationStop' => $destinationStopMap[$destinationLeg['destination_stop_id']] ?? null,
                    'originSequence' => (int)$originLeg['origin_sequence'],
                    'transferSequence' => (int)$originLeg['transfer_sequence'],
                    'destinationSequence' => (int)$destinationLeg['destination_sequence']
                ];

                $transferStopIds[$transferStopId] = true;

                if (count($connections) >= $limit) {
                    break 2;
                }
            }
        }

        if (!empty($transferStopIds)) {
            $transferStops = $this->loadStopsByIds(array_keys($transferStopIds));
            foreach ($connections as &$connection) {
                $transferId = $connection['transferStopId'];
                $connection['transferStop'] = $transferStops[$transferId] ?? null;
            }
        }

        return array_values($connections);
    }

    private function findOriginLegs($originStopIds, $limit) {
        $params = [];
        $types = '';
        $originPlaceholders = $this->buildInClause($originStopIds, 's', $types, $params);

        $sql = "SELECT DISTINCT
                    t.route_id AS origin_route_id,
                    r.route_short_name AS origin_route_short_name,
                    r.route_long_name AS origin_route_long_name,
                    r.route_color AS origin_route_color,
                    r.route_text_color AS origin_route_text_color,
                    st1.stop_id AS origin_stop_id,
                    st2.stop_id AS transfer_stop_id,
                    st1.stop_sequence AS origin_sequence,
                    st2.stop_sequence AS transfer_sequence
                FROM sp_stop_times st1
                JOIN sp_stop_times st2 ON st1.trip_id = st2.trip_id
                JOIN sp_trip t ON t.trip_id = st1.trip_id
                JOIN sp_routes r ON r.route_id = t.route_id
                WHERE st1.stop_id IN ($originPlaceholders)
                  AND st2.stop_sequence > st1.stop_sequence
                LIMIT ?";

        $types .= 'i';
        $params[] = $limit;

        $this->con->ExecutaPrepared($sql, $types, $params);

        $rows = [];
        while ($this->con->Linha()) {
            $rows[] = $this->con->rs;
        }

        return $rows;
    }

    private function findDestinationLegs($destinationStopIds, $limit) {
        $params = [];
        $types = '';
        $destinationPlaceholders = $this->buildInClause($destinationStopIds, 's', $types, $params);

        $sql = "SELECT DISTINCT
                    t.route_id AS destination_route_id,
                    r.route_short_name AS destination_route_short_name,
                    r.route_long_name AS destination_route_long_name,
                    r.route_color AS destination_route_color,
                    r.route_text_color AS destination_route_text_color,
                    st1.stop_id AS destination_stop_id,
                    st2.stop_id AS transfer_stop_id,
                    st2.stop_sequence AS transfer_sequence,
                    st1.stop_sequence AS destination_sequence
                FROM sp_stop_times st1
                JOIN sp_stop_times st2 ON st1.trip_id = st2.trip_id
                JOIN sp_trip t ON t.trip_id = st1.trip_id
                JOIN sp_routes r ON r.route_id = t.route_id
                WHERE st1.stop_id IN ($destinationPlaceholders)
                  AND st2.stop_sequence < st1.stop_sequence
                LIMIT ?";

        $types .= 'i';
        $params[] = $limit;

        $this->con->ExecutaPrepared($sql, $types, $params);

        $rows = [];
        while ($this->con->Linha()) {
            $rows[] = $this->con->rs;
        }

        return $rows;
    }

    private function buildAlternatives($directRoutes, $transferRoutes, $maxAlternatives, $rankingPriority) {
        $candidates = [];

        foreach ($directRoutes as $route) {
            $candidates[] = $this->buildCandidate('direct', $route, $rankingPriority);
        }

        foreach ($transferRoutes as $route) {
            $candidates[] = $this->buildCandidate('transfer', $route, $rankingPriority);
        }

        usort($candidates, function($a, $b) {
            return $this->compareSortKey($a['sortKey'], $b['sortKey']);
        });

        $alternatives = [];
        foreach (array_slice($candidates, 0, $maxAlternatives) as $candidate) {
            $alternatives[] = [
                'type' => $candidate['type'],
                'data' => $candidate['data']
            ];
        }

        return $alternatives;
    }

    private function buildCandidate($type, $route, $rankingPriority) {
        $metrics = $this->computeMetrics($type, $route);
        $sortKey = $this->buildSortKey($metrics, $rankingPriority, $route, $type);

        return [
            'type' => $type,
            'data' => $route,
            'metrics' => $metrics,
            'sortKey' => $sortKey
        ];
    }

    private function computeMetrics($type, $route) {
        $transferCount = $type === 'transfer' ? 1 : 0;
        $hopCount = $this->computeHopCount($type, $route);
        $originDistance = $this->safeDistance($route['originStop'] ?? null);
        $destinationDistance = $this->safeDistance($route['destinationStop'] ?? null);

        return [
            'transferCount' => $transferCount,
            'hopCount' => $hopCount,
            'originDistance' => $originDistance,
            'destinationDistance' => $destinationDistance
        ];
    }

    private function buildSortKey($metrics, $rankingPriority, $route, $type) {
        $arrivalScore = $this->computeArrivalScore($rankingPriority, $route, $type);

        switch ($rankingPriority) {
            case 'shortest':
                return [$metrics['hopCount'], $metrics['transferCount'], $arrivalScore, $metrics['originDistance'] + $metrics['destinationDistance']];
            case 'fewest_transfers':
                return [$metrics['transferCount'], $metrics['hopCount'], $arrivalScore];
            case 'closest_origin':
                return [$metrics['originDistance'], $metrics['hopCount'], $arrivalScore];
            case 'closest_destination':
                return [$metrics['destinationDistance'], $metrics['hopCount'], $arrivalScore];
            case 'arrives_first':
            default:
                return [$arrivalScore, $metrics['transferCount'], $metrics['hopCount'], $metrics['originDistance'] + $metrics['destinationDistance']];
        }
    }

    private function computeArrivalScore($rankingPriority, $route, $type) {
        if ($rankingPriority !== 'arrives_first') {
            return PHP_INT_MAX;
        }

        $originRouteId = $type === 'transfer' ? ($route['originRoute']['routeId'] ?? null) : ($route['route']['routeId'] ?? null);
        $originStopId = $route['originStopId'] ?? null;
        $originWait = $this->getNextArrivalWait($originStopId, $originRouteId);

        if ($type !== 'transfer') {
            return $originWait !== null ? $originWait : PHP_INT_MAX;
        }

        $transferStopId = $route['transferStopId'] ?? null;
        $destinationRouteId = $route['destinationRoute']['routeId'] ?? null;
        $transferWait = $this->getNextArrivalWait($transferStopId, $destinationRouteId);

        if ($originWait === null && $transferWait === null) {
            return PHP_INT_MAX;
        }

        $originWait = $originWait ?? PHP_INT_MAX / 2;
        $transferWait = $transferWait ?? PHP_INT_MAX / 2;

        return $originWait + $transferWait;
    }

    private function getNextArrivalWait($stopId, $routeId) {
        if (!$stopId || !$routeId) {
            return null;
        }

        $arrivals = $this->transitService->getArrivalsAtStop($stopId, null, null, 12);
        foreach ($arrivals as $arrival) {
            if (!isset($arrival->routeId)) {
                continue;
            }
            if ($arrival->routeId == $routeId) {
                return isset($arrival->waitTime) ? (int)$arrival->waitTime : null;
            }
        }

        return null;
    }

    private function computeHopCount($type, $route) {
        if ($type === 'transfer') {
            $originSequence = $route['originSequence'] ?? null;
            $transferSequence = $route['transferSequence'] ?? null;
            $destinationSequence = $route['destinationSequence'] ?? null;

            if ($originSequence === null || $transferSequence === null || $destinationSequence === null) {
                return PHP_INT_MAX;
            }

            return max(0, ($transferSequence - $originSequence) + ($destinationSequence - $transferSequence));
        }

        $originSequence = $route['originSequence'] ?? null;
        $destinationSequence = $route['destinationSequence'] ?? null;

        if ($originSequence === null || $destinationSequence === null) {
            return PHP_INT_MAX;
        }

        return max(0, $destinationSequence - $originSequence);
    }

    private function compareSortKey($a, $b) {
        $length = min(count($a), count($b));
        for ($i = 0; $i < $length; $i++) {
            if ($a[$i] === $b[$i]) {
                continue;
            }
            return ($a[$i] < $b[$i]) ? -1 : 1;
        }
        return count($a) <=> count($b);
    }

    private function safeDistance($stop) {
        if (!$stop || !isset($stop->distance)) {
            return PHP_INT_MAX;
        }
        return (float)$stop->distance;
    }

    private function mapStopsById($stops) {
        $map = [];
        foreach ($stops as $stop) {
            if (!isset($stop->id)) {
                continue;
            }
            $map[$stop->id] = $stop;
        }
        return $map;
    }

    private function loadStopsByIds($stopIds) {
        if (empty($stopIds)) {
            return [];
        }

        $params = [];
        $types = '';
        $placeholders = $this->buildInClause($stopIds, 's', $types, $params);

        $sql = "SELECT stop_id, stop_name, stop_desc, stop_lat, stop_lon
                FROM sp_stop
                WHERE stop_id IN ($placeholders)";

        $this->con->ExecutaPrepared($sql, $types, $params);

        $stops = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;
            $obj = new stdClass();
            $obj->id = $rs['stop_id'];
            $obj->name = $rs['stop_name'] ?? '';
            $obj->desc = $rs['stop_desc'] ?? '';
            $obj->lat = $rs['stop_lat'];
            $obj->lon = $rs['stop_lon'];
            $stops[$obj->id] = $obj;
        }

        return $stops;
    }

    private function buildInClause($values, $type, &$types, &$params) {
        $placeholders = implode(',', array_fill(0, count($values), '?'));
        $types .= str_repeat($type, count($values));
        foreach ($values as $value) {
            $params[] = $value;
        }
        return $placeholders;
    }

    private function clampInt($value, $min, $max, $fallback) {
        if (!is_numeric($value)) {
            return $fallback;
        }
        $value = (int)$value;
        if ($value < $min) {
            return $min;
        }
        if ($value > $max) {
            return $max;
        }
        return $value;
    }

    private function normalizePriority($value) {
        $value = strtolower(trim((string)$value));
        $allowed = ['arrives_first', 'shortest', 'fewest_transfers', 'closest_origin', 'closest_destination'];
        return in_array($value, $allowed, true) ? $value : 'arrives_first';
    }
}
