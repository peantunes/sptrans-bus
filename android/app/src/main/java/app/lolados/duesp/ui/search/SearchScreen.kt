package app.lolados.duesp.ui.search

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.R
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.domain.Stop
import app.lolados.duesp.ui.ErrorBox
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.map.StopRow
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class SearchUiState(
    val query: String = "",
    val results: List<Stop> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val searched: Boolean = false,
)

class SearchViewModel(private val repository: TransitRepository) : ViewModel() {
    private val _state = MutableStateFlow(SearchUiState())
    val state: StateFlow<SearchUiState> = _state.asStateFlow()
    private var job: Job? = null

    fun onQueryChange(query: String) {
        _state.update { it.copy(query = query) }
        job?.cancel()
        if (query.trim().length < 3) {
            _state.update { it.copy(results = emptyList(), isLoading = false, searched = false, error = null) }
            return
        }
        job = viewModelScope.launch {
            delay(350)
            search()
        }
    }

    fun search() {
        val query = _state.value.query.trim()
        if (query.length < 3) return
        job?.cancel()
        job = viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            runCatching { repository.searchStops(query) }
                .onSuccess { r -> _state.update { it.copy(results = r, isLoading = false, searched = true) } }
                .onFailure { e -> _state.update { it.copy(isLoading = false, error = e.message) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(onBack: () -> Unit, onOpenStop: (Stop) -> Unit) {
    val vm = containerViewModel { SearchViewModel(it.transitRepository) }
    val state by vm.state.collectAsStateWithLifecycle()
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.action_search)) },
            navigationIcon = {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
            },
        )
        OutlinedTextField(
            value = state.query,
            onValueChange = vm::onQueryChange,
            placeholder = { Text(stringResource(R.string.search_hint)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).focusRequester(focus),
        )
        if (state.isLoading) LinearProgressIndicator(Modifier.fillMaxWidth().padding(top = 8.dp))
        when {
            state.error != null -> ErrorBox(state.error, onRetry = vm::search)
            state.query.isNotEmpty() && state.query.trim().length < 3 ->
                Text(stringResource(R.string.search_min_chars), Modifier.padding(16.dp))
            state.searched && state.results.isEmpty() ->
                Text(stringResource(R.string.search_empty), Modifier.padding(16.dp))
            else -> LazyColumn(Modifier.fillMaxSize()) {
                items(state.results, key = { it.id }) { stop ->
                    StopRow(stop, isFavorite = false, onClick = { onOpenStop(stop) })
                }
            }
        }
    }
}
