package app.lolados.duesp.ui.status

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.R
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.domain.RailLineStatus
import app.lolados.duesp.domain.RailNetworkStatus
import app.lolados.duesp.ui.ErrorBox
import app.lolados.duesp.ui.LoadingBox
import app.lolados.duesp.ui.OfficialSource
import app.lolados.duesp.ui.SourceFooter
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.map.SectionHeader
import app.lolados.duesp.ui.parseHexColor
import app.lolados.duesp.ui.railLineColor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class StatusUiState(
    val status: RailNetworkStatus? = null,
    val isLoading: Boolean = true,
    val error: String? = null,
)

class StatusViewModel(private val repository: TransitRepository) : ViewModel() {
    private val _state = MutableStateFlow(StatusUiState())
    val state: StateFlow<StatusUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            runCatching { repository.railStatus() }
                .onSuccess { s -> _state.update { it.copy(status = s, isLoading = false) } }
                .onFailure { e -> _state.update { it.copy(isLoading = false, error = e.message) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatusScreen(onOpenAlerts: () -> Unit) {
    val vm = containerViewModel { StatusViewModel(it.transitRepository) }
    val state by vm.state.collectAsStateWithLifecycle()

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.status_title)) },
            actions = { IconButton(onClick = vm::load) { Icon(Icons.Filled.Refresh, stringResource(R.string.action_refresh)) } },
        )
        PullToRefreshBox(isRefreshing = state.isLoading && state.status != null, onRefresh = vm::load) {
            LazyColumn(Modifier.fillMaxSize()) {
                val status = state.status
                when {
                    status == null && state.isLoading -> item { LoadingBox() }
                    status == null -> item { ErrorBox(state.error, onRetry = vm::load) }
                    else -> {
                        status.generatedAt?.let {
                            item {
                                Text(
                                    stringResource(R.string.status_updated_at, it),
                                    style = MaterialTheme.typography.labelMedium,
                                    modifier = Modifier.padding(horizontal = 16.dp),
                                )
                            }
                        }
                        item {
                            ListItem(
                                modifier = Modifier.clickable(onClick = onOpenAlerts),
                                leadingContent = { Icon(Icons.Filled.NotificationsActive, null) },
                                headlineContent = { Text(stringResource(R.string.status_alerts)) },
                                supportingContent = { Text(stringResource(R.string.status_alerts_subtitle)) },
                            )
                        }
                        item { SectionHeader(stringResource(R.string.status_metro)) }
                        if (!status.metroAvailable) item { Unavailable() }
                        items(status.metro, key = { "m-${it.number}" }) { LineRow(it) }
                        item { SectionHeader(stringResource(R.string.status_cptm)) }
                        if (!status.cptmAvailable) item { Unavailable() }
                        items(status.cptm, key = { "c-${it.number}" }) { LineRow(it) }
                        item { SourceFooter(listOf(OfficialSource.METRO, OfficialSource.CPTM)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun Unavailable() {
    Text(stringResource(R.string.status_unavailable), Modifier.padding(horizontal = 16.dp))
}

@Composable
private fun LineRow(line: RailLineStatus) {
    ListItem(
        leadingContent = {
            Box(
                Modifier.size(36.dp).background(railLineColor(line.number), CircleShape),
                contentAlignment = androidx.compose.ui.Alignment.Center,
            ) { Text(line.number, color = Color.White, style = MaterialTheme.typography.labelLarge) }
        },
        headlineContent = { Text(stringResource(R.string.status_line_format, line.number, line.name)) },
        supportingContent = {
            Text(line.status, color = parseHexColor(line.statusColor, MaterialTheme.colorScheme.onSurfaceVariant).darkenIfTooLight())
        },
    )
    HorizontalDivider()
}

/** The API sends bright status colors (e.g. #00E000) that are hard to read on light backgrounds. */
private fun Color.darkenIfTooLight(): Color =
    if (red * 0.299f + green * 0.587f + blue * 0.114f > 0.45f) copy(red = red * 0.65f, green = green * 0.65f, blue = blue * 0.65f) else this
