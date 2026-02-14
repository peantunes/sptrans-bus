# Transit API Documentation

REST API for accessing São Paulo transit data (GTFS-based).

## Base URL

```
http://localhost:8080/api/
```

## Endpoints

### 0. Get Metro + CPTM Status

Returns Metro and CPTM line status from DB snapshots.  
If cached data is older than 30 minutes, the API refreshes from:

- Metro: `https://www.metro.sp.gov.br/wp-content/themes/metrosp/direto-metro.php`
- CPTM: `https://api.cptm.sp.gov.br/AppCPTM/v1/Linhas/ObterStatus` (JSON API)

**Endpoint:** `GET /api/metro_cptm.php`

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `refresh` | integer | No | 0 | Set to `1` to force refresh from source |

**Example Request:**
```
GET /api/metro_cptm.php
```

**Example Response:**
```json
{
  "generatedAt": "2026-02-14 13:35:20",
  "cacheTtlMinutes": 30,
  "refreshed": {
    "metro": false,
    "cptm": true
  },
  "metro": {
    "source": "metro",
    "available": true,
    "count": 5,
    "lastFetchedAt": "2026-02-14 13:10:00",
    "lastSourceUpdatedAt": "2026-02-14 13:01:36",
    "lines": []
  },
  "cptm": {
    "source": "cptm",
    "available": true,
    "count": 7,
    "lastFetchedAt": "2026-02-14 13:35:20",
    "lastSourceUpdatedAt": "2026-02-14 13:33:40",
    "lines": []
  },
  "errors": {}
}
```

---

### 1. Get Arrivals at Stop

Returns upcoming bus arrivals at a specific stop, considering the current day's service calendar.

**Endpoint:** `GET /api/arrivals.php`

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `stop_id` | string | Yes | - | The stop ID |
| `time` | string | No | Current time | Time in HH:MM:SS format |
| `date` | string | No | Today | Date in YYYY-MM-DD format |
| `limit` | integer | No | 20 | Maximum number of results |

**Example Request:**
```
GET /api/arrivals.php?stop_id=18848&limit=10
```

**Example Response:**
```json
{
  "stopId": "18848",
  "queryTime": "14:30:00",
  "queryDate": "2024-02-01",
  "count": 10,
  "arrivals": [
    {
      "tripId": "1012-10-0",
      "routeId": "1012-10",
      "routeShortName": "1012-10",
      "routeLongName": "Term. Jd. Britania - Jd. Monte Belo",
      "headsign": "Jd. Monte Belo",
      "arrivalTime": "14:35:00",
      "departureTime": "14:35:00",
      "stopSequence": 5,
      "routeType": 3,
      "routeColor": "509E2F",
      "routeTextColor": "FFFFFF",
      "frequency": 20,
      "waitTime": 5
    }
  ]
}
```

**Response Fields:**

| Field | Description |
|-------|-------------|
| `tripId` | Unique identifier for the trip |
| `routeId` | Route identifier |
| `routeShortName` | Short name/number of the route |
| `routeLongName` | Full route description |
| `headsign` | Final destination displayed on the bus |
| `arrivalTime` | Scheduled arrival time at the stop |
| `departureTime` | Scheduled departure time from the stop |
| `stopSequence` | Order of this stop in the trip |
| `routeType` | GTFS route type (3 = bus) |
| `routeColor` | Route color (hex) |
| `routeTextColor` | Text color for the route (hex) |
| `frequency` | Bus frequency in minutes (if available) |
| `waitTime` | Minutes until arrival |

---

### 2. Get Trip Route

Returns complete trip information including all stops in sequence order.

**Endpoint:** `GET /api/trip.php`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `trip_id` | string | Yes | The trip ID |

**Example Request:**
```
GET /api/trip.php?trip_id=1012-10-0
```

**Example Response:**
```json
{
  "trip": {
    "tripId": "1012-10-0",
    "routeId": "1012-10",
    "serviceId": "USD",
    "headsign": "Jd. Monte Belo",
    "directionId": 0,
    "shapeId": "84609",
    "stops": [
      {
        "stopId": "301790",
        "stopName": "Term. Jd. Britania",
        "stopDesc": "",
        "stopLat": -23.432024,
        "stopLon": -46.787121,
        "arrivalTime": "07:00:00",
        "departureTime": "07:00:00",
        "stopSequence": 1
      },
      {
        "stopId": "301791",
        "stopName": "Rua Example",
        "stopDesc": "",
        "stopLat": -23.433000,
        "stopLon": -46.788000,
        "arrivalTime": "07:05:00",
        "departureTime": "07:05:00",
        "stopSequence": 2
      }
    ]
  }
}
```

---

### 3. Get Route Information

Returns route details including all associated trips and fare information.

**Endpoint:** `GET /api/route.php`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `route_id` | string | Yes | The route ID |

**Example Request:**
```
GET /api/route.php?route_id=1012-10
```

**Example Response:**
```json
{
  "route": {
    "routeId": "1012-10",
    "agencyId": "1",
    "routeShortName": "1012-10",
    "routeLongName": "Term. Jd. Britania - Jd. Monte Belo",
    "routeType": 3,
    "routeColor": "509E2F",
    "routeTextColor": "FFFFFF",
    "trips": [
      {
        "tripId": "1012-10-0",
        "serviceId": "USD",
        "headsign": "Jd. Monte Belo",
        "directionId": 0,
        "shapeId": "84609"
      }
    ]
  },
  "fare": {
    "fareId": "BUS",
    "price": 4.40,
    "currencyType": "BRL",
    "paymentMethod": 0,
    "transfers": "",
    "transferDuration": 10800
  }
}
```

---

### 4. Get Stop Information

Returns stop details with routes serving the stop.

**Endpoint:** `GET /api/stop.php`

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `stop_id` | string | Yes | - | The stop ID |
| `include_arrivals` | string | No | 0 | Set to "1" to include upcoming arrivals |

**Example Request:**
```
GET /api/stop.php?stop_id=18848&include_arrivals=1
```

**Example Response:**
```json
{
  "stop": {
    "stopId": "18848",
    "stopName": "Clínicas",
    "stopDesc": "",
    "stopLat": -23.554022,
    "stopLon": -46.671108,
    "routes": "1012-10, 1012-21, 2345-10"
  },
  "routesAtStop": [
    {
      "routeId": "1012-10",
      "routeShortName": "1012-10",
      "routeLongName": "Term. Jd. Britania - Jd. Monte Belo",
      "routeType": 3,
      "routeColor": "509E2F",
      "routeTextColor": "FFFFFF"
    }
  ],
  "arrivals": [
    {
      "tripId": "1012-10-0",
      "routeId": "1012-10",
      "arrivalTime": "14:35:00",
      "waitTime": 5
    }
  ]
}
```

---

### 5. Search Stops

Search for stops by name.

**Endpoint:** `GET /api/search.php`

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `q` | string | Yes | - | Search query |
| `limit` | integer | No | 20 | Maximum results |

**Example Request:**
```
GET /api/search.php?q=Paulista&limit=10
```

**Example Response:**
```json
{
  "query": "Paulista",
  "count": 10,
  "stops": [
    {
      "stopId": "12345",
      "stopName": "Av. Paulista, 1000",
      "stopDesc": "",
      "stopLat": -23.561414,
      "stopLon": -46.656166,
      "routes": "1012-10, 2345-21"
    }
  ]
}
```

---

### 6. Get Shape Points

Returns shape points for drawing a route on a map. Supports GeoJSON format.

**Endpoint:** `GET /api/shape.php`

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `shape_id` | string | Yes | - | The shape ID |
| `format` | string | No | array | "geojson" for GeoJSON format |

**Example Request (Array format):**
```
GET /api/shape.php?shape_id=84609
```

**Example Response (Array):**
```json
{
  "shapeId": "84609",
  "count": 150,
  "points": [
    {
      "lat": -23.432024,
      "lon": -46.787121,
      "sequence": 1,
      "distTraveled": 0
    },
    {
      "lat": -23.432100,
      "lon": -46.787200,
      "sequence": 2,
      "distTraveled": 15.5
    }
  ]
}
```

**Example Request (GeoJSON format):**
```
GET /api/shape.php?shape_id=84609&format=geojson
```

**Example Response (GeoJSON):**
```json
{
  "type": "Feature",
  "properties": {
    "shapeId": "84609"
  },
  "geometry": {
    "type": "LineString",
    "coordinates": [
      [-46.787121, -23.432024],
      [-46.787200, -23.432100]
    ]
  }
}
```

---

### 7. Get All Routes

Returns a paginated list of all routes.

**Endpoint:** `GET /api/routes.php`

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `limit` | integer | No | 100 | Maximum results |
| `offset` | integer | No | 0 | Offset for pagination |

**Example Request:**
```
GET /api/routes.php?limit=50&offset=0
```

**Example Response:**
```json
{
  "limit": 50,
  "offset": 0,
  "count": 50,
  "routes": [
    {
      "routeId": "1012-10",
      "routeShortName": "1012-10",
      "routeLongName": "Term. Jd. Britania - Jd. Monte Belo",
      "routeType": 3,
      "routeColor": "509E2F",
      "routeTextColor": "FFFFFF"
    }
  ]
}
```

---

### 8. Get Nearby Stops

Returns stops near a geographic coordinate, sorted by distance.

**Endpoint:** `GET /api/nearby.php`

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `lat` | float | Yes | - | Latitude |
| `lon` | float | Yes | - | Longitude |
| `limit` | integer | No | 20 | Maximum results |
| `include_arrivals` | string | No | 0 | Set to "1" to include arrivals |

**Example Request:**
```
GET /api/nearby.php?lat=-23.554022&lon=-46.671108&limit=10&include_arrivals=1
```

**Example Response:**
```json
{
  "lat": -23.554022,
  "lon": -46.671108,
  "count": 10,
  "stops": [
    {
      "id": "18848",
      "name": "Clínicas",
      "desc": "",
      "lat": -23.554022,
      "lon": -46.671108,
      "routes": "1012-10, 1012-21",
      "distance": 0.00001,
      "arrivals": [
        {
          "tripId": "1012-10-0",
          "arrivalTime": "14:35:00",
          "waitTime": 5
        }
      ]
    }
  ]
}
```

---

## Error Responses

All endpoints return errors in the following format:

**400 Bad Request** - Missing required parameters:
```json
{
  "error": "Missing required parameter: stop_id"
}
```

**404 Not Found** - Resource not found:
```json
{
  "error": "Stop not found",
  "stopId": "invalid_id"
}
```

---

## Route Types (GTFS)

| Type | Description |
|------|-------------|
| 0 | Tram, Streetcar, Light rail |
| 1 | Subway, Metro |
| 2 | Rail |
| 3 | Bus |
| 4 | Ferry |
| 5 | Cable car |
| 6 | Gondola |
| 7 | Funicular |

---

## Calendar Service IDs

Common service patterns:

| Service ID | Description |
|------------|-------------|
| USD | Every day (Mon-Sun) |
| U__ | Weekdays only (Mon-Fri) |
| __D | Weekends only (Sat-Sun) |

---

## Notes

- All times are in the `America/Sao_Paulo` timezone
- Coordinates use WGS84 (standard GPS coordinates)
- The `waitTime` field in arrivals is calculated in minutes from the query time
- Shape coordinates in GeoJSON format follow [longitude, latitude] order per GeoJSON spec
