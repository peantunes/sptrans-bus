package app.lolados.duesp.ui.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.data.FavoritesRepository
import app.lolados.duesp.data.LatLon
import app.lolados.duesp.data.LocationProvider
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.domain.RailMapLine
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
    /** The user is outside the São Paulo metro area, so the map shows Praça da Sé instead. */
    val outsideServiceArea: Boolean = false,
    /** Bumped whenever the map should move to [center] (a new location, not every state change). */
    val recenterRequest: Int = 0,
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

    /** Metrô and CPTM lines, always drawn on the map. */
    private val _railLines = MutableStateFlow<List<RailMapLine>>(emptyList())
    val railLines: StateFlow<List<RailMapLine>> = _railLines.asStateFlow()

    val favorites: StateFlow<List<Stop>> =
        favoritesRepository.favorites.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private var started = false

    init {
        viewModelScope.launch { _railLines.value = repository.railNetwork() }
    }

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
            // The app only covers the São Paulo metro area: elsewhere, start from Praça da Sé.
            val outside = here != null && !ServiceArea.contains(here)
            val center = if (here == null || outside) LocationProvider.DEFAULT else here
            _state.update {
                it.copy(
                    center = center,
                    userLocation = here,
                    usingDefaultLocation = here == null,
                    outsideServiceArea = outside,
                    hasLocationPermission = location.hasPermission(),
                    recenterRequest = it.recenterRequest + 1,
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

/** São Paulo metro area, as on iOS (MKCoordinateRegion.saoPauloMetro): 0.9° around Praça da Sé. */
object ServiceArea {
    private const val HALF_SPAN = 0.45

    fun contains(point: LatLon): Boolean =
        point.lat in (LocationProvider.DEFAULT.lat - HALF_SPAN)..(LocationProvider.DEFAULT.lat + HALF_SPAN) &&
            point.lon in (LocationProvider.DEFAULT.lon - HALF_SPAN)..(LocationProvider.DEFAULT.lon + HALF_SPAN)
}
