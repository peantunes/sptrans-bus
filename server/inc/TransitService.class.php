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
    public $serviceDate;
    public $scheduledTimestamp;
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
     * Convert GTFS date (YYYYMMDD) to ISO date (YYYY-MM-DD) in service timezone.
     */
    private function gtfsDateToIso($gtfsDate) {
        $raw = trim((string)$gtfsDate);
        if (!preg_match('/^\d{8}$/', $raw)) {
            return null;
        }

        $dateTime = DateTimeImmutable::createFromFormat('Ymd', $raw, $this->serviceTimezone);
        if (!$dateTime || $dateTime->format('Ymd') !== $raw) {
            return null;
        }

        return $dateTime->format('Y-m-d');
    }

    /**
     * Convert service date + GTFS time (hours may exceed 24) into unix timestamp.
     */
    private function gtfsDateTimeToTimestamp($serviceDateIso, $gtfsTime) {
        $serviceDate = trim((string)$serviceDateIso);
        if ($serviceDate === '') {
            return null;
        }

        $serviceMidnight = DateTimeImmutable::createFromFormat('Y-m-d H:i:s', $serviceDate . ' 00:00:00', $this->serviceTimezone);
        if (!$serviceMidnight || $serviceMidnight->format('Y-m-d') !== $serviceDate) {
            return null;
        }

        $seconds = $this->timeToSeconds($gtfsTime);
        if ($seconds === null) {
            return null;
        }

        return $serviceMidnight->getTimestamp() + $seconds;
    }

    /**
     * Check if calendar_dates exceptions table is available.
     * Uses lazy caching to avoid checking schema on every query.
     */
    private function supportsCalendarDateExceptions() {
        if ($this->hasCalendarDatesTable !== null) {
            return $this->hasCalendarDatesTable;
        }

        $this->con->Executa("
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
            AND table_name = 'sp_calendar_dates'
            LIMIT 1
        ");
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
    public function getArrivalsAtStop($stopId, $time = null, $date = null, $limit = 20, $direction = 'next', $cursorTime = null, $cursorDate = null) {
        $limit = (int)$limit;
        if ($limit <= 0) {
            return [];
        }

        $direction = strtolower(trim((string)$direction));
        if ($direction !== 'previous' && $direction !== 'next') {
            $direction = 'next';
        }

        $referenceTimestamp = $date ? $this->parseServiceDateTimestamp($date) : null;
        if ($date !== null && $referenceTimestamp === null) {
            return [];
        }
        if ($referenceTimestamp === null) {
            $referenceTimestamp = $this->getServiceDateTime()->getTimestamp();
        }

        $referenceTime = $time ?? $this->getCurrentTimeInServiceTimezone();
        $referenceSeconds = $this->timeToSeconds($referenceTime);
        if ($referenceSeconds === null) {
            return [];
        }

        $referenceDateIso = $this->getServiceDateTime($referenceTimestamp)->format('Y-m-d');
        $referenceEpoch = $this->gtfsDateTimeToTimestamp($referenceDateIso, $referenceTime);
        if ($referenceEpoch === null) {
            $referenceEpoch = $this->getServiceDateTime()->getTimestamp();
        }

        $cursorTimestamp = $cursorDate ? $this->parseServiceDateTimestamp($cursorDate) : $referenceTimestamp;
        if ($cursorDate !== null && $cursorTimestamp === null) {
            return [];
        }
        if ($cursorTimestamp === null) {
            $cursorTimestamp = $referenceTimestamp;
        }

        $cursorLookupTime = $cursorTime ?? $referenceTime;
        $cursorLookupSeconds = $this->timeToSeconds($cursorLookupTime);
        if ($cursorLookupSeconds === null) {
            return [];
        }

        $cursorDateGtfs = $this->getCurrentDateGtfs($cursorTimestamp);
        $cursorDayColumn = $this->getDayOfWeekColumn($cursorTimestamp);
        $arrivals = $this->fetchFrequencyArrivalsAtStop(
            $stopId,
            $cursorLookupTime,
            $cursorDateGtfs,
            $cursorDayColumn,
            $limit,
            $direction,
            $referenceEpoch
        );

        // Early morning needs previous service day with GTFS times >= 24:00:00.
        // Only apply in default "next" mode (without an explicit cursor).
        $overnightCutoffSeconds = 6 * 3600;
        if (
            $direction === 'next'
            && $cursorTime === null
            && $cursorDate === null
            && $cursorLookupSeconds < $overnightCutoffSeconds
        ) {
            $previousTimestamp = $this->getServiceDateTime($cursorTimestamp)->modify('-1 day')->getTimestamp();
            $previousDate = $this->getCurrentDateGtfs($previousTimestamp);
            $previousDayColumn = $this->getDayOfWeekColumn($previousTimestamp);
            $overnightTime = $this->secondsToGtfsTime($cursorLookupSeconds + 86400);

            $arrivals = array_merge(
                $arrivals,
                $this->fetchFrequencyArrivalsAtStop(
                    $stopId,
                    $overnightTime,
                    $previousDate,
                    $previousDayColumn,
                    $limit,
                    $direction,
                    $referenceEpoch
                )
            );
        }

        // Remove duplicates after combining service-day queries.
        $uniqueArrivals = [];
        foreach ($arrivals as $arrival) {
            $key = $arrival->tripId . '|' . $arrival->arrivalTime . '|' . $arrival->stopSequence . '|' . ($arrival->serviceDate ?? '');
            $uniqueArrivals[$key] = $arrival;
        }
        $arrivals = array_values($uniqueArrivals);

        usort($arrivals, function($a, $b) {
            $aTs = isset($a->scheduledTimestamp) ? (int)$a->scheduledTimestamp : PHP_INT_MAX;
            $bTs = isset($b->scheduledTimestamp) ? (int)$b->scheduledTimestamp : PHP_INT_MAX;
            if ($aTs !== $bTs) {
                return $aTs <=> $bTs;
            }

            return strcmp((string)$a->routeShortName, (string)$b->routeShortName);
        });

        if (count($arrivals) > $limit) {
            if ($direction === 'previous') {
                $arrivals = array_slice($arrivals, -$limit);
            } else {
                $arrivals = array_slice($arrivals, 0, $limit);
            }
        }

        return $arrivals;
    }

    /**
     * Internal frequency-based arrivals query for a specific service day.
     */
    private function fetchFrequencyArrivalsAtStop($stopId, $cursorTime, $cursorDateGtfs, $dayColumn, $limit, $direction, $referenceEpoch) {
        $allowedDays = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        if (!in_array($dayColumn, $allowedDays, true)) {
            return [];
        }

        $cursorSeconds = $this->timeToSeconds($cursorTime);
        if ($cursorSeconds === null) {
            return [];
        }

        $supportsCalendarDates = $this->supportsCalendarDateExceptions();

        $calendarJoinSql = "LEFT JOIN sp_calendar c ON c.service_id = t.service_id";
        $serviceCalendarConditionSql = "c.$dayColumn = 1
            AND c.start_date <= ?
            AND c.end_date >= ?";
        $types = "sss";
        $params = [
            $stopId,
            $cursorDateGtfs,
            $cursorDateGtfs
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

            $types = "ssss";
            $params = [
                $cursorDateGtfs,
                $stopId,
                $cursorDateGtfs,
                $cursorDateGtfs,
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
                stop_offset.offset_secs,
                TIME_TO_SEC(f.start_time) AS frequency_start_secs,
                TIME_TO_SEC(f.end_time) AS frequency_end_secs,
                f.headway_secs,
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
            AND f.headway_secs > 0
            AND $serviceCalendarConditionSql
            ORDER BY r.route_short_name, st.trip_id, f.start_time";

        $this->con->ExecutaPrepared($sql, $types, $params);

        $arrivals = [];
        $serviceDateIso = $this->gtfsDateToIso($cursorDateGtfs);
        if ($serviceDateIso === null) {
            $serviceDateIso = $this->getServiceDateTime()->format('Y-m-d');
        }

        $maxPerTemplate = max($limit, 20);
        while ($this->con->Linha()) {
            $rs = $this->con->rs;

            $offsetSeconds = isset($rs['offset_secs']) ? (int)$rs['offset_secs'] : 0;
            $frequencyStartSeconds = isset($rs['frequency_start_secs']) ? (int)$rs['frequency_start_secs'] : null;
            $frequencyEndSeconds = isset($rs['frequency_end_secs']) ? (int)$rs['frequency_end_secs'] : null;
            $headwaySeconds = isset($rs['headway_secs']) ? (int)$rs['headway_secs'] : 0;
            if ($frequencyStartSeconds === null || $frequencyEndSeconds === null || $headwaySeconds <= 0) {
                continue;
            }

            $firstArrivalSeconds = $frequencyStartSeconds + $offsetSeconds;
            $lastArrivalSeconds = $frequencyEndSeconds + $offsetSeconds;
            if ($lastArrivalSeconds < $firstArrivalSeconds) {
                continue;
            }

            $occurrenceSeconds = null;
            if ($direction === 'previous') {
                if ($cursorSeconds < $firstArrivalSeconds) {
                    continue;
                }

                $steps = (int)floor(($cursorSeconds - $firstArrivalSeconds) / $headwaySeconds);
                $occurrenceSeconds = $firstArrivalSeconds + ($steps * $headwaySeconds);
                if ($occurrenceSeconds > $lastArrivalSeconds) {
                    $overshoot = $occurrenceSeconds - $lastArrivalSeconds;
                    $rollbackSteps = (int)ceil($overshoot / $headwaySeconds);
                    $occurrenceSeconds -= $rollbackSteps * $headwaySeconds;
                }
            } else {
                if ($cursorSeconds <= $firstArrivalSeconds) {
                    $occurrenceSeconds = $firstArrivalSeconds;
                } else {
                    $steps = (int)ceil(($cursorSeconds - $firstArrivalSeconds) / $headwaySeconds);
                    $occurrenceSeconds = $firstArrivalSeconds + ($steps * $headwaySeconds);
                }
            }

            if ($occurrenceSeconds === null) {
                continue;
            }

            $generatedCount = 0;
            while (
                $occurrenceSeconds >= $firstArrivalSeconds
                && $occurrenceSeconds <= $lastArrivalSeconds
                && $generatedCount < $maxPerTemplate
            ) {
                $arrivalTime = $this->secondsToGtfsTime($occurrenceSeconds);
                $arrival = new Arrival();
                $arrival->tripId = $rs['trip_id'];
                $arrival->routeId = $rs['route_id'];
                $arrival->routeShortName = $this->safeEncode($rs['route_short_name']);
                $arrival->routeLongName = $this->safeEncode($rs['route_long_name']);
                $arrival->headsign = $this->safeEncode($rs['trip_headsign']);
                $arrival->arrivalTime = $arrivalTime;
                $arrival->departureTime = $arrivalTime;
                $arrival->stopSequence = (int)$rs['stop_sequence'];
                $arrival->routeType = (int)$rs['route_type'];
                $arrival->routeColor = $rs['route_color'];
                $arrival->routeTextColor = $rs['route_text_color'];
                $arrival->frequency = $rs['frequency_minutes'] ? (int)$rs['frequency_minutes'] : null;
                $arrival->serviceDate = $serviceDateIso;
                $arrival->scheduledTimestamp = $this->gtfsDateTimeToTimestamp($serviceDateIso, $arrivalTime);
                if ($arrival->scheduledTimestamp !== null) {
                    $arrival->waitTime = max(0, (int)ceil((((int)$arrival->scheduledTimestamp) - ((int)$referenceEpoch)) / 60));
                } else {
                    $arrival->waitTime = 0;
                }

                $arrivals[] = $arrival;
                $generatedCount++;
                if ($direction === 'previous') {
                    $occurrenceSeconds -= $headwaySeconds;
                } else {
                    $occurrenceSeconds += $headwaySeconds;
                }
            }
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
