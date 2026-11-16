package app.lolados.duesp.ui.plan

import android.graphics.DashPathEffect
import android.graphics.Paint
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import app.lolados.duesp.R
import app.lolados.duesp.domain.Journey
import app.lolados.duesp.domain.JourneyStep
import app.lolados.duesp.domain.Place
import app.lolados.duesp.ui.parseHexColor
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JourneyDetailScreen(journey: Journey?, originLabel: String, destinationLabel: String, onBack: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.plan_journey_title)) },
            navigationIcon = {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
            },
        )
        if (journey == null) {
            // The plan was replaced (e.g. process death); nothing to show.
            Text(stringResource(R.string.plan_journey_gone), Modifier.padding(16.dp))
            return
        }
        var focus by remember(journey) { mutableStateOf<List<GeoPoint>?>(null) }
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item { JourneySummaryCard(journey, originLabel, destinationLabel) }
            item {
                Text(stringResource(R.string.plan_route_overview), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
            item {
                PlanCard {
                    RouteMap(journey, focus, Modifier.fillMaxWidth().height(230.dp).clip(RoundedCornerShape(14.dp)))
                }
            }
            itemsIndexed(journey.steps) { _, step ->
                when (step) {
                    is JourneyStep.Walk -> WalkBlock(step) { focus = listOfNotNull(step.from.geo(), step.to.geo()) }
                    is JourneyStep.Ride -> RideLegCard(step.leg) { focus = step.leg.allStops.mapNotNull { it.place.geo() } }
                }
            }
            item {
                Text(stringResource(R.string.plan_walking_paths_note), style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

private fun Place.geo(): GeoPoint? = if (hasLocation) GeoPoint(lat!!, lon!!) else null

/** Rides through their stops in the line colour (with a dark outline), walks dashed. */
@Composable
private fun RouteMap(journey: Journey, focus: List<GeoPoint>?, modifier: Modifier) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val fallback = MaterialTheme.colorScheme.primary
    val walkColor = MaterialTheme.colorScheme.onSurfaceVariant.toArgb()
    val mapView = remember {
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
        }
    }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            mapView.onDetach()
        }
    }

    AndroidView(factory = { mapView }, modifier = modifier, update = { map ->
        map.overlays.clear()
        val all = mutableListOf<GeoPoint>()
        journey.steps.forEach { step ->
            when (step) {
                is JourneyStep.Walk -> {
                    val points = listOfNotNull(step.from.geo(), step.to.geo())
                    if (points.size == 2) {
                        all += points
                        map.overlays.add(Polyline(map).apply {
                            setPoints(points)
                            outlinePaint.color = walkColor
                            outlinePaint.strokeWidth = 3 * density
                            outlinePaint.strokeCap = Paint.Cap.ROUND
                            outlinePaint.pathEffect = DashPathEffect(floatArrayOf(6 * density, 6 * density), 0f)
                        })
                    }
                }
                is JourneyStep.Ride -> {
                    val points = step.leg.allStops.mapNotNull { it.place.geo() }
                    if (points.size >= 2) {
                        all += points
                        val color = parseHexColor(step.leg.route?.color, fallback).toArgb()
                        // Dark outline so light colours (e.g. Metrô L4 yellow) stand out on the map.
                        map.overlays.add(Polyline(map).apply {
                            setPoints(points)
                            outlinePaint.color = android.graphics.Color.argb(115, 0, 0, 0)
                            outlinePaint.strokeWidth = 8 * density
                            outlinePaint.strokeCap = Paint.Cap.ROUND
                        })
                        map.overlays.add(Polyline(map).apply {
                            setPoints(points)
                            outlinePaint.color = color
                            outlinePaint.strokeWidth = 5 * density
                            outlinePaint.strokeCap = Paint.Cap.ROUND
                        })
                    }
                }
            }
        }
        all.firstOrNull()?.let { start ->
            map.overlays.add(Marker(map).apply { position = start; setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM) })
        }
        all.lastOrNull()?.takeIf { all.size > 1 }?.let { end ->
            map.overlays.add(Marker(map).apply { position = end; setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM) })
        }
        val target = focus?.takeIf { it.isNotEmpty() } ?: all
        if (target.isNotEmpty()) {
            val zoom = {
                if (target.size == 1) {
                    map.controller.setZoom(17.0)
                    map.controller.setCenter(target.first())
                } else {
                    map.zoomToBoundingBox(BoundingBox.fromGeoPointsSafe(target), false, (36 * density).toInt())
                }
            }
            if (map.width > 0 && map.height > 0) zoom() else map.addOnFirstLayoutListener { _, _, _, _, _ -> zoom() }
        }
        map.invalidate()
    })
}
