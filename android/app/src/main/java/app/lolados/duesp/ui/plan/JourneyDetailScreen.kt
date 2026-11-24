package app.lolados.duesp.ui.plan

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.lolados.duesp.R
import app.lolados.duesp.domain.Journey
import app.lolados.duesp.domain.JourneyStep
import app.lolados.duesp.domain.Place
import app.lolados.duesp.ui.map.MapDot
import app.lolados.duesp.ui.map.MapLine
import app.lolados.duesp.ui.map.RouteMapContent
import app.lolados.duesp.ui.map.RouteMapDialog
import app.lolados.duesp.ui.map.StaticRouteMap
import app.lolados.duesp.ui.OfficialSource
import app.lolados.duesp.ui.SourceFooter
import app.lolados.duesp.ui.parseHexColor
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import app.lolados.duesp.domain.Arrival
import app.lolados.duesp.domain.ArrivalCursor
import app.lolados.duesp.domain.RideLeg
import app.lolados.duesp.domain.TransitMode
import app.lolados.duesp.ui.appContainer
import java.time.Instant
import java.time.LocalDate
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import org.osmdroid.util.GeoPoint

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JourneyDetailScreen(
    journey: Journey?,
    originLabel: String,
    destinationLabel: String,
    onBack: () -> Unit,
    serviceDay: LocalDate? = null,
    isSharing: Boolean = false,
    onShare: (() -> Unit)? = null,
) {
    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.plan_journey_title)) },
            navigationIcon = {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
            },
            actions = {
                if (onShare != null) {
                    IconButton(onClick = onShare, enabled = !isSharing) {
                        if (isSharing) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        else Icon(Icons.Filled.Share, stringResource(R.string.plan_share_title))
                    }
                }
            },
        )
        if (journey == null) {
            // The plan was replaced (e.g. process death); nothing to show.
            Text(stringResource(R.string.plan_journey_gone), Modifier.padding(16.dp))
            return
        }
        // The list only holds a picture of the map; the interactive map opens full screen, outside the list,
        // so scrolling never creates or tears down a live MapView.
        val fallback = MaterialTheme.colorScheme.primary
        val walkColor = MaterialTheme.colorScheme.onSurfaceVariant
        val content = remember(journey, fallback, walkColor) { journeyMapContent(journey, fallback, walkColor) }
        val prediction = boardingPrediction(journey.rides.firstOrNull(), serviceDay)
        val preview = remember(journey) { mutableStateOf<Bitmap?>(null) }
        var mapFocus by remember(journey) { mutableStateOf<List<GeoPoint>?>(null) }
        var showMap by remember(journey) { mutableStateOf(false) }
        fun openMap(focus: List<GeoPoint>?) {
            mapFocus = focus
            showMap = true
        }
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item { JourneySummaryCard(journey, originLabel, destinationLabel) }
            if (prediction != null) {
                item {
                    PlanCard {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(stringResource(R.string.arrivals_olho_vivo_live), style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.primary)
                            Text(stringResource(R.string.plan_live_boarding, prediction.routeShortName, prediction.headsign, prediction.displayTime))
                        }
                    }
                }
            }
            item {
                Text(stringResource(R.string.plan_route_overview), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
            item {
                PlanCard {
                    StaticRouteMap(
                        content, preview,
                        Modifier.fillMaxWidth().height(230.dp).clip(RoundedCornerShape(14.dp)),
                        onClick = { openMap(null) },
                    )
                }
            }
            itemsIndexed(journey.steps) { _, step ->
                when (step) {
                    is JourneyStep.Walk -> WalkBlock(step) { openMap(listOfNotNull(step.from.geo(), step.to.geo())) }
                    is JourneyStep.Ride -> RideLegCard(step.leg) { openMap(step.leg.allStops.mapNotNull { it.place.geo() }) }
                }
            }
            item {
                Text(stringResource(R.string.plan_walking_paths_note), style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            item { SourceFooter(listOf(OfficialSource.SPTRANS)) }
        }
        if (showMap) {
            RouteMapDialog(stringResource(R.string.plan_map_title), content, mapFocus, onDismiss = { showMap = false })
        }
    }
}

@Composable
private fun boardingPrediction(leg: RideLeg?, serviceDay: LocalDate?): Arrival? {
    val stopId = leg?.board?.id ?: return null
    val seconds = leg.board.time?.let(ArrivalCursor::gtfsSeconds) ?: return null
    if (leg.mode != TransitMode.BUS || serviceDay == null || leg.tripId.isNullOrBlank()) return null
    val departure = serviceDay.atStartOfDay(PlanViewModel.SAO_PAULO).toEpochSecond() + seconds
    val repository = appContainer().transitRepository
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val result by produceState<Arrival?>(null, leg, departure, lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            value = null
            while (departure - Instant.now().epochSecond in 0..3600) {
                value = try {
                    repository.arrivals(stopId, 40).firstOrNull {
                        it.liveFromOlhoVivo && it.tripId == leg.tripId && it.minutesUntil(Instant.now().epochSecond) in 0..60
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (_: Exception) {
                    null
                }
                delay(30_000)
            }
            value = null
        }
    }
    return result
}

private fun Place.geo(): GeoPoint? = if (hasLocation) GeoPoint(lat!!, lon!!) else null

/** Rides through their stops in the line colour, walks dashed, dots at the start and the end. */
private fun journeyMapContent(journey: Journey, fallback: Color, walkColor: Color): RouteMapContent {
    val lines = mutableListOf<MapLine>()
    journey.steps.forEach { step ->
        when (step) {
            is JourneyStep.Walk -> {
                val points = listOfNotNull(step.from.geo(), step.to.geo())
                if (points.size == 2) lines += MapLine(points, walkColor.toArgb(), widthDp = 3f, dashed = true, outlined = false)
            }
            is JourneyStep.Ride -> {
                val points = step.leg.allStops.mapNotNull { it.place.geo() }
                if (points.size >= 2) lines += MapLine(points, parseHexColor(step.leg.route?.color, fallback).toArgb())
            }
        }
    }
    val all = lines.flatMap { it.points }
    val dotColor = fallback.toArgb()
    val dots = listOfNotNull(all.firstOrNull(), all.lastOrNull()?.takeIf { all.size > 1 })
        .map { MapDot(it, dotColor, highlighted = true) }
    return RouteMapContent(lines, dots)
}
