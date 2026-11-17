package app.lolados.duesp.alerts

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.lolados.duesp.R
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.ui.ErrorBox
import app.lolados.duesp.ui.LoadingBox
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.map.SectionHeader
import app.lolados.duesp.ui.railLineColor
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class RailAlertsUiState(
    val lines: List<AlertLine> = emptyList(),
    val selected: Set<String> = emptySet(),
    val isLoading: Boolean = true,
    val isSaving: Boolean = false,
    val error: String? = null,
    val saved: Boolean = false,
    val pushConfigured: Boolean = true,
)

class RailAlertsViewModel(
    private val transit: TransitRepository,
    private val alerts: RailAlertsRepository,
) : ViewModel() {
    private val _state = MutableStateFlow(RailAlertsUiState(pushConfigured = alerts.isPushConfigured))
    val state: StateFlow<RailAlertsUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            runCatching {
                val status = transit.railStatus()
                val lines = (status.metro + status.cptm).map(AlertLine::from).distinctBy { it.id }
                val subscribed = runCatching { alerts.subscribedLineIds() }.getOrDefault(emptySet())
                lines to subscribed.intersect(lines.map { it.id }.toSet())
            }.onSuccess { (lines, selected) ->
                _state.update { it.copy(lines = lines, selected = selected, isLoading = false) }
            }.onFailure { e ->
                _state.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun toggle(id: String) = _state.update {
        it.copy(selected = if (id in it.selected) it.selected - id else it.selected + id, saved = false)
    }

    fun toggleAll() = _state.update {
        val all = it.lines.map { l -> l.id }.toSet()
        it.copy(selected = if (it.selected == all) emptySet() else all, saved = false)
    }

    fun save() {
        val current = _state.value
        _state.update { it.copy(isSaving = true, error = null, saved = false) }
        viewModelScope.launch {
            runCatching { alerts.save(current.lines.filter { it.id in current.selected }) }
                .onSuccess { confirmed -> _state.update { it.copy(selected = confirmed, isSaving = false, saved = true) } }
                .onFailure { e -> _state.update { it.copy(isSaving = false, error = e.message) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RailAlertsScreen(onBack: () -> Unit) {
    val vm = containerViewModel { RailAlertsViewModel(it.transitRepository, it.alerts) }
    val state by vm.state.collectAsStateWithLifecycle()

    // Ask for the Android 13+ notification permission before saving; save either way so the server knows the state.
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { vm.save() }
    val onSave = {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && state.selected.isNotEmpty()) {
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            vm.save()
        }
    }

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.status_alerts)) },
            navigationIcon = {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
            },
            actions = {
                if (state.lines.isNotEmpty()) {
                    TextButton(onClick = vm::toggleAll) { Text(stringResource(R.string.alerts_select_all)) }
                }
            },
        )

        if (!state.pushConfigured) {
            Text(
                stringResource(R.string.alerts_not_configured),
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(16.dp),
            )
        }

        Text(
            stringResource(R.string.alerts_description),
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        )

        when {
            state.isLoading -> LoadingBox()
            state.lines.isEmpty() -> ErrorBox(state.error, onRetry = vm::load)
            else -> {
                LazyColumn(Modifier.weight(1f)) {
                    val grouped = state.lines.groupBy { it.source }
                    listOf("metro" to R.string.status_metro, "cptm" to R.string.status_cptm).forEach { (source, label) ->
                        val lines = grouped[source].orEmpty()
                        if (lines.isNotEmpty()) {
                            item { SectionHeader(stringResource(label)) }
                            items(lines, key = { it.id }) { line ->
                                AlertLineRow(line, checked = line.id in state.selected, onToggle = { vm.toggle(line.id) })
                            }
                        }
                    }
                }
                Column(Modifier.fillMaxWidth().padding(16.dp)) {
                    state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    if (state.saved) Text(stringResource(R.string.alerts_saved), color = MaterialTheme.colorScheme.primary)
                    Button(
                        onClick = onSave,
                        enabled = !state.isSaving && state.pushConfigured,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(stringResource(R.string.alerts_save, state.selected.size))
                    }
                }
            }
        }
    }
}

@Composable
private fun AlertLineRow(line: AlertLine, checked: Boolean, onToggle: () -> Unit) {
    ListItem(
        modifier = Modifier.clickable(onClick = onToggle),
        leadingContent = {
            Box(Modifier.size(32.dp).background(railLineColor(line.number), CircleShape), contentAlignment = Alignment.Center) {
                Text(line.number, color = Color.White, style = MaterialTheme.typography.labelMedium)
            }
        },
        headlineContent = { Text(stringResource(R.string.status_line_format, line.number, line.name)) },
        trailingContent = { Checkbox(checked = checked, onCheckedChange = { onToggle() }) },
    )
    HorizontalDivider()
}
