package app.lolados.duesp.domain

import kotlinx.serialization.Serializable

@Serializable
data class Stop(
    val id: Int,
    val name: String,
    val description: String? = null,
    val lat: Double,
    val lon: Double,
    val routes: String? = null,
    /** Distance in meters, only set for nearby results. */
    val distanceMeters: Int? = null,
) {
    val mode: TransitMode get() = TransitMode.fromRoutes(routes)

    /** Route list without duplicates ("METRÔ L3, METRÔ L3" → ["METRÔ L3"]). */
    val routeList: List<String>
        get() = routes.orEmpty().split(",").map { it.trim() }.filter { it.isNotEmpty() }.distinct()
}

enum class TransitMode {
    BUS, METRO, TRAIN;

    companion object {
        fun fromRoutes(routes: String?): TransitMode {
            val value = routes.orEmpty().uppercase()
            return when {
                value.contains("METRÔ") || value.contains("METRO") -> METRO
                value.contains("CPTM") -> TRAIN
                else -> BUS
            }
        }
    }
}

data class Arrival(
    val tripId: String,
    val routeShortName: String,
    val routeLongName: String,
    val headsign: String,
    /** GTFS time, may exceed 24:00:00 for trips past midnight. */
    val arrivalTime: String,
    val routeType: Int,
    val routeColor: String,
    val routeTextColor: String,
    val waitMinutes: Int,
    val serviceDate: String?,
    val scheduledTimestamp: Long?,
    val stopSequence: Int,
    /** Minutes between departures, when the line runs by frequency. */
    val frequencyMinutes: Int? = null,
) {
    val identity: String get() = "$tripId|$serviceDate|$scheduledTimestamp|$stopSequence"

    /**
     * Minutes until arrival, recomputed from the scheduled timestamp (the API `waitTime` is relative to
     * the query time and goes stale). Negative values mean the vehicle already passed.
     */
    fun minutesUntil(nowEpochSeconds: Long): Int =
        scheduledTimestamp?.let { Math.ceil((it - nowEpochSeconds) / 60.0).toInt() } ?: waitMinutes

    /** HH:mm display, wrapping GTFS hours ≥ 24. */
    val displayTime: String
        get() {
            val parts = arrivalTime.split(":")
            val hour = parts.getOrNull(0)?.toIntOrNull() ?: return arrivalTime
            val minute = parts.getOrNull(1) ?: "00"
            return "%02d:%s".format(hour % 24, minute)
        }
}

/** One stop of a trip, in order. [arrivalTime] is GTFS (may exceed 24:00:00). */
data class TripStop(
    val stopId: Int,
    val name: String,
    val lat: Double,
    val lon: Double,
    val arrivalTime: String,
    val sequence: Int,
) {
    val displayTime: String
        get() {
            val parts = arrivalTime.split(":")
            val hour = parts.getOrNull(0)?.toIntOrNull() ?: return ""
            return "%02d:%s".format(hour % 24, parts.getOrNull(1) ?: "00")
        }
}

/** A trip with all its stops and, when the API has it, the geometry of the route. */
data class TripRoute(
    val tripId: String,
    val headsign: String,
    val stops: List<TripStop>,
    /** (lat, lon) pairs; empty when there is no shape, then the stops are joined instead. */
    val shape: List<Pair<Double, Double>>,
)

/** A Metrô or CPTM line on the main map: its colour and stations in order. */
data class RailMapLine(
    val id: String,
    val name: String,
    val source: RailSource,
    val colorHex: String,
    val stations: List<RailStation>,
)

data class RailStation(val stopId: Int, val name: String, val lat: Double, val lon: Double)

enum class RailSource { METRO, CPTM }

data class RailLineStatus(
    val source: RailSource,
    val number: String,
    val name: String,
    val status: String,
    val detail: String,
    val statusColor: String,
    val updatedAt: String?,
) {
    val isNormal: Boolean
        get() = status.contains("normal", ignoreCase = true)
}

data class RailNetworkStatus(
    val metro: List<RailLineStatus>,
    val cptm: List<RailLineStatus>,
    val metroAvailable: Boolean,
    val cptmAvailable: Boolean,
    val generatedAt: String?,
)
