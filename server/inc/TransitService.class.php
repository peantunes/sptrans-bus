<?php
/**
 * Transit Service Class
 *
 * Provides services for GTFS transit data including:
 * - Bus arrivals at stops (with calendar consideration)
 * - Trip route information
 * - Stop search
 * - Route shapes
 * - Fare information
 */

class Arrival {
    public $tripId;
    public $routeId;
    public $routeShortName;
    public $routeLongName;
    public $headsign;
    public $arrivalTime;
    public $departureTime;
    public $stopSequence;
    public $routeType;
    public $routeColor;
    public $routeTextColor;
    public $frequency;
    public $waitTime;
}

class TripStop {
    public $stopId;
    public $stopName;
    public $stopDesc;
    public $stopLat;
    public $stopLon;
    public $arrivalTime;
    public $departureTime;
    public $stopSequence;
}

class RouteInfo {
    public $routeId;
    public $agencyId;
    public $routeShortName;
    public $routeLongName;
    public $routeType;
    public $routeColor;
    public $routeTextColor;
    public $trips;
}

class TripInfo {
    public $tripId;
    public $routeId;
    public $serviceId;
    public $headsign;
    public $directionId;
    public $shapeId;
    public $stops;
}

class StopInfo {
    public $stopId;
    public $stopName;
    public $stopDesc;
    public $stopLat;
    public $stopLon;
    public $routes;
}

class ShapePoint {
    public $lat;
    public $lon;
    public $sequence;
    public $distTraveled;
}

class FareInfo {
    public $fareId;
    public $price;
    public $currencyType;
    public $paymentMethod;
    public $transfers;
    public $transferDuration;
}

class TransitService {

    private $con;

    public function __construct($con) {
        $this->con = $con;
    }

    /**
     * Get the current day of week column name for calendar
     */
    private function getDayOfWeekColumn($timestamp = null) {
        $days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        $dayIndex = (int)date('w', $timestamp ?? time());
        return $days[$dayIndex];
    }

    /**
     * Get current date in GTFS format (YYYYMMDD)
     */
    private function getCurrentDateGtfs($timestamp = null) {
        return date('Ymd', $timestamp ?? time());
    }

    /**
     * Return value safely (no encoding conversion needed - data is already UTF-8)
     */
    private function safeEncode($value) {
        if ($value === null) return '';
        return $value;
    }

    /**
     * 1. Get bus arrivals at a stop
     *
     * Returns buses arriving at the specified stop, considering:
     * - Current time (or specified time)
     * - Calendar (service running on current day)
     * - Frequency information
     *
     * @param string $stopId The stop ID
     * @param string|null $time Optional time in HH:MM:SS format (defaults to current time)
     * @param string|null $date Optional date in YYYY-MM-DD format (defaults to today)
     * @param int $limit Maximum number of results (default 20)
     * @return array List of Arrival objects
     */
    public function getArrivalsAtStop($stopId, $time = null, $date = null, $limit = 20) {
        // Parse date and time
        $timestamp = $date ? strtotime($date) : time();
        $currentTime = $time ?? date('H:i:s');
        $currentDate = $this->getCurrentDateGtfs($timestamp);
        $dayColumn = $this->getDayOfWeekColumn($timestamp);
        $limit = (int)$limit;

        // Note: Day column cannot be parameterized as it's a column name
        // We validate it's one of the allowed values
        $allowedDays = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        if (!in_array($dayColumn, $allowedDays)) {
            return [];
        }

        $sql = "SELECT
                    st.trip_id,
                    st.arrival_time,
                    st.departure_time,
                    st.stop_sequence,
                    t.route_id,
                    t.trip_headsign,
                    t.service_id,
                    r.route_short_name,
                    r.route_long_name,
                    r.route_type,
                    r.route_color,
                    r.route_text_color,
                    (SELECT ROUND(f.headway_secs/60)
                     FROM sp_frequencies f
                     WHERE f.trip_id = st.trip_id
                       AND f.start_time <= ?
                       AND f.end_time >= ?
                     LIMIT 1) as frequency
                FROM sp_stop_times st
                INNER JOIN sp_trip t ON st.trip_id = t.trip_id
                INNER JOIN sp_routes r ON t.route_id = r.route_id
                INNER JOIN sp_calendar c ON t.service_id = c.service_id
                WHERE st.stop_id = ?
                  AND st.arrival_time >= ?
                  AND c.$dayColumn = 1
                  AND c.start_date <= ?
                  AND c.end_date >= ?
                ORDER BY st.arrival_time
                LIMIT ?";

        $this->con->ExecutaPrepared($sql, "ssssssi", [
            $currentTime,
            $currentTime,
            $stopId,
            $currentTime,
            $currentDate,
            $currentDate,
            $limit
        ]);

        $arrivals = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $arrival = new Arrival();
            $arrival->tripId = $rs['trip_id'];
            $arrival->routeId = $rs['route_id'];
            $arrival->routeShortName = $this->safeEncode($rs['route_short_name']);
            $arrival->routeLongName = $this->safeEncode($rs['route_long_name']);
            $arrival->headsign = $this->safeEncode($rs['trip_headsign']);
            $arrival->arrivalTime = $rs['arrival_time'];
            $arrival->departureTime = $rs['departure_time'];
            $arrival->stopSequence = (int)$rs['stop_sequence'];
            $arrival->routeType = (int)$rs['route_type'];
            $arrival->routeColor = $rs['route_color'];
            $arrival->routeTextColor = $rs['route_text_color'];
            $arrival->frequency = $rs['frequency'] ? (int)$rs['frequency'] : null;

            // Calculate wait time in minutes
            $arrivalTimestamp = strtotime($rs['arrival_time']);
            $currentTimestamp = strtotime($currentTime);
            $arrival->waitTime = round(($arrivalTimestamp - $currentTimestamp) / 60);

            $arrivals[] = $arrival;
        }

        return $arrivals;
    }

    /**
     * 2. Get trip route details
     *
     * Returns all stops for a given trip in sequence order
     *
     * @param string $tripId The trip ID
     * @return TripInfo|null Trip information with stops
     */
    public function getTripRoute($tripId) {
        // Get trip info
        $sql = "SELECT t.*, r.route_short_name, r.route_long_name, r.route_type, r.route_color, r.route_text_color
                FROM sp_trip t
                INNER JOIN sp_routes r ON t.route_id = r.route_id
                WHERE t.trip_id = ?";

        $this->con->ExecutaPrepared($sql, "s", [$tripId]);

        if (!$this->con->Linha()) {
            return null;
        }

        $rs = $this->con->rs;

        $trip = new TripInfo();
        $trip->tripId = $rs['trip_id'];
        $trip->routeId = $rs['route_id'];
        $trip->serviceId = $rs['service_id'];
        $trip->headsign = $this->safeEncode($rs['trip_headsign']);
        $trip->directionId = isset($rs['direction_id']) ? (int)$rs['direction_id'] : null;
        $trip->shapeId = $rs['shape_id'] ?? null;

        // Get all stops for this trip
        $sql = "SELECT
                    st.stop_id,
                    st.arrival_time,
                    st.departure_time,
                    st.stop_sequence,
                    s.stop_name,
                    s.stop_desc,
                    s.stop_lat,
                    s.stop_lon
                FROM sp_stop_times st
                INNER JOIN sp_stop s ON st.stop_id = s.stop_id
                WHERE st.trip_id = ?
                ORDER BY st.stop_sequence";

        $this->con->ExecutaPrepared($sql, "s", [$tripId]);

        $stops = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $stop = new TripStop();
            $stop->stopId = $rs['stop_id'];
            $stop->stopName = $this->safeEncode($rs['stop_name']);
            $stop->stopDesc = $this->safeEncode($rs['stop_desc']);
            $stop->stopLat = (float)$rs['stop_lat'];
            $stop->stopLon = (float)$rs['stop_lon'];
            $stop->arrivalTime = $rs['arrival_time'];
            $stop->departureTime = $rs['departure_time'];
            $stop->stopSequence = (int)$rs['stop_sequence'];

            $stops[] = $stop;
        }

        $trip->stops = $stops;

        return $trip;
    }

    /**
     * 3. Get route information
     *
     * Returns route details and associated trips
     *
     * @param string $routeId The route ID
     * @return RouteInfo|null Route information
     */
    public function getRouteInfo($routeId) {
        $sql = "SELECT * FROM sp_routes WHERE route_id = ?";

        $this->con->ExecutaPrepared($sql, "s", [$routeId]);

        if (!$this->con->Linha()) {
            return null;
        }

        $rs = $this->con->rs;

        $route = new RouteInfo();
        $route->routeId = $rs['route_id'];
        $route->agencyId = $rs['agency_id'] ?? null;
        $route->routeShortName = $this->safeEncode($rs['route_short_name']);
        $route->routeLongName = $this->safeEncode($rs['route_long_name']);
        $route->routeType = (int)$rs['route_type'];
        $route->routeColor = $rs['route_color'];
        $route->routeTextColor = $rs['route_text_color'];

        // Get trips for this route
        $sql = "SELECT trip_id, service_id, trip_headsign, direction_id, shape_id
                FROM sp_trip
                WHERE route_id = ?";

        $this->con->ExecutaPrepared($sql, "s", [$routeId]);

        $trips = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;
            $trips[] = [
                'tripId' => $rs['trip_id'],
                'serviceId' => $rs['service_id'],
                'headsign' => $this->safeEncode($rs['trip_headsign']),
                'directionId' => isset($rs['direction_id']) ? (int)$rs['direction_id'] : null,
                'shapeId' => $rs['shape_id'] ?? null
            ];
        }

        $route->trips = $trips;

        return $route;
    }

    /**
     * 4. Search stops by name
     *
     * @param string $query Search query
     * @param int $limit Maximum results
     * @return array List of StopInfo objects
     */
    public function searchStops($query, $limit = 20) {
        $limit = (int)$limit;
        $searchQuery = '%' . $query . '%';

        $sql = "SELECT s.*,
                    (SELECT GROUP_CONCAT(DISTINCT t.route_id SEPARATOR ', ')
                     FROM sp_stop_times st
                     INNER JOIN sp_trip t ON st.trip_id = t.trip_id
                     WHERE st.stop_id = s.stop_id) as routes
                FROM sp_stop s
                WHERE s.stop_name LIKE ?
                ORDER BY s.stop_name
                LIMIT ?";

        $this->con->ExecutaPrepared($sql, "si", [$searchQuery, $limit]);

        $stops = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $stop = new StopInfo();
            $stop->stopId = $rs['stop_id'];
            $stop->stopName = $this->safeEncode($rs['stop_name']);
            $stop->stopDesc = $this->safeEncode($rs['stop_desc']);
            $stop->stopLat = (float)$rs['stop_lat'];
            $stop->stopLon = (float)$rs['stop_lon'];
            $stop->routes = $rs['routes'];

            $stops[] = $stop;
        }

        return $stops;
    }

    /**
     * 5. Get stop details by ID
     *
     * @param string $stopId The stop ID
     * @return StopInfo|null Stop information
     */
    public function getStopInfo($stopId) {
        $sql = "SELECT s.*,
                    (SELECT GROUP_CONCAT(DISTINCT t.route_id SEPARATOR ', ')
                     FROM sp_stop_times st
                     INNER JOIN sp_trip t ON st.trip_id = t.trip_id
                     WHERE st.stop_id = s.stop_id) as routes
                FROM sp_stop s
                WHERE s.stop_id = ?";

        $this->con->ExecutaPrepared($sql, "s", [$stopId]);

        if (!$this->con->Linha()) {
            return null;
        }

        $rs = $this->con->rs;

        $stop = new StopInfo();
        $stop->stopId = $rs['stop_id'];
        $stop->stopName = $this->safeEncode($rs['stop_name']);
        $stop->stopDesc = $this->safeEncode($rs['stop_desc']);
        $stop->stopLat = (float)$rs['stop_lat'];
        $stop->stopLon = (float)$rs['stop_lon'];
        $stop->routes = $rs['routes'];

        return $stop;
    }

    /**
     * 6. Get shape points for a trip (for drawing on map)
     *
     * @param string $shapeId The shape ID
     * @return array List of ShapePoint objects
     */
    public function getShape($shapeId) {
        $sql = "SELECT shape_pt_lat, shape_pt_lon, shape_pt_sequence, shape_dist_traveled
                FROM sp_shapes
                WHERE shape_id = ?
                ORDER BY shape_pt_sequence";

        $this->con->ExecutaPrepared($sql, "s", [$shapeId]);

        $points = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $point = new ShapePoint();
            $point->lat = (float)$rs['shape_pt_lat'];
            $point->lon = (float)$rs['shape_pt_lon'];
            $point->sequence = (int)$rs['shape_pt_sequence'];
            $point->distTraveled = isset($rs['shape_dist_traveled']) ? (float)$rs['shape_dist_traveled'] : null;

            $points[] = $point;
        }

        return $points;
    }

    /**
     * 7. Get fare information for a route
     *
     * @param string $routeId The route ID
     * @return FareInfo|null Fare information
     */
    public function getFare($routeId) {
        $sql = "SELECT fa.*
                FROM sp_fare_rules fr
                INNER JOIN sp_fare_att fa ON fr.fare_id = fa.fare_id
                WHERE fr.route_id = ?
                LIMIT 1";

        $this->con->ExecutaPrepared($sql, "s", [$routeId]);

        if (!$this->con->Linha()) {
            return null;
        }

        $rs = $this->con->rs;

        $fare = new FareInfo();
        $fare->fareId = $rs['fare_id'];
        $fare->price = (float)$rs['price'];
        $fare->currencyType = $rs['currency_type'];
        $fare->paymentMethod = (int)$rs['payment_method'];
        $fare->transfers = $rs['transfers'];
        $fare->transferDuration = isset($rs['transfer_duration']) ? (int)$rs['transfer_duration'] : null;

        return $fare;
    }

    /**
     * 8. Get routes passing through a stop
     *
     * @param string $stopId The stop ID
     * @return array List of route information
     */
    public function getRoutesAtStop($stopId) {
        $sql = "SELECT DISTINCT r.*
                FROM sp_stop_times st
                INNER JOIN sp_trip t ON st.trip_id = t.trip_id
                INNER JOIN sp_routes r ON t.route_id = r.route_id
                WHERE st.stop_id = ?
                ORDER BY r.route_short_name";

        $this->con->ExecutaPrepared($sql, "s", [$stopId]);

        $routes = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $routes[] = [
                'routeId' => $rs['route_id'],
                'routeShortName' => $this->safeEncode($rs['route_short_name']),
                'routeLongName' => $this->safeEncode($rs['route_long_name']),
                'routeType' => (int)$rs['route_type'],
                'routeColor' => $rs['route_color'],
                'routeTextColor' => $rs['route_text_color']
            ];
        }

        return $routes;
    }

    /**
     * 9. Get all routes
     *
     * @param int $limit Maximum results
     * @param int $offset Offset for pagination
     * @return array List of routes
     */
    public function getAllRoutes($limit = 100, $offset = 0) {
        $limit = (int)$limit;
        $offset = (int)$offset;

        $sql = "SELECT * FROM sp_routes ORDER BY route_short_name LIMIT ?, ?";

        $this->con->ExecutaPrepared($sql, "ii", [$offset, $limit]);

        $routes = [];
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $routes[] = [
                'routeId' => $rs['route_id'],
                'routeShortName' => $this->safeEncode($rs['route_short_name']),
                'routeLongName' => $this->safeEncode($rs['route_long_name']),
                'routeType' => (int)$rs['route_type'],
                'routeColor' => $rs['route_color'],
                'routeTextColor' => $rs['route_text_color']
            ];
        }

        return $routes;
    }

    /**
     * 10. Get service calendar information
     *
     * @param string $serviceId The service ID
     * @return array|null Calendar information
     */
    public function getServiceCalendar($serviceId) {
        $sql = "SELECT * FROM sp_calendar WHERE service_id = ?";

        $this->con->ExecutaPrepared($sql, "s", [$serviceId]);

        if (!$this->con->Linha()) {
            return null;
        }

        $rs = $this->con->rs;

        return [
            'serviceId' => $rs['service_id'],
            'monday' => (bool)$rs['monday'],
            'tuesday' => (bool)$rs['tuesday'],
            'wednesday' => (bool)$rs['wednesday'],
            'thursday' => (bool)$rs['thursday'],
            'friday' => (bool)$rs['friday'],
            'saturday' => (bool)$rs['saturday'],
            'sunday' => (bool)$rs['sunday'],
            'startDate' => $rs['start_date'],
            'endDate' => $rs['end_date']
        ];
    }
}
