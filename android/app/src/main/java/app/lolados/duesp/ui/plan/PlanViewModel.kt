package app.lolados.duesp.ui.plan

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.data.LatLon
import app.lolados.duesp.data.PlaceSuggestion
import app.lolados.duesp.data.PlannerStorage
import app.lolados.duesp.domain.Journey
import app.lolados.duesp.domain.Place
import app.lolados.duesp.domain.PlannerLimits
import app.lolados.duesp.domain.SavedRoute
import app.lolados.duesp.domain.TripPlan
import app.lolados.duesp.domain.PlanFormSnapshot
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.UUID

enum class PlanField { ORIGIN, DESTINATION }

enum class PlanPriority(val apiValue: String) {
    ARRIVES_FIRST("arrives_first"),
    FEWEST_TRANSFERS("fewest_transfers"),
    LEAST_WALKING("least_walking"),
}

/** Why the free tier stopped an action; the screen offers Premium. */
enum class PremiumPrompt { SAVE_LIMIT, SEARCH_LIMIT, CHOOSE_TIME }

data class PlaceField(val text: String = "", val place: Place? = null, val isCurrentLocation: Boolean = false)

/** What a finished search was for, shown above and inside the results. */
data class PlanContext(val origin: Place, val destination: Place, val departure: LocalDateTime)

data class PlanUiState(
    val origin: PlaceField = PlaceField(),
    val destination: PlaceField = PlaceField(),
    val activeField: PlanField? = null,
    val suggestions: List<PlaceSuggestion> = emptyList(),
    val isSuggesting: Boolean = false,
    /** null = leave now (the time the search button is pressed). São Paulo wall-clock time. Premium only. */
    val departAt: LocalDateTime? = null,
    val priority: PlanPriority = PlanPriority.ARRIVES_FIRST,
    val maxTransfers: Int = 3,
    val isPlanning: Boolean = false,
    val plan: TripPlan? = null,
    val context: PlanContext? = null,
    val error: String? = null,
    val locationUnavailable: Boolean = false,
    val isPremium: Boolean = false,
    val savedRoutes: List<SavedRoute> = emptyList(),
    val searchesToday: Int = 0,
    val premiumPrompt: PremiumPrompt? = null,
) {
    val canPlan: Boolean get() = origin.place != null && destination.place != null && !isPlanning

    /** Remaining searches today on the free tier; null for Premium. */
    val searchesLeft: Int? get() = if (isPremium) null else (PlannerLimits.FREE_DAILY_SEARCHES - searchesToday).coerceAtLeast(0)

    val currentRouteIsSaved: Boolean
        get() = savedRoutes.any { it.matches(origin, destination) }

    val canSaveCurrentRoute: Boolean
        get() = origin.place != null && destination.place != null && !currentRouteIsSaved

    val hasFormContent: Boolean
        get() = origin.text.isNotBlank() || destination.text.isNotBlank() || departAt != null
}

private fun SavedRoute.matches(origin: PlaceField, destination: PlaceField): Boolean {
    val o = origin.place ?: return false
    val d = destination.place ?: return false
    val sameOrigin = if (originIsCurrentLocation) origin.isCurrentLocation else !origin.isCurrentLocation && this.origin == o
    return sameOrigin && this.destination == d
}

class PlanViewModel(
    private val planTrip: suspend (Place, Place, LocalDateTime, String, Int) -> TripPlan,
    private val suggest: suspend (String) -> List<PlaceSuggestion>,
    private val currentLocation: suspend () -> LatLon?,
    private val storage: PlannerStorage,
    isPremium: Flow<Boolean>,
    private val now: () -> LocalDateTime = { LocalDateTime.now(SAO_PAULO) },
) : ViewModel() {
    private val _state = MutableStateFlow(PlanUiState())
    val state: StateFlow<PlanUiState> = _state.asStateFlow()

    private var suggestJob: Job? = null
    private var planJob: Job? = null
    private var revision = 0

    /** Completes once the last form has been restored (or there was none). */
    private val formRestored = CompletableDeferred<Unit>()

    init {
        viewModelScope.launch { isPremium.collect { premium -> _state.update { it.copy(isPremium = premium) } } }
        viewModelScope.launch { storage.savedRoutes.collect { routes -> _state.update { it.copy(savedRoutes = routes) } } }
        viewModelScope.launch {
            val used = storage.searchesOn(now().toLocalDate())
            _state.update { it.copy(searchesToday = used) }
        }
        viewModelScope.launch {
            runCatching { storage.lastForm() }.getOrNull()?.let(::restore)
            formRestored.complete(Unit)
            // From here on, every change to the places or preferences is remembered.
            _state.map { it.snapshot() }.distinctUntilChanged().collect { runCatching { storage.saveForm(it) } }
        }
    }

    private fun restore(form: PlanFormSnapshot) {
        _state.update { current ->
            if (current.origin.text.isNotBlank() || current.destination.text.isNotBlank()) return@update current
            current.copy(
                // A "current location" origin is resolved again where the user is now (fillOriginIfEmpty).
                origin = form.origin?.takeIf { !form.originIsCurrentLocation }?.let { PlaceField(it.name, it) } ?: PlaceField(),
                destination = form.destination?.let { PlaceField(it.name, it) } ?: PlaceField(),
                priority = PlanPriority.entries.firstOrNull { it.apiValue == form.priority } ?: PlanPriority.ARRIVES_FIRST,
                maxTransfers = form.maxTransfers.coerceIn(0, 4),
            )
        }
    }

    private fun PlanUiState.snapshot() = PlanFormSnapshot(
        origin = origin.place?.takeIf { !origin.isCurrentLocation },
        originIsCurrentLocation = origin.isCurrentLocation,
        destination = destination.place,
        priority = priority.apiValue,
        maxTransfers = maxTransfers,
    )

    /** Clears one field. */
    fun clearField(field: PlanField) {
        suggestJob?.cancel()
        _state.update { it.with(field, PlaceField()).copy(suggestions = emptyList(), isSuggesting = false).invalidated() }
    }

    /** Clears the whole form (places and time); preferences are kept. */
    fun clearForm() {
        suggestJob?.cancel()
        _state.update {
            it.copy(origin = PlaceField(), destination = PlaceField(), departAt = null, activeField = null,
                suggestions = emptyList(), isSuggesting = false).invalidated()
        }
    }

    fun journey(id: Int): Journey? = _state.value.plan?.all?.firstOrNull { it.id == id }

    /** The view model outlives the first location fix: fill an untouched origin when the screen shows. */
    fun fillOriginIfEmpty(label: String) {
        viewModelScope.launch {
            formRestored.await()
            val origin = _state.value.origin
            if (origin.place != null || origin.text.isNotBlank()) return@launch
            val here = currentLocation() ?: return@launch
            val still = _state.value.origin
            if (still.place == null && still.text.isBlank()) select(PlanField.ORIGIN, Place(label, here.lat, here.lon), isCurrentLocation = true)
        }
    }

    fun useCurrentLocation(label: String) {
        viewModelScope.launch {
            val here = currentLocation()
            if (here == null) {
                _state.update { it.copy(locationUnavailable = true) }
            } else {
                select(PlanField.ORIGIN, Place(label, here.lat, here.lon), isCurrentLocation = true)
            }
        }
    }

    fun onFocus(field: PlanField?) {
        _state.update { if (it.activeField == field) it else it.copy(activeField = field, suggestions = emptyList()) }
    }

    fun onTextChange(field: PlanField, text: String) {
        val current = field.of(_state.value)
        // Text fields may report the unchanged text (focus changes): only a real edit drops the place.
        if (text == current.text) return
        _state.update { it.with(field, PlaceField(text)).copy(activeField = field).invalidated() }
        suggestJob?.cancel()
        if (text.trim().length < 3) {
            _state.update { it.copy(suggestions = emptyList(), isSuggesting = false) }
            return
        }
        suggestJob = viewModelScope.launch {
            delay(350)
            _state.update { it.copy(isSuggesting = true) }
            val results = runCatching { suggest(text.trim()) }.getOrDefault(emptyList())
            if (field.of(_state.value).text == text) {
                _state.update { it.copy(suggestions = results, isSuggesting = false) }
            }
        }
    }

    fun selectSuggestion(field: PlanField, suggestion: PlaceSuggestion) {
        select(field, Place(suggestion.title, suggestion.lat, suggestion.lon))
    }

    fun swap() {
        _state.update { it.copy(origin = it.destination, destination = it.origin, suggestions = emptyList()).invalidated() }
    }

    /** Choosing a departure time is Premium; returns whether the picker may open. */
    fun requestChooseTime(): Boolean {
        if (_state.value.isPremium) return true
        _state.update { it.copy(premiumPrompt = PremiumPrompt.CHOOSE_TIME) }
        return false
    }

    fun setDeparture(value: LocalDateTime?) {
        if (value != null && !_state.value.isPremium) {
            _state.update { it.copy(premiumPrompt = PremiumPrompt.CHOOSE_TIME) }
            return
        }
        _state.update { it.copy(departAt = value).invalidated() }
    }

    fun setPriority(value: PlanPriority) = _state.update { it.copy(priority = value).invalidated() }
    fun setMaxTransfers(value: Int) = _state.update { it.copy(maxTransfers = value.coerceIn(0, 4)).invalidated() }
    fun dismissLocationMessage() = _state.update { it.copy(locationUnavailable = false) }
    fun dismissPremiumPrompt() = _state.update { it.copy(premiumPrompt = null) }

    fun plan() {
        val snapshot = _state.value
        val origin = snapshot.origin.place ?: return
        val destination = snapshot.destination.place ?: return
        if (snapshot.isPlanning) return
        if (!snapshot.isPremium && snapshot.searchesToday >= PlannerLimits.FREE_DAILY_SEARCHES) {
            _state.update { it.copy(premiumPrompt = PremiumPrompt.SEARCH_LIMIT) }
            return
        }
        // "Now" is the moment the button is pressed, sent explicitly. A chosen time is Premium only.
        val pressedAt = now()
        val departure = snapshot.departAt?.takeIf { snapshot.isPremium } ?: pressedAt
        val request = ++revision
        val context = PlanContext(origin, destination, departure)
        planJob?.cancel()
        _state.update { it.copy(isPlanning = true, error = null, plan = null, context = null, activeField = null, suggestions = emptyList()) }
        planJob = viewModelScope.launch {
            try {
                val result = planTrip(origin, destination, departure, snapshot.priority.apiValue, snapshot.maxTransfers)
                // Only successful searches count towards the free limit.
                val used = storage.recordSearch(pressedAt.toLocalDate())
                if (request == revision) _state.update { it.copy(isPlanning = false, plan = result, context = context, searchesToday = used) }
                else _state.update { it.copy(searchesToday = used) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (request == revision) _state.update { it.copy(isPlanning = false, error = e.message ?: "") }
            }
        }
    }

    fun saveCurrentRoute() {
        val snapshot = _state.value
        val origin = snapshot.origin.place ?: return
        val destination = snapshot.destination.place ?: return
        if (snapshot.currentRouteIsSaved) return
        if (!snapshot.isPremium && snapshot.savedRoutes.size >= PlannerLimits.FREE_SAVED_ROUTES) {
            _state.update { it.copy(premiumPrompt = PremiumPrompt.SAVE_LIMIT) }
            return
        }
        val route = SavedRoute(UUID.randomUUID().toString(), origin, destination, snapshot.origin.isCurrentLocation)
        viewModelScope.launch { storage.setSavedRoutes(snapshot.savedRoutes + route) }
    }

    fun deleteRoute(id: String) {
        val remaining = _state.value.savedRoutes.filterNot { it.id == id }
        viewModelScope.launch { storage.setSavedRoutes(remaining) }
    }

    /** Fills the form with a saved route and searches it now. */
    fun useRoute(route: SavedRoute, currentLabel: String) {
        viewModelScope.launch {
            val origin = if (route.originIsCurrentLocation) {
                val here = currentLocation()
                if (here == null) {
                    _state.update { it.copy(locationUnavailable = true) }
                    return@launch
                }
                Place(currentLabel, here.lat, here.lon)
            } else {
                route.origin
            }
            suggestJob?.cancel()
            _state.update {
                it.copy(
                    origin = PlaceField(origin.name, origin, route.originIsCurrentLocation),
                    destination = PlaceField(route.destination.name, route.destination),
                    activeField = null,
                    suggestions = emptyList(),
                ).invalidated()
            }
            plan()
        }
    }

    private fun select(field: PlanField, place: Place, isCurrentLocation: Boolean = false) {
        suggestJob?.cancel()
        _state.update {
            it.with(field, PlaceField(place.name, place, isCurrentLocation))
                .copy(activeField = null, suggestions = emptyList(), isSuggesting = false).invalidated()
        }
    }

    /** Any change to the inputs makes shown results stale; a newer request wins. */
    private fun PlanUiState.invalidated(): PlanUiState {
        revision++
        planJob?.cancel()
        return copy(plan = null, context = null, error = null, isPlanning = false)
    }

    private fun PlanField.of(state: PlanUiState) = if (this == PlanField.ORIGIN) state.origin else state.destination

    private fun PlanUiState.with(field: PlanField, value: PlaceField) =
        if (field == PlanField.ORIGIN) copy(origin = value) else copy(destination = value)

    companion object {
        val SAO_PAULO: ZoneId = ZoneId.of("America/Sao_Paulo")
    }
}
