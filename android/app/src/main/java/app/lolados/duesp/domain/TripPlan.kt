package app.lolados.duesp.domain

import kotlinx.serialization.Serializable

/** Free tier limits for the planner; Premium has none (same rules as iOS). */
object PlannerLimits {
    const val FREE_SAVED_ROUTES = 2
    const val FREE_DAILY_SEARCHES = 5
}

/** Last planner form, restored when the screen opens again. Times are not kept: searches start from now. */
@Serializable
data class PlanFormSnapshot(
    val origin: Place? = null,
    val originIsCurrentLocation: Boolean = false,
    val destination: Place? = null,
    val priority: String = "arrives_first",
    val maxTransfers: Int = 3,
)

/** A saved origin → destination pair. "Current location" origins are resolved when used. */
@Serializable
data class SavedRoute(
    val id: String,
    val origin: Place,
    val destination: Place,
    val originIsCurrentLocation: Boolean = false,
)

/** Planner result: transit journeys plus, for short trips, a walk-only option. */
data class TripPlan(
    val journeys: List<Journey>,
    val walkOnly: Journey? = null,
) {
    val all: List<Journey> get() = journeys + listOfNotNull(walkOnly)
}

/** One door-to-door option, as an ordered list of walking and riding steps. */
data class Journey(
    val id: Int,
    /** When to leave the origin (GTFS time, may pass 24:00). */
    val startTime: String?,
    /** When you reach the destination. */
    val endTime: String?,
    val durationMinutes: Int?,
    val walkMeters: Int?,
    val walkMinutes: Int?,
    val transfers: Int,
    val stopCount: Int?,
    val steps: List<JourneyStep>,
    val isWalkOnly: Boolean = false,
) {
    val rides: List<RideLeg> get() = steps.filterIsInstance<JourneyStep.Ride>().map { it.leg }
}

sealed interface JourneyStep {
    data class Walk(
        val from: Place,
        val to: Place,
        val departureTime: String?,
        val arrivalTime: String?,
        val minutes: Int,
        val meters: Int,
        /** Last step of the journey: the target is the destination itself. */
        val toDestination: Boolean,
    ) : JourneyStep

    data class Ride(val leg: RideLeg) : JourneyStep
}

@Serializable
data class Place(val name: String, val lat: Double?, val lon: Double?) {
    val hasLocation: Boolean get() = lat != null && lon != null && !(lat == 0.0 && lon == 0.0)
}

data class PlanRoute(
    val id: String,
    val shortName: String,
    val longName: String,
    val color: String,
    val textColor: String,
    val type: Int?,
) {
    val displayName: String get() = shortName.ifBlank { id }
}

data class TimedStop(val id: Int?, val name: String, val lat: Double?, val lon: Double?, val time: String?) {
    val place: Place get() = Place(name, lat, lon)
}

data class RideLeg(
    val route: PlanRoute?,
    val mode: TransitMode,
    val headsign: String?,
    val board: TimedStop,
    val alight: TimedStop,
    val intermediate: List<TimedStop>,
    val durationMinutes: Int?,
    val headwayMinutes: Int?,
) {
    /** Stops in travel order, boarding and alighting included. */
    val allStops: List<TimedStop> get() = listOf(board) + intermediate + listOf(alight)

    companion object {
        /** "metro"/"rail"/"bus" from the planner, or GTFS route_type. */
        fun modeOf(mode: String?, routeType: Int?): TransitMode = when (mode?.lowercase()) {
            "metro" -> TransitMode.METRO
            "rail" -> TransitMode.TRAIN
            "bus" -> TransitMode.BUS
            else -> when (routeType) {
                1 -> TransitMode.METRO
                0, 2 -> TransitMode.TRAIN
                else -> TransitMode.BUS
            }
        }
    }
}

object GtfsTime {
    /** "HH:MM[:SS]" with hours possibly ≥ 24 → "HH:MM" on a 24h clock; null stays null. */
    fun display(value: String?): String? {
        if (value.isNullOrBlank()) return null
        val parts = value.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: return value
        val minute = parts.getOrNull(1)?.toIntOrNull() ?: return value
        return "%02d:%02d".format(hour % 24, minute)
    }

    fun duration(minutes: Int): String = when {
        minutes < 60 -> "$minutes min"
        minutes % 60 == 0 -> "${minutes / 60} h"
        else -> "${minutes / 60} h ${minutes % 60} min"
    }
}
