package app.lolados.duesp.ui.stop

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.domain.Arrival
import app.lolados.duesp.domain.TripRoute
import app.lolados.duesp.domain.TripStop
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/** The arrival tapped at a stop: what the route screen needs, passed through navigation. */
@Serializable
data class TripSelection(
    val tripId: String,
    val stopId: Int,
    val stopSequence: Int,
    val routeShortName: String,
    val routeLongName: String,
    val headsign: String,
    val routeColor: String,
    val routeTextColor: String,
    /** GTFS time of this vehicle at the stop. */
    val arrivalTime: String,
    val frequencyMinutes: Int? = null,
) {
    companion object {
        fun of(arrival: Arrival, stopId: Int) = TripSelection(
            tripId = arrival.tripId,
            stopId = stopId,
            stopSequence = arrival.stopSequence,
            routeShortName = arrival.routeShortName,
            routeLongName = arrival.routeLongName,
            headsign = arrival.headsign,
            routeColor = arrival.routeColor,
            routeTextColor = arrival.routeTextColor,
            arrivalTime = arrival.arrivalTime,
            frequencyMinutes = arrival.frequencyMinutes,
        )
    }
}

data class TripDetailUiState(
    val route: TripRoute? = null,
    val isLoading: Boolean = true,
    val error: String? = null,
    /** Index in [TripRoute.stops] of the stop the user came from. */
    val currentIndex: Int = -1,
    /** HH:mm per stop, shifted to the vehicle the user tapped. */
    val times: List<String> = emptyList(),
)

class TripDetailViewModel(val selection: TripSelection, private val repository: TransitRepository) : ViewModel() {
    private val _state = MutableStateFlow(TripDetailUiState())
    val state: StateFlow<TripDetailUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.value = _state.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            runCatching { repository.trip(selection.tripId) }
                .onSuccess { route ->
                    val current = route.stops.indexOfFirst { it.sequence == selection.stopSequence }
                        .takeIf { it >= 0 } ?: route.stops.indexOfFirst { it.stopId == selection.stopId }
                    _state.value = TripDetailUiState(
                        route = route,
                        isLoading = false,
                        currentIndex = current,
                        times = shiftedTimes(route.stops, current),
                    )
                }
                .onFailure { e -> _state.value = _state.value.copy(isLoading = false, error = e.message) }
        }
    }

    /**
     * Trips that run by frequency carry the times of a template trip (e.g. from 04:00), so shift every stop
     * by the difference between the tapped arrival and the template time at that stop.
     */
    private fun shiftedTimes(stops: List<TripStop>, current: Int): List<String> {
        val offset = stops.getOrNull(current)?.let { stop ->
            val tapped = seconds(selection.arrivalTime)
            val template = seconds(stop.arrivalTime)
            if (tapped != null && template != null) tapped - template else null
        } ?: 0
        return stops.map { stop ->
            seconds(stop.arrivalTime)?.let { s ->
                val total = Math.floorMod(s + offset, 24 * 3600)
                "%02d:%02d".format(total / 3600, (total % 3600) / 60)
            } ?: ""
        }
    }

    private fun seconds(gtfs: String): Int? {
        val parts = gtfs.split(":").map { it.toIntOrNull() ?: return null }
        if (parts.size < 2) return null
        return parts[0] * 3600 + parts[1] * 60 + (parts.getOrNull(2) ?: 0)
    }
}
