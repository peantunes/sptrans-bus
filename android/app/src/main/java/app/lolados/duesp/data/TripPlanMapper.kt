package app.lolados.duesp.data

import app.lolados.duesp.data.api.PlanAlternativeDto
import app.lolados.duesp.data.api.PlanDepartureDto
import app.lolados.duesp.data.api.PlanLegDto
import app.lolados.duesp.data.api.PlanResultDto
import app.lolados.duesp.data.api.PlanRouteDto
import app.lolados.duesp.data.api.PlanSegmentDto
import app.lolados.duesp.data.api.PlanStopDto
import app.lolados.duesp.data.api.PlanWalkOptionDto
import app.lolados.duesp.domain.Journey
import app.lolados.duesp.domain.JourneyStep
import app.lolados.duesp.domain.Place
import app.lolados.duesp.domain.PlanRoute
import app.lolados.duesp.domain.RideLeg
import app.lolados.duesp.domain.TimedStop
import app.lolados.duesp.domain.TripPlan
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * Maps plan.php into ordered journey steps. Planner v2 sends `segments` (walking and
 * transit in order); the legacy shape only has vehicle `legs` (or `data`), so walks to
 * and from the stops are estimated from the request's origin and destination.
 */
class TripPlanMapper(private val json: Json = Json { ignoreUnknownKeys = true; coerceInputValues = true }) {

    fun map(result: PlanResultDto, origin: Place, destination: Place): TripPlan {
        val journeys = result.alternatives.mapIndexedNotNull { index, dto -> mapAlternative(index, dto, origin, destination) }
        val departure = decodeOrNull<PlanDepartureDto>(result.departure)?.time
        val walkOnly = decodeOrNull<PlanWalkOptionDto>(result.walk)?.let { walk ->
            val minutes = walk.durationMinutes ?: return@let null
            val meters = walk.distanceMeters ?: return@let null
            Journey(
                id = journeys.size,
                startTime = departure,
                endTime = walk.arrivalTime,
                durationMinutes = minutes,
                walkMeters = meters,
                walkMinutes = minutes,
                transfers = 0,
                stopCount = null,
                steps = listOf(JourneyStep.Walk(origin, destination, departure, walk.arrivalTime, minutes, meters, toDestination = true)),
                isWalkOnly = true,
            )
        }
        return TripPlan(journeys, walkOnly)
    }

    private fun mapAlternative(index: Int, dto: PlanAlternativeDto, origin: Place, destination: Place): Journey? {
        val segments = decodeOrNull<List<PlanSegmentDto>>(dto.segments).orEmpty()
        val steps = if (segments.any { it.type == "transit" }) {
            stepsFromSegments(segments, destination)
        } else {
            legacySteps(dto, origin, destination)
        }
        if (steps.none { it is JourneyStep.Ride }) return null
        val summary = dto.summary
        val rides = steps.filterIsInstance<JourneyStep.Ride>()
        return Journey(
            id = index,
            startTime = summary?.startTime ?: summary?.departureTime,
            endTime = summary?.endTime ?: summary?.arrivalTime,
            durationMinutes = summary?.durationMinutes,
            walkMeters = summary?.walkMeters,
            walkMinutes = summary?.walkMinutes,
            transfers = summary?.transferCount ?: (rides.size - 1).coerceAtLeast(0),
            stopCount = summary?.stopCount,
            steps = steps,
        )
    }

    private fun stepsFromSegments(segments: List<PlanSegmentDto>, destination: Place): List<JourneyStep> =
        segments.mapIndexedNotNull { index, segment ->
            when (segment.type) {
                "transit" -> ride(
                    route = segment.route,
                    mode = segment.mode,
                    headsign = segment.headsign,
                    origin = segment.originStop,
                    destination = segment.destinationStop,
                    departure = segment.departureTime,
                    arrival = segment.arrivalTime,
                    intermediate = segment.intermediateStops,
                    duration = segment.durationMinutes,
                    headway = segment.headwayMinutes,
                )
                "walk" -> {
                    val minutes = segment.durationMinutes ?: return@mapIndexedNotNull null
                    val last = index == segments.lastIndex
                    JourneyStep.Walk(
                        from = segment.from.toPlace(""),
                        to = if (last) destination else segment.to.toPlace(destination.name),
                        departureTime = segment.departureTime,
                        arrivalTime = segment.arrivalTime,
                        minutes = minutes,
                        meters = segment.distanceMeters ?: 0,
                        toDestination = last,
                    )
                }
                else -> null
            }
        }

    private fun legacySteps(dto: PlanAlternativeDto, origin: Place, destination: Place): List<JourneyStep> {
        val legs: List<PlanLegDto> = dto.legs.orEmpty().ifEmpty {
            val data = dto.data ?: return emptyList()
            if (dto.type == "transfer") {
                listOf(
                    PlanLegDto(route = data.originRoute, tripId = data.originTripId, originStop = data.originStop, destinationStop = data.transferStop),
                    PlanLegDto(route = data.destinationRoute, tripId = data.destinationTripId, originStop = data.transferStop, destinationStop = data.destinationStop),
                )
            } else {
                listOf(PlanLegDto(route = data.route, tripId = data.tripId, originStop = data.originStop, destinationStop = data.destinationStop))
            }
        }
        val rides = legs.mapNotNull {
            ride(it.route, it.mode, it.headsign, it.originStop, it.destinationStop, it.departureTime, it.arrivalTime,
                it.intermediateStops, it.durationMinutes, it.headwayMinutes)
        }
        if (rides.isEmpty()) return emptyList()
        val steps = mutableListOf<JourneyStep>()
        estimatedWalk(origin, rides.first().leg.board.place, toDestination = false)?.let(steps::add)
        rides.forEachIndexed { i, ride ->
            steps += ride
            rides.getOrNull(i + 1)?.let { next ->
                estimatedWalk(ride.leg.alight.place, next.leg.board.place, toDestination = false)?.let(steps::add)
            }
        }
        estimatedWalk(rides.last().leg.alight.place, destination, toDestination = true)?.let(steps::add)
        return steps
    }

    private fun ride(
        route: PlanRouteDto?,
        mode: String?,
        headsign: String?,
        origin: PlanStopDto?,
        destination: PlanStopDto?,
        departure: String?,
        arrival: String?,
        intermediate: List<PlanStopDto>?,
        duration: Int?,
        headway: Int?,
    ): JourneyStep.Ride? {
        if (origin == null && destination == null) return null
        val planRoute = route?.let {
            PlanRoute(
                id = it.routeId.orEmpty(),
                shortName = it.shortName ?: it.routeId.orEmpty(),
                longName = it.longName.orEmpty(),
                color = it.color.orEmpty(),
                textColor = it.textColor.orEmpty(),
                type = it.type,
            )
        }
        return JourneyStep.Ride(
            RideLeg(
                route = planRoute,
                mode = RideLeg.modeOf(mode, route?.type),
                headsign = headsign?.ifBlank { null },
                board = origin.toTimedStop(departure),
                alight = destination.toTimedStop(arrival),
                intermediate = intermediate.orEmpty().map { it.toTimedStop(it.time) },
                durationMinutes = duration,
                headwayMinutes = headway,
            ),
        )
    }

    /** Straight-line walk at 80 m/min, skipped under 120 m (legacy responses only). */
    private fun estimatedWalk(from: Place, to: Place, toDestination: Boolean): JourneyStep.Walk? {
        if (!from.hasLocation || !to.hasLocation) return null
        val meters = TransitRepository.haversineMeters(from.lat!!, from.lon!!, to.lat!!, to.lon!!)
        if (meters < 120) return null
        return JourneyStep.Walk(from, to, null, null, ceil(meters / 80).toInt().coerceAtLeast(1), meters.roundToInt(), toDestination)
    }

    private fun PlanStopDto?.toPlace(fallbackName: String) = Place(this?.name ?: fallbackName, this?.lat, this?.lon)

    private fun PlanStopDto?.toTimedStop(time: String?) =
        TimedStop(this?.id, this?.name.orEmpty(), this?.lat, this?.lon, time)

    private inline fun <reified T> decodeOrNull(element: JsonElement?): T? {
        if (element == null || element is JsonNull) return null
        return runCatching { json.decodeFromJsonElement<T>(element) }.getOrNull()
    }
}
