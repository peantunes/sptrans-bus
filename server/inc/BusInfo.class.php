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
        
        $sql = "select
                    b.*, c.trip_headsign, a.trip_id, a.arrival_time, a.stop_id, a.stop_sequence, (select round(headway_secs/60) from sp_frequencies 
                                where trip_id=a.trip_id 
                                AND start_time <= TIME_FORMAT(\"$time\",\"%H:%i:%s\") 
                                AND end_time >= TIME_FORMAT(\"$time\",\"%H:%i:%s\")) freq
                    from sp_stop_times a, sp_routes b, sp_trip c
                    where a.stop_id = '$stopId'
                        and b.route_id = c.route_id
                        and a.trip_id = c.trip_id
                        
                order by a.arrival_time";
        //echo $sql;   
        $this->con->Executa($sql);
        
        
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
    
    public function listStopsByStopsAndGeo($stops, $lat="", $long=""){
        $stopItems = implode("','", explode(",", $stops));
        $sql = "select abs(abs(a.stop_lat-('$lat')) 
                                            + abs(a.stop_lon-('$lon'))) as distance, a.*,
                            (SELECT group_concat(b1.route_id separator ', ') FROM `sp_stop_times` a1, sp_trip b1 where a1.trip_id=b1.trip_id  and stop_id=a.stop_id group by stop_id) routes
                        from sp_stop a where stop_id in ('$stopItems')";
        
        return $this->loadStops($sql);
    }
    
    public function listStopsByGeo($lat, $lon){
        $sql = "select abs(abs(a.stop_lat-('$lat')) 
                                            + abs(a.stop_lon-('$lon'))) as distance, a.*, 
                                            IFNULL((SELECT group_concat(b1.route_id separator ', ') FROM `sp_stop_times` a1, sp_trip b1 where a1.trip_id=b1.trip_id  and stop_id=a.stop_id group by stop_id), '') routes
                                            from sp_stop a order by 1 limit 0,30";
                                            
            /*				
        $sql = "select abs(abs(a.stop_lat-('$lat')) 
                                            + abs(a.stop_lon-('$lon'))) as distance, a.*, 
                                    (SELECT group_concat(xx.route_id separator ', ')
                                        from (select a1.stop_id, b1.route_id FROM `sp_stop_times` a1, sp_trip b1 where a1.trip_id=b1.trip_id
                                        and a1.stop_id=a.stop_id group by stop_id, b1.route_id) xx group by xx.stop_id)
                                
                            from sp_stop a order by 1 limit 0,30";
                            */
        
        return $this->loadStops($sql);
        
    }
    
    private function loadStops($sql){
        $this->con->Executa($sql);
        $list = array();
        while($this->con->Linha()){
            $rs = $this->con->rs;
            $obj = new BusStop();
            $obj->id = $rs["stop_id"] == null?'':$rs["stop_id"];
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