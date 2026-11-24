package app.lolados.duesp.data.api

import kotlinx.serialization.Serializable

// Mirrors the JSON returned by https://sptrans.lolados.app/api (camelCase keys).

@Serializable
data class NearbyStopsResponse(val stops: List<NearbyStopDto> = emptyList())

@Serializable
data class NearbyStopDto(
    val id: Int,
    val name: String,
    val desc: String? = null,
    val lat: Double,
    val lon: Double,
    val routes: String? = null,
    val distance: Double = 0.0,
)

@Serializable
data class SearchStopsResponse(val stops: List<StopDto> = emptyList())

@Serializable
data class StopDto(
    val stopId: Int,
    val stopName: String,
    val stopDesc: String? = null,
    val stopLat: Double,
    val stopLon: Double,
    val routes: String? = null,
)

@Serializable
data class ArrivalsResponse(
    val queryDate: String? = null,
    val queryTime: String? = null,
    val arrivals: List<ArrivalDto> = emptyList(),
)

@Serializable
data class ArrivalDto(
    val source: String? = null,
    val vehicleId: String? = null,
    val tripId: String,
    val routeId: String,
    val routeShortName: String,
    val routeLongName: String = "",
    val headsign: String = "",
    val arrivalTime: String,
    val departureTime: String = "",
    val stopSequence: Int = 0,
    val routeType: Int = 3,
    val routeColor: String = "",
    val routeTextColor: String = "",
    val frequency: Int? = null,
    val waitTime: Int = 0,
    val serviceDate: String? = null,
    val scheduledTimestamp: Long? = null,
)

// trip.php?trip_id=… and shape.php?shape_id=…

@Serializable
data class TripResponse(val trip: TripDto)

@Serializable
data class TripDto(
    val tripId: String,
    val routeId: String = "",
    val headsign: String = "",
    val shapeId: String? = null,
    val stops: List<TripStopDto> = emptyList(),
)

@Serializable
data class TripStopDto(
    val stopId: Int,
    val stopName: String,
    val stopDesc: String? = null,
    val stopLat: Double,
    val stopLon: Double,
    val arrivalTime: String = "",
    val stopSequence: Int = 0,
)

@Serializable
data class ShapeResponse(val points: List<ShapePointDto> = emptyList())

@Serializable
data class ShapePointDto(val lat: Double, val lon: Double, val sequence: Int = 0)

@Serializable
data class RailStatusResponse(
    val generatedAt: String? = null,
    val metro: RailSourceStatusDto,
    val cptm: RailSourceStatusDto,
)

@Serializable
data class RailSourceStatusDto(
    val source: String,
    val available: Boolean = false,
    val lastSourceUpdatedAt: String? = null,
    val lines: List<RailLineStatusDto> = emptyList(),
)

// rail_alert_subscriptions.php (same contract as iOS, with platform = "android" and fcmToken)

@Serializable
data class AlertStateEnvelope(val success: Boolean = false, val state: AlertStateDto)

@Serializable
data class AlertStateDto(
    val installationId: String = "",
    val platform: String = "",
    val notificationsEnabled: Boolean = false,
    val authorizationStatus: String? = null,
    val subscriptions: List<AlertLineDto> = emptyList(),
)

@Serializable
data class AlertLineDto(
    val lineId: String,
    val source: String,
    val lineNumber: String,
    val lineName: String,
)

@Serializable
data class AlertUpdateRequest(
    val installationId: String,
    val action: String,
    val platform: String = "android",
    val fcmToken: String?,
    val notificationsEnabled: Boolean,
    val authorizationStatus: String,
    val locale: String,
    val timezone: String,
    val appVersion: String,
    val buildVersion: String,
    val lines: List<AlertLineDto>,
)

@Serializable
data class AlertUpdateResponse(val success: Boolean = false, val state: AlertStateDto)

@Serializable
data class RailLineStatusDto(
    val lineNumber: String,
    val lineName: String,
    val status: String,
    val statusDetail: String = "",
    val statusColor: String = "",
    val sourceUpdatedAt: String? = null,
)
