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
    private $hasCalendarDatesTable = null;
    private $serviceTimezone;

    public function __construct($con) {
        $this->con = $con;
        $this->serviceTimezone = new DateTimeZone('America/Sao_Paulo');
    }

    /**
     * Build DateTimeImmutable in service timezone.
     */
    private function getServiceDateTime($timestamp = null) {
        if ($timestamp === null) {
            return new DateTimeImmutable('now', $this->serviceTimezone);
        }

        return (new DateTimeImmutable('@' . (int)$timestamp))
            ->setTimezone($this->serviceTimezone);
    }

    /**
     * Parse YYYY-MM-DD in service timezone and return timestamp at 00:00:00.
     */
    private function parseServiceDateTimestamp($date) {
        if ($date === null) {
            return null;
        }

        $dateValue = trim((string)$date);
        if ($dateValue === '') {
            return null;
        }

        $dateTime = DateTimeImmutable::createFromFormat('Y-m-d', $dateValue, $this->serviceTimezone);
        if (!$dateTime || $dateTime->format('Y-m-d') !== $dateValue) {
            return null;
        }

        return $dateTime->setTime(0, 0, 0)->getTimestamp();
    }

    /**
     * Return current time string in service timezone.
     */
    private function getCurrentTimeInServiceTimezone() {
        return $this->getServiceDateTime()->format('H:i:s');
    }

    /**
     * Convert seconds to GTFS time format HH:MM:SS (hours may exceed 24).
     */
    private function secondsToGtfsTime($seconds) {
        $seconds = max(0, (int)$seconds);
        $hours = (int)floor($seconds / 3600);
        $minutes = (int)floor(($seconds % 3600) / 60);
        $remainingSeconds = $seconds % 60;

        return sprintf('%02d:%02d:%02d', $hours, $minutes, $remainingSeconds);
    }

    /**
     * Get the current day of week column name for calendar
     */
    private function getDayOfWeekColumn($timestamp = null) {
        $days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        $dayIndex = (int)$this->getServiceDateTime($timestamp)->format('w');
        return $days[$dayIndex];
    }

    /**
     * Get current date in GTFS format (YYYYMMDD)
     */
    private function getCurrentDateGtfs($timestamp = null) {
        return $this->getServiceDateTime($timestamp)->format('Ymd');
    }

    /**
     * Return value safely (no encoding conversion needed - data is already UTF-8)
     */
    private function safeEncode($value) {
        if ($value === null) return '';
        return $value;
    }

    /**
     * Parse GTFS/SQL time string to total seconds.
     * Supports values with fractional seconds and hours >= 24.
     */
    private function timeToSeconds($timeValue) {
        if ($timeValue === null) {
            return null;
        }

        $raw = trim((string)$timeValue);
        if ($raw === '') {
            return null;
        }

        // Drop fractional part, e.g. 08:37:04.000000 -> 08:37:04
        $raw = preg_replace('/\..*$/', '', $raw);
        $parts = explode(':', $raw);

        if (count($parts) < 2) {
            return null;
        }

        $hour = (int)$parts[0];
        $minute = (int)$parts[1];
        $second = isset($parts[2]) ? (int)$parts[2] : 0;

        return ($hour * 3600) + ($minute * 60) + $second;
    }

    /**
     * Check if calendar_dates exceptions table is available.
     * Uses lazy caching to avoid checking schema on every query.
     */
    private function supportsCalendarDateExceptions() {
        if ($this->hasCalendarDatesTable !== null) {
            return $this->hasCalendarDatesTable;
        }

        $this->con->ExecutaPrepared("SHOW TABLES LIKE ?", "s", ["sp_calendar_dates"]);
        $this->hasCalendarDatesTable = $this->con->Linha() ? true : false;

        return $this->hasCalendarDatesTable;
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
        $limit = (int)$limit;
        if ($limit <= 0) {
            return [];
        }

        $timestamp = $date ? $this->parseServiceDateTimestamp($date) : null;
        if ($date !== null && $timestamp === null) {
            return [];
        }
        if ($timestamp === null) {
            $timestamp = $this->getServiceDateTime()->getTimestamp();
        }

        $currentTime = $time ?? $this->getCurrentTimeInServiceTimezone();
        $currentSeconds = $this->timeToSeconds($currentTime);
        if ($currentSeconds === null) {
            return [];
        }

        $currentDate = $this->getCurrentDateGtfs($timestamp);
        $dayColumn = $this->getDayOfWeekColumn($timestamp);
        $arrivals = $this->fetchFrequencyArrivalsAtStop($stopId, $currentTime, $currentDate, $dayColumn, $limit);

        // Early morning needs previous service day with GTFS times >= 24:00:00.
        $overnightCutoffSeconds = 6 * 3600;
        if ($currentSeconds < $overnightCutoffSeconds) {
            $previousTimestamp = $this->getServiceDateTime($timestamp)->modify('-1 day')->getTimestamp();
            $previousDate = $this->getCurrentDateGtfs($previousTimestamp);
            $previousDayColumn = $this->getDayOfWeekColumn($previousTimestamp);
            $overnightTime = $this->secondsToGtfsTime($currentSeconds + 86400);

            $arrivals = array_merge(
                $arrivals,
                $this->fetchFrequencyArrivalsAtStop($stopId, $overnightTime, $previousDate, $previousDayColumn, $limit)
            );
        }

        // Remove duplicates after combining today's and previous service-day queries.
        $uniqueArrivals = [];
        foreach ($arrivals as $arrival) {
            $key = $arrival->tripId . '|' . $arrival->arrivalTime . '|' . $arrival->stopSequence;
            $uniqueArrivals[$key] = $arrival;
        }
        $arrivals = array_values($uniqueArrivals);

        usort($arrivals, function($a, $b) {
            $waitDiff = ((int)$a->waitTime) <=> ((int)$b->waitTime);
            if ($waitDiff !== 0) {
                return $waitDiff;
            }

            $aArrival = $this->timeToSeconds($a->arrivalTime) ?? PHP_INT_MAX;
            $bArrival = $this->timeToSeconds($b->arrivalTime) ?? PHP_INT_MAX;
            if ($aArrival !== $bArrival) {
                return $aArrival <=> $bArrival;
            }

            return strcmp((string)$a->routeShortName, (string)$b->routeShortName);
        });

        if (count($arrivals) > $limit) {
            $arrivals = array_slice($arrivals, 0, $limit);
        }

        return $arrivals;
    }

    /**
     * Internal frequency-based arrivals query for a specific service day.
     */
    private function fetchFrequencyArrivalsAtStop($stopId, $currentTime, $currentDate, $dayColumn, $limit) {
        $allowedDays = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        if (!in_array($dayColumn, $allowedDays, true)) {
            return [];
        }

        $supportsCalendarDates = $this->supportsCalendarDateExceptions();

        $calendarJoinSql = "LEFT JOIN sp_calendar c ON c.service_id = t.service_id";
        $serviceCalendarConditionSql = "c.$dayColumn = 1
            AND c.start_date <= ?
            AND c.end_date >= ?";
        $types = "sssssssi";
        $params = [
            $currentTime,
            $stopId,
            $currentTime,
            $currentTime,
            $currentDate,
            $currentDate,
            $currentTime,
            $limit
        ];

        if ($supportsCalendarDates) {
            $calendarJoinSql .= "
            LEFT JOIN sp_calendar_dates cd
            ON cd.service_id = t.service_id
            AND cd.`date` = ?";

            $serviceCalendarConditionSql = "(
                    cd.exception_type = 1
                    OR (
                        cd.exception_type IS NULL
                        AND c.$dayColumn = 1
                        AND c.start_date <= ?
                        AND c.end_date >= ?
                    )
                )
                AND (cd.exception_type IS NULL OR cd.exception_type <> 2)";

            $types = "ssssssssi";
            $params = [
                $currentTime,
                $stopId,
                $currentTime,
                $currentTime,
                $currentDate,
                $currentDate,
                $currentDate,
                $currentTime,
                $limit
            ];
        }

        $sql = "SELECT
                st.trip_id,
                t.route_id,
                t.trip_headsign,
                r.route_short_name,
                r.route_long_name,
                r.route_type,
                r.route_color,
                r.route_text_color,
                stop_offset.stop_sequence as stop_sequence,
                -- next arrival time (computed)
                SEC_TO_TIME(
                    TIME_TO_SEC(f.start_time)
                    + (
                        CEIL(
                            GREATEST(
                                0,
                                TIME_TO_SEC(?) - TIME_TO_SEC(f.start_time) - stop_offset.offset_secs
                            ) / f.headway_secs
                        ) * f.headway_secs
                    )
                    + stop_offset.offset_secs
                ) AS arrival_time,

                ROUND(f.headway_secs / 60) AS frequency_minutes

            FROM sp_stop_times st

            JOIN (
                SELECT
                    trip_id,
                    stop_id,
                    stop_sequence,
                    TIME_TO_SEC(arrival_time)
                    - TIME_TO_SEC(MIN(arrival_time) OVER (PARTITION BY trip_id))
                    AS offset_secs
                FROM sp_stop_times
            ) stop_offset
            ON stop_offset.trip_id = st.trip_id
            AND stop_offset.stop_id = st.stop_id

            JOIN sp_frequencies f
            ON f.trip_id = st.trip_id

            JOIN sp_trip t ON t.trip_id = st.trip_id
            JOIN sp_routes r ON r.route_id = t.route_id
            $calendarJoinSql

            WHERE st.stop_id = ?
            AND f.start_time <= ?
            AND f.end_time >= ?
            AND $serviceCalendarConditionSql

            HAVING arrival_time >= ?

            ORDER BY arrival_time
            LIMIT ?";

        $this->con->ExecutaPrepared($sql, $types, $params);

        $arrivals = [];
        $currentSeconds = $this->timeToSeconds($currentTime);
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $arrival = new Arrival();
            $arrival->tripId = $rs['trip_id'];
            $arrival->routeId = $rs['route_id'];
            $arrival->routeShortName = $this->safeEncode($rs['route_short_name']);
            $arrival->routeLongName = $this->safeEncode($rs['route_long_name']);
            $arrival->headsign = $this->safeEncode($rs['trip_headsign']);
            $arrival->arrivalTime = $rs['arrival_time'];
            $arrival->departureTime = $rs['arrival_time'];
            $arrival->stopSequence = (int)$rs['stop_sequence'];
            $arrival->routeType = (int)$rs['route_type'];
            $arrival->routeColor = $rs['route_color'];
            $arrival->routeTextColor = $rs['route_text_color'];
            $arrival->frequency = $rs['frequency_minutes'] ? (int)$rs['frequency_minutes'] : null;

            $arrivalSeconds = $this->timeToSeconds($rs['arrival_time']);
            if ($arrivalSeconds !== null && $currentSeconds !== null) {
                $arrival->waitTime = max(0, (int)ceil(($arrivalSeconds - $currentSeconds) / 60));
            } else {
                $arrival->waitTime = 0;
            }

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
