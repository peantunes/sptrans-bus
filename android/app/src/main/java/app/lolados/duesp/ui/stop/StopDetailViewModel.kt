package app.lolados.duesp.ui.stop

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.data.FavoritesRepository
import app.lolados.duesp.data.PremiumAccess
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.domain.Arrival
import app.lolados.duesp.domain.ArrivalCursor
import app.lolados.duesp.domain.Stop
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

data class StopDetailUiState(
    val arrivals: List<Arrival> = emptyList(),
    val isLoading: Boolean = true,
    val isLoadingPage: Boolean = false,
    val error: String? = null,
    /** Reference date/time in São Paulo ("yyyy-MM-dd", "HH:mm:ss"). */
    val referenceDate: String = "",
    val referenceTime: String = "",
    val isCustomTime: Boolean = false,
    val hasMoreNext: Boolean = true,
    val hasMorePrevious: Boolean = true,
)

class StopDetailViewModel(
    val stop: Stop,
    private val repository: TransitRepository,
    private val favoritesRepository: FavoritesRepository,
    premium: PremiumAccess,
) : ViewModel() {

    private var revision = 0
    private val _state = MutableStateFlow(StopDetailUiState())
    val state: StateFlow<StopDetailUiState> = _state.asStateFlow()

    val isFavorite: StateFlow<Boolean> = favoritesRepository.favorites
        .map { list -> list.any { it.id == stop.id } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    val hasHistoryAccess: StateFlow<Boolean> =
        premium.hasArrivalsHistoryAccess.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    init {
        reload()
    }

    fun toggleFavorite() = viewModelScope.launch { favoritesRepository.toggle(stop) }

    /** Reload from "now" in São Paulo. */
    fun reload() = loadFrom(LocalDateTime.now(SAO_PAULO), custom = false)

    /** Premium: arrivals from a custom date/time. */
    fun loadFrom(dateTime: LocalDateTime, custom: Boolean = true) {
        val request = ++revision
        val date = dateTime.format(DateTimeFormatter.ISO_LOCAL_DATE)
        val time = dateTime.format(TIME_FORMAT)
        _state.update {
            it.copy(isLoading = true, isLoadingPage = false, error = null, referenceDate = date, referenceTime = time, isCustomTime = custom)
        }
        viewModelScope.launch {
            runCatching { repository.arrivals(stop.id, PAGE_SIZE, date = date.takeIf { custom }, time = time.takeIf { custom }) }
                .onSuccess { list ->
                    if (request != revision) return@launch
                    _state.update {
                        it.copy(
                            arrivals = list.sortedForDisplay(),
                            isLoading = false,
                            hasMoreNext = list.size >= PAGE_SIZE || list.any { it.liveFromOlhoVivo },
                            hasMorePrevious = true,
                        )
                    }
                }
                .onFailure { e -> if (request == revision) _state.update { it.copy(isLoading = false, error = e.message) } }
        }
    }

    /** Premium: load the next or previous page. */
    fun loadPage(previous: Boolean) {
        val current = _state.value
        if (current.isLoading || current.isLoadingPage) return
        val request = revision
        val cursor = if (previous) ArrivalCursor.previous(current.arrivals) else ArrivalCursor.next(current.arrivals)
        cursor ?: return
        _state.update { it.copy(isLoadingPage = true) }
        viewModelScope.launch {
            runCatching {
                repository.arrivals(
                    stop.id, PAGE_SIZE,
                    date = current.referenceDate, time = current.referenceTime,
                    cursorDate = cursor.date, cursorTime = cursor.time,
                    direction = if (previous) "previous" else "next",
                )
            }.onSuccess { page ->
                if (request != revision) return@launch
                _state.update { s ->
                    val merged = (if (previous) page + s.arrivals else s.arrivals + page)
                        .distinctBy { it.identity }
                        .sortedForDisplay()
                    s.copy(
                        arrivals = merged,
                        isLoadingPage = false,
                        hasMoreNext = if (previous) s.hasMoreNext else page.size >= PAGE_SIZE,
                        hasMorePrevious = if (previous) page.size >= PAGE_SIZE else s.hasMorePrevious,
                    )
                }
            }.onFailure { if (request == revision) _state.update { it.copy(isLoadingPage = false) } }
        }
    }

    private fun List<Arrival>.sortedForDisplay() =
        sortedWith(compareBy<Arrival> { it.scheduledTimestamp ?: Long.MAX_VALUE }.thenBy { it.arrivalTime })

    companion object {
        const val PAGE_SIZE = 20
        val SAO_PAULO: ZoneId = ZoneId.of("America/Sao_Paulo")
        private val TIME_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")
    }
}
