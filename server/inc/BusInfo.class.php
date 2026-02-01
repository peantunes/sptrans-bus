<?php
class BusRoute {
    public $id;
    public $name;
    public $desc;
    public $time;
    public $type;
    public $color;
    public $freq;
    public $textColor;
}

class BusStop {
    public $id;
    public $name;
    public $desc;
    public $lat;
    public $lon;
    public $routes;
    public $distance;
}

class BusInfo{

    var $con;

    function __construct($con){
        $this->con = $con;
    }

    public function listBusByStopId($stopId){
        $time = date("H:i:s");

        $sql = "SELECT
                    b.*, c.trip_headsign, a.trip_id, a.arrival_time, a.stop_id, a.stop_sequence,
                    (SELECT ROUND(headway_secs/60) FROM sp_frequencies
                        WHERE trip_id = a.trip_id
                        AND start_time <= ?
                        AND end_time >= ?
                        LIMIT 1) freq
                FROM sp_stop_times a, sp_routes b, sp_trip c
                WHERE a.stop_id = ?
                    AND b.route_id = c.route_id
                    AND a.trip_id = c.trip_id
                ORDER BY a.arrival_time";

        $this->con->ExecutaPrepared($sql, "sss", [$time, $time, $stopId]);

        $list = array();
        while($this->con->Linha()){
            $rs = $this->con->rs;
            $obj = new BusRoute();
            $obj->id = $rs["route_id"];
            $obj->name = $rs["route_short_name"] ?? '';
            $obj->desc = $rs["trip_headsign"] ?? '';
            $obj->time = $rs["arrival_time"];
            $obj->type = $rs["route_type"];
            $obj->color = $rs["route_color"];
            $obj->freq = $rs["freq"];
            $obj->textColor = $rs["route_text_color"];
            array_push($list, $obj);

        }

        return $list;
    }

    public function listStopsByStopsAndGeo($stops, $lat = "", $lon = ""){
        // Split the comma-separated stops into an array
        $stopItems = array_map('trim', explode(",", $stops));

        // Build placeholders for IN clause
        $placeholders = str_repeat('?,', count($stopItems) - 1) . '?';
        $types = str_repeat('s', count($stopItems)) . 'dd';

        $sql = "SELECT ABS(ABS(a.stop_lat - ?) + ABS(a.stop_lon - ?)) as distance, a.*,
                    (SELECT GROUP_CONCAT(b1.route_id SEPARATOR ', ')
                     FROM sp_stop_times a1
                     INNER JOIN sp_trip b1 ON a1.trip_id = b1.trip_id
                     WHERE stop_id = a.stop_id
                     GROUP BY stop_id) routes
                FROM sp_stop a
                WHERE stop_id IN ($placeholders)";

        // Build params array: lat, lon, then all stop IDs
        $params = array_merge([(float)$lat, (float)$lon], $stopItems);
        $types = 'dd' . str_repeat('s', count($stopItems));

        $this->con->ExecutaPrepared($sql, $types, $params);

        return $this->loadStopsFromResult();
    }

    public function listStopsByGeo($lat, $lon){
        $sql = "SELECT ABS(ABS(a.stop_lat - ?) + ABS(a.stop_lon - ?)) as distance, a.*,
                    IFNULL((SELECT GROUP_CONCAT(b1.route_id SEPARATOR ', ')
                            FROM sp_stop_times a1
                            INNER JOIN sp_trip b1 ON a1.trip_id = b1.trip_id
                            WHERE stop_id = a.stop_id
                            GROUP BY stop_id), '') routes
                FROM sp_stop a
                ORDER BY 1
                LIMIT 0, 30";

        $this->con->ExecutaPrepared($sql, "dd", [(float)$lat, (float)$lon]);

        return $this->loadStopsFromResult();
    }

    private function loadStopsFromResult(){
        $list = array();
        while($this->con->Linha()){
            $rs = $this->con->rs;
            $obj = new BusStop();
            $obj->id = $rs["stop_id"] == null ? '' : $rs["stop_id"];
            $obj->name = $rs["stop_name"] ?? '';
            $obj->desc = $rs["stop_desc"] ?? '';
            $obj->lat = $rs["stop_lat"];
            $obj->lon = $rs["stop_lon"];
            $obj->routes = $rs["routes"];
            $obj->distance = $rs["distance"];

            array_push($list, $obj);
        }
        return $list;
    }
}
