package app.lolados.duesp.ui.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.data.FavoritesRepository
import app.lolados.duesp.data.LatLon
import app.lolados.duesp.data.LocationProvider
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.domain.Stop
import app.lolados.duesp.domain.TransitMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class MapUiState(
    val center: LatLon = LocationProvider.DEFAULT,
    val userLocation: LatLon? = null,
    val stops: List<Stop> = emptyList(),
    val filter: TransitMode? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val usingDefaultLocation: Boolean = false,
    val hasLocationPermission: Boolean = false,
) {
    val visibleStops: List<Stop> get() = filter?.let { mode -> stops.filter { it.mode == mode } } ?: stops
}

class MapViewModel(
    private val repository: TransitRepository,
    private val location: LocationProvider,
    private val favoritesRepository: FavoritesRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(MapUiState())
    val state: StateFlow<MapUiState> = _state.asStateFlow()

    val favorites: StateFlow<List<Stop>> =
        favoritesRepository.favorites.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private var started = false

    /** Called once the location permission prompt has been answered (granted or not). */
    fun start() {
        if (started) return
        started = true
        locateAndLoad()
    }

    fun locateAndLoad() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            val here = location.currentLocation()
            val center = here ?: LocationProvider.DEFAULT
            _state.update {
                it.copy(
                    center = center,
                    userLocation = here,
                    usingDefaultLocation = here == null,
                    hasLocationPermission = location.hasPermission(),
                )
            }
            load(center)
        }
    }

    fun searchHere(center: LatLon) {
        _state.update { it.copy(center = center) }
        viewModelScope.launch { load(center) }
    }

    fun setFilter(mode: TransitMode?) = _state.update { it.copy(filter = mode) }

    private suspend fun load(center: LatLon) {
        _state.update { it.copy(isLoading = true, error = null) }
        runCatching { repository.nearbyStops(center.lat, center.lon, limit = 40) }
            .onSuccess { stops -> _state.update { it.copy(stops = stops, isLoading = false) } }
            .onFailure { e -> _state.update { it.copy(isLoading = false, error = e.message) } }
    }
}
