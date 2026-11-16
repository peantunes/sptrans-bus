package app.lolados.duesp.data

import app.lolados.duesp.data.api.ArrivalDto
import app.lolados.duesp.data.api.RailLineStatusDto
import app.lolados.duesp.data.api.TransitApi
import app.lolados.duesp.domain.Arrival
import app.lolados.duesp.domain.RailLineStatus
import app.lolados.duesp.domain.RailNetworkStatus
import app.lolados.duesp.domain.RailSource
import app.lolados.duesp.domain.Stop
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

class TransitRepository(private val api: TransitApi) {

    suspend fun nearbyStops(lat: Double, lon: Double, limit: Int = 30): List<Stop> =
        api.nearby(lat, lon, limit).stops.map {
            Stop(
                id = it.id,
                name = it.name,
                description = it.desc?.ifBlank { null },
                lat = it.lat,
                lon = it.lon,
                routes = it.routes,
                // The API "distance" is a Manhattan distance in degrees (BusInfo.class.php), so compute meters here.
                distanceMeters = haversineMeters(lat, lon, it.lat, it.lon).roundToInt(),
            )
        }.sortedBy { it.distanceMeters }

    suspend fun searchStops(query: String): List<Stop> =
        api.search(query).stops.map {
            Stop(it.stopId, it.stopName, it.stopDesc?.ifBlank { null }, it.stopLat, it.stopLon, it.routes)
        }

    suspend fun arrivals(
        stopId: Int,
        limit: Int,
        date: String? = null,
        time: String? = null,
        cursorDate: String? = null,
        cursorTime: String? = null,
        direction: String = "next",
    ): List<Arrival> =
        api.arrivals(stopId, limit, date, time, cursorDate, cursorTime, direction).arrivals.map { it.toDomain() }

    suspend fun railStatus(refresh: Boolean = false): RailNetworkStatus {
        val response = api.railStatus(refresh)
        return RailNetworkStatus(
            metro = response.metro.lines.map { it.toDomain(RailSource.METRO) }.sortedBy { it.number.toIntOrNull() ?: 99 },
            cptm = response.cptm.lines.map { it.toDomain(RailSource.CPTM) }.sortedBy { it.number.toIntOrNull() ?: 99 },
            metroAvailable = response.metro.available,
            cptmAvailable = response.cptm.available,
            generatedAt = response.generatedAt,
        )
    }

    companion object {
        fun haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
            val r = 6_371_000.0
            val dLat = Math.toRadians(lat2 - lat1)
            val dLon = Math.toRadians(lon2 - lon1)
            val a = sin(dLat / 2).pow(2) + cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2).pow(2)
            return 2 * r * atan2(sqrt(a), sqrt(1 - a))
        }
    }

    private fun ArrivalDto.toDomain() = Arrival(
        tripId = tripId,
        routeShortName = routeShortName,
        routeLongName = routeLongName,
        headsign = headsign,
        arrivalTime = arrivalTime,
        routeType = routeType,
        routeColor = routeColor,
        routeTextColor = routeTextColor,
        waitMinutes = waitTime,
        serviceDate = serviceDate,
        scheduledTimestamp = scheduledTimestamp,
        stopSequence = stopSequence,
    )

    private fun RailLineStatusDto.toDomain(source: RailSource) = RailLineStatus(
        source = source,
        number = lineNumber,
        name = lineName,
        status = status,
        detail = statusDetail,
        statusColor = statusColor,
        updatedAt = sourceUpdatedAt,
    )
}
