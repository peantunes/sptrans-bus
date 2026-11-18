package app.lolados.duesp.ui.stop

import android.graphics.Bitmap
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lolados.duesp.R
import app.lolados.duesp.domain.TripRoute
import app.lolados.duesp.domain.TripStop
import app.lolados.duesp.ui.ErrorBox
import app.lolados.duesp.ui.LoadingBox
import app.lolados.duesp.ui.RouteBadge
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.map.MapDot
import app.lolados.duesp.ui.map.MapLine
import app.lolados.duesp.ui.map.RouteMapContent
import app.lolados.duesp.ui.map.RouteMapDialog
import app.lolados.duesp.ui.map.StaticRouteMap
import app.lolados.duesp.ui.parseHexColor
import org.osmdroid.util.GeoPoint

/** The route of the vehicle tapped at a stop: every stop before and after it, with a map. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TripDetailScreen(selection: TripSelection, onBack: () -> Unit) {
    val vm = containerViewModel(key = "trip-${selection.tripId}-${selection.stopSequence}") {
        TripDetailViewModel(selection, it.transitRepository)
    }
    val state by vm.state.collectAsStateWithLifecycle()
    val lineColor = parseHexColor(selection.routeColor, MaterialTheme.colorScheme.primary)
    val lineText = parseHexColor(selection.routeTextColor, Color.White)

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.trip_title)) },
            navigationIcon = {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
            },
        )
        val route = state.route
        when {
            state.isLoading -> LoadingBox()
            route == null -> ErrorBox(state.error, onRetry = vm::load)
            else -> TripContent(selection, route, state.currentIndex, state.times, lineColor, lineText)
        }
    }
}

@Composable
private fun TripContent(
    selection: TripSelection,
    route: TripRoute,
    currentIndex: Int,
    times: List<String>,
    lineColor: Color,
    lineText: Color,
) {
    val content = remember(route, lineColor) { tripMapContent(route, currentIndex, lineColor) }
    val preview = remember(route) { mutableStateOf<Bitmap?>(null) }
    var focusStop by remember(route) { mutableStateOf<Int?>(null) }
    var showMap by remember(route) { mutableStateOf(false) }
    val listState = rememberLazyListState()
    // Header, map and section title come before the stops; open with the current stop in view.
    val headerItems = 3
    LaunchedEffect(route) {
        if (currentIndex > 1) listState.scrollToItem(headerItems + currentIndex - 1)
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        state = listState,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        item { TripHeader(selection, route, lineColor, lineText) }
        item {
            Card(Modifier.fillMaxWidth().padding(top = 14.dp), shape = RoundedCornerShape(18.dp)) {
                StaticRouteMap(
                    content, preview,
                    Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(18.dp)),
                    onClick = {
                        focusStop = null
                        showMap = true
                    },
                )
            }
        }
        item {
            Row(Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.trip_stops_title), style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text("${route.stops.size}", style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        itemsIndexed(route.stops, key = { index, stop -> "${stop.sequence}-$index" }) { index, stop ->
            StopTimelineRow(
                stop = stop,
                number = index + 1,
                time = times.getOrNull(index).orEmpty(),
                isFirst = index == 0,
                isLast = index == route.stops.lastIndex,
                isCurrent = index == currentIndex,
                isPast = currentIndex >= 0 && index < currentIndex,
                lineColor = lineColor,
                onClick = {
                    focusStop = index
                    showMap = true
                },
            )
        }
    }

    if (showMap) {
        val stop = focusStop?.let { route.stops.getOrNull(it) }
        // The tapped stop gets its own highlighted dot, on top of the route.
        val shown = remember(content, stop) {
            if (stop == null) content
            else content.copy(dots = content.dots + MapDot(GeoPoint(stop.lat, stop.lon), android.graphics.Color.BLACK, highlighted = true))
        }
        RouteMapDialog(
            title = stop?.name ?: selection.routeShortName,
            content = shown,
            focus = stop?.let { listOf(GeoPoint(it.lat, it.lon)) },
            onDismiss = { showMap = false },
        )
    }
}

@Composable
private fun TripHeader(selection: TripSelection, route: TripRoute, lineColor: Color, lineText: Color) {
    Card(
        Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                RouteBadge(selection.routeShortName, lineColor, lineText)
                Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                    Text(
                        selection.headsign.ifBlank { route.headsign },
                        style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
                        maxLines = 2, overflow = TextOverflow.Ellipsis,
                    )
                    if (selection.routeLongName.isNotBlank()) {
                        Text(selection.routeLongName, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("${route.stops.size}", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.trip_stops_label), style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Schedule, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(displayTime(selection.arrivalTime), Modifier.padding(start = 6.dp),
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                selection.frequencyMinutes?.let { minutes ->
                    Spacer(Modifier.width(14.dp))
                    Text(stringResource(R.string.trip_every_minutes, minutes), style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun StopTimelineRow(
    stop: TripStop,
    number: Int,
    time: String,
    isFirst: Boolean,
    isLast: Boolean,
    isCurrent: Boolean,
    isPast: Boolean,
    lineColor: Color,
    onClick: () -> Unit,
) {
    val faded = lineColor.copy(alpha = 0.35f)
    val textColor = if (isPast) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
    Row(
        Modifier.fillMaxWidth().height(IntrinsicSize.Min).clip(RoundedCornerShape(10.dp)).clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.width(28.dp).fillMaxHeight().drawBehind {
                val x = size.width / 2
                val y = size.height / 2
                val stroke = 3.dp.toPx()
                if (!isFirst) drawLine(if (isPast || isCurrent) faded else lineColor, Offset(x, 0f), Offset(x, y), stroke)
                if (!isLast) drawLine(if (isPast) faded else lineColor, Offset(x, y), Offset(x, size.height), stroke)
                val radius = (if (isCurrent) 8 else 5).dp.toPx()
                drawCircle(Color.White, radius + 2.dp.toPx(), Offset(x, y))
                drawCircle(if (isPast) faded else lineColor, radius, Offset(x, y))
            },
        )
        Column(Modifier.weight(1f).padding(start = 10.dp, top = 10.dp, bottom = 10.dp)) {
            Text(
                stop.name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal,
                color = textColor,
                maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            Text(
                if (isCurrent) stringResource(R.string.trip_you_are_here) else stringResource(R.string.trip_stop_number, number),
                style = MaterialTheme.typography.bodySmall,
                color = if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Normal,
            )
        }
        if (time.isNotEmpty()) {
            Text(time, Modifier.padding(start = 8.dp, end = 4.dp), style = MaterialTheme.typography.labelLarge,
                color = textColor, fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal)
        }
    }
}

/** The route (shape, or the stops joined when there is none) in the line colour; dots at both ends and here. */
private fun tripMapContent(route: TripRoute, currentIndex: Int, lineColor: Color): RouteMapContent {
    val color = lineColor.toArgb()
    val stopPoints = route.stops.map { GeoPoint(it.lat, it.lon) }
    val path = route.shape.map { (lat, lon) -> GeoPoint(lat, lon) }.takeIf { it.size >= 2 } ?: stopPoints
    val dots = buildList {
        stopPoints.firstOrNull()?.let { add(MapDot(it, color)) }
        stopPoints.lastOrNull()?.takeIf { stopPoints.size > 1 }?.let { add(MapDot(it, color)) }
        stopPoints.getOrNull(currentIndex)?.let { add(MapDot(it, color, highlighted = true)) }
    }
    return RouteMapContent(listOf(MapLine(path, color)), dots)
}

private fun displayTime(gtfs: String): String {
    val parts = gtfs.split(":")
    val hour = parts.getOrNull(0)?.toIntOrNull() ?: return gtfs
    return "%02d:%s".format(hour % 24, parts.getOrNull(1) ?: "00")
}
