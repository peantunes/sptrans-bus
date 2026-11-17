package app.lolados.duesp.ui.stop

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.AssistChip
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lolados.duesp.R
import app.lolados.duesp.domain.Arrival
import app.lolados.duesp.domain.Stop
import app.lolados.duesp.ui.ErrorBox
import app.lolados.duesp.ui.LoadingBox
import app.lolados.duesp.ui.RouteBadge
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.parseHexColor
import java.time.LocalDateTime

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StopDetailScreen(stop: Stop, onBack: () -> Unit, onOpenPremium: () -> Unit) {
    val vm = containerViewModel(key = "stop-${stop.id}") {
        StopDetailViewModel(stop, it.transitRepository, it.favorites, it.premium)
    }
    val state by vm.state.collectAsStateWithLifecycle()
    val isFavorite by vm.isFavorite.collectAsStateWithLifecycle()
    val hasHistory by vm.hasHistoryAccess.collectAsStateWithLifecycle()
    val context = LocalContext.current

    fun pickDateTime() {
        val now = LocalDateTime.now(StopDetailViewModel.SAO_PAULO)
        DatePickerDialog(context, { _, y, m, d ->
            TimePickerDialog(context, { _, h, min ->
                vm.loadFrom(LocalDateTime.of(y, m + 1, d, h, min))
            }, now.hour, now.minute, true).show()
        }, now.year, now.monthValue - 1, now.dayOfMonth).show()
    }

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stop.name, maxLines = 1) },
            navigationIcon = {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
            },
            actions = {
                IconButton(onClick = vm::reload) { Icon(Icons.Filled.Refresh, stringResource(R.string.action_refresh)) }
                IconButton(onClick = { vm.toggleFavorite() }) {
                    Icon(
                        if (isFavorite) Icons.Filled.Star else Icons.Filled.StarBorder,
                        stringResource(if (isFavorite) R.string.action_unfavorite else R.string.action_favorite),
                    )
                }
            },
        )

        LazyColumn(Modifier.fillMaxSize()) {
            item {
                Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                    stop.description?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
                    if (stop.routeList.isNotEmpty()) {
                        Text(stop.routeList.joinToString(" · "), style = MaterialTheme.typography.bodySmall)
                    }
                    Row(
                        Modifier.fillMaxWidth().padding(top = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        AssistChip(
                            onClick = { if (hasHistory) pickDateTime() else onOpenPremium() },
                            label = { Text(stringResource(R.string.arrivals_pick_time)) },
                            leadingIcon = { Icon(if (hasHistory) Icons.Filled.Schedule else Icons.Filled.Lock, null) },
                        )
                        if (state.isCustomTime) {
                            AssistChip(onClick = vm::reload, label = { Text(stringResource(R.string.arrivals_reset_time)) })
                        }
                    }
                    if (state.isCustomTime) {
                        Text(
                            stringResource(R.string.arrivals_reference, "${state.referenceDate} ${state.referenceTime.take(5)}"),
                            style = MaterialTheme.typography.labelMedium,
                        )
                    }
                }
            }

            item {
                Text(
                    stringResource(R.string.arrivals_title),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(start = 16.dp, top = 8.dp),
                )
            }

            when {
                state.isLoading -> item { LoadingBox() }
                state.error != null -> item { ErrorBox(state.error, onRetry = vm::reload) }
                state.arrivals.isEmpty() -> item { Text(stringResource(R.string.arrivals_empty), Modifier.padding(16.dp)) }
                else -> {
                    if (state.hasMorePrevious) {
                        item { PageButton(R.string.arrivals_previous, hasHistory, state.isLoadingPage) { if (hasHistory) vm.loadPage(true) else onOpenPremium() } }
                    }
                    items(state.arrivals, key = { it.identity }) { ArrivalRow(it, showCountdown = !state.isCustomTime) }
                    if (state.hasMoreNext) {
                        item { PageButton(R.string.arrivals_next, hasHistory, state.isLoadingPage) { if (hasHistory) vm.loadPage(false) else onOpenPremium() } }
                    }
                }
            }
        }
    }
}

@Composable
private fun PageButton(label: Int, unlocked: Boolean, loading: Boolean, onClick: () -> Unit) {
    TextButton(onClick = onClick, enabled = !loading, modifier = Modifier.fillMaxWidth()) {
        if (!unlocked) {
            Icon(Icons.Filled.Lock, null)
            Spacer(Modifier.width(6.dp))
        }
        Text(stringResource(label))
    }
}

@Composable
private fun ArrivalRow(arrival: Arrival, showCountdown: Boolean) {
    val bg = parseHexColor(arrival.routeColor, MaterialTheme.colorScheme.primary)
    val fg = parseHexColor(arrival.routeTextColor, Color.White)
    ListItem(
        leadingContent = { RouteBadge(arrival.routeShortName, bg, fg) },
        headlineContent = { Text(arrival.headsign.ifBlank { arrival.routeLongName }, maxLines = 1) },
        supportingContent = { Text(arrival.displayTime, style = MaterialTheme.typography.bodySmall) },
        trailingContent = {
            if (showCountdown) {
                val minutes = arrival.minutesUntil(System.currentTimeMillis() / 1000)
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        when {
                            minutes < 0 -> stringResource(R.string.arrivals_departed)
                            minutes == 0 -> stringResource(R.string.arrivals_now)
                            else -> stringResource(R.string.arrivals_minutes, minutes)
                        },
                        fontWeight = if (minutes < 0) FontWeight.Normal else FontWeight.Bold,
                        color = if (minutes < 0) MaterialTheme.colorScheme.onSurfaceVariant else Color.Unspecified,
                    )
                }
            }
        },
    )
    HorizontalDivider()
}
