package app.lolados.duesp.data

import app.lolados.duesp.data.api.ArrivalDto
import app.lolados.duesp.data.api.RailLineStatusDto
import app.lolados.duesp.data.api.TransitApi
import app.lolados.duesp.domain.Arrival
import app.lolados.duesp.domain.Place
import app.lolados.duesp.domain.TripPlan
import java.time.LocalDateTime
import app.lolados.duesp.domain.RailLineStatus
import app.lolados.duesp.domain.RailNetworkStatus
import app.lolados.duesp.domain.RailSource
import app.lolados.duesp.domain.RailMapLine
import app.lolados.duesp.domain.RailStation
import app.lolados.duesp.domain.Stop
import app.lolados.duesp.domain.TripRoute
import app.lolados.duesp.domain.TripStop
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

class TransitRepository(private val api: TransitApi) {
    private val planMapper = TripPlanMapper()

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

    /** [departure] is a São Paulo wall-clock time, always sent (for "now", the moment of the search). */
    suspend fun planTrip(
        origin: Place,
        destination: Place,
        departure: LocalDateTime,
        rankingPriority: String,
        maxTransfers: Int,
    ): TripPlan {
        val response = api.plan(
            originLat = origin.lat ?: error("origin without location"),
            originLon = origin.lon ?: error("origin without location"),
            destLat = destination.lat ?: error("destination without location"),
            destLon = destination.lon ?: error("destination without location"),
            date = departure.toLocalDate().toString(),
            time = "%02d:%02d".format(departure.hour, departure.minute),
            rankingPriority = rankingPriority,
            maxTransfers = maxTransfers,
        )
        return planMapper.map(response.result, origin, destination)
    }

    /** A trip with all its stops in order, plus its geometry when available (the shape is optional). */
    suspend fun trip(tripId: String): TripRoute = coroutineScope {
        val trip = api.trip(tripId).trip
        val shape = trip.shapeId?.takeIf { it.isNotBlank() }?.let { id ->
            async { runCatching { api.shape(id).points.sortedBy { it.sequence }.map { it.lat to it.lon } }.getOrNull() }
        }
        val seen = HashSet<Int>()
        TripRoute(
            tripId = trip.tripId,
            headsign = trip.headsign,
            stops = trip.stops.sortedBy { it.stopSequence }
                .filter { seen.add(it.stopSequence) }
                .map { TripStop(it.stopId, it.stopName, it.stopLat, it.stopLon, it.arrivalTime, it.stopSequence) },
            shape = shape?.await().orEmpty(),
        )
    }

    private val railNetworkLock = Mutex()
    @Volatile private var railNetworkCache: List<RailMapLine>? = null

    /**
     * Metrô and CPTM lines for the main map, loaded once per process (lines barely change). A line whose
     * trip can't be loaded uses the built-in outline; if every request fails, nothing is cached so the
     * next call tries again.
     */
    suspend fun railNetwork(): List<RailMapLine> = railNetworkLock.withLock {
        railNetworkCache?.let { return it }
        val loaded = coroutineScope {
            RailNetwork.sources.map { source ->
                async {
                    runCatching {
                        val trip = api.trip(source.tripId).trip
                        val seen = HashSet<Int>()
                        val stations = trip.stops.sortedBy { it.stopSequence }
                            .filter { seen.add(it.stopId) }
                            .map { RailStation(it.stopId, it.stopName, it.stopLat, it.stopLon) }
                        RailMapLine(source.id, source.name, source.source, source.colorHex, stations)
                    }.getOrNull()?.takeIf { it.stations.size >= 2 }
                }
            }.awaitAll()
        }
        val lines = RailNetwork.sources.mapIndexed { index, source -> loaded[index] ?: RailNetwork.fallback(source) }
        if (loaded.any { it != null }) railNetworkCache = lines
        lines
    }

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
        frequencyMinutes = frequency?.takeIf { it > 0 },
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
