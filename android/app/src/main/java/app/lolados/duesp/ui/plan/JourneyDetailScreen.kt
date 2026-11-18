package app.lolados.duesp.ui.plan

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Point
import android.os.Handler
import android.os.Looper
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import app.lolados.duesp.R
import app.lolados.duesp.domain.Journey
import app.lolados.duesp.domain.JourneyStep
import app.lolados.duesp.domain.Place
import app.lolados.duesp.ui.parseHexColor
import java.util.concurrent.Executors
import org.osmdroid.tileprovider.MapTileProviderBasic
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.drawing.MapSnapshot
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.Polyline

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JourneyDetailScreen(
    journey: Journey?,
    originLabel: String,
    destinationLabel: String,
    onBack: () -> Unit,
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
            item {
                Text(stringResource(R.string.plan_route_overview), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            }
            item {
                PlanCard {
                    RouteMapPreview(
                        journey, preview,
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
        }
        if (showMap) {
            RouteMapDialog(journey, mapFocus, onDismiss = { showMap = false })
        }
    }
}

private fun Place.geo(): GeoPoint? = if (hasLocation) GeoPoint(lat!!, lon!!) else null

/** Lines of the journey: rides through their stops in the line colour (with a dark outline), walks dashed. */
private fun routeOverlays(journey: Journey, density: Float, fallback: Int, walkColor: Int): Pair<List<Overlay>, List<GeoPoint>> {
    val overlays = mutableListOf<Overlay>()
    val all = mutableListOf<GeoPoint>()
    journey.steps.forEach { step ->
        when (step) {
            is JourneyStep.Walk -> {
                val points = listOfNotNull(step.from.geo(), step.to.geo())
                if (points.size == 2) {
                    all += points
                    overlays += Polyline().apply {
                        setPoints(points)
                        outlinePaint.color = walkColor
                        outlinePaint.strokeWidth = 3 * density
                        outlinePaint.strokeCap = Paint.Cap.ROUND
                        outlinePaint.pathEffect = DashPathEffect(floatArrayOf(6 * density, 6 * density), 0f)
                    }
                }
            }
            is JourneyStep.Ride -> {
                val points = step.leg.allStops.mapNotNull { it.place.geo() }
                if (points.size >= 2) {
                    all += points
                    val color = parseHexColor(step.leg.route?.color, androidx.compose.ui.graphics.Color(fallback)).toArgb()
                    // Dark outline so light colours (e.g. Metrô L4 yellow) stand out on the map.
                    overlays += Polyline().apply {
                        setPoints(points)
                        outlinePaint.color = android.graphics.Color.argb(115, 0, 0, 0)
                        outlinePaint.strokeWidth = 8 * density
                        outlinePaint.strokeCap = Paint.Cap.ROUND
                    }
                    overlays += Polyline().apply {
                        setPoints(points)
                        outlinePaint.color = color
                        outlinePaint.strokeWidth = 5 * density
                        outlinePaint.strokeCap = Paint.Cap.ROUND
                    }
                }
            }
        }
    }
    return overlays to all
}

/** Start and end dots for the picture (Marker needs a live MapView). */
private class EndpointsOverlay(private val points: List<GeoPoint>, private val density: Float, private val color: Int) : Overlay() {
    override fun draw(canvas: Canvas, projection: Projection) {
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = android.graphics.Color.WHITE }
        val p = Point()
        points.forEach { geo ->
            projection.toPixels(geo, p)
            canvas.drawCircle(p.x.toFloat(), p.y.toFloat(), 8 * density, ring)
            canvas.drawCircle(p.x.toFloat(), p.y.toFloat(), 5.5f * density, fill)
        }
    }

    override fun draw(canvas: Canvas, mapView: MapView, shadow: Boolean) {
        if (!shadow) draw(canvas, mapView.projection)
    }
}

/** A still picture of the route on the map; tap to open the interactive map. */
@Composable
private fun RouteMapPreview(journey: Journey, picture: MutableState<Bitmap?>, modifier: Modifier, onClick: () -> Unit) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val fallback = MaterialTheme.colorScheme.primary.toArgb()
    val walkColor = MaterialTheme.colorScheme.onSurfaceVariant.toArgb()
    BoxWithConstraints(
        modifier
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable(onClickLabel = stringResource(R.string.plan_map_open), onClick = onClick),
    ) {
        val width = constraints.maxWidth
        val height = constraints.maxHeight
        DisposableEffect(journey, width, height) {
            val (lines, points) = routeOverlays(journey, density, fallback, walkColor)
            if (picture.value != null || points.isEmpty() || width <= 0 || height <= 0) return@DisposableEffect onDispose { }
            val endpoints = listOfNotNull(points.first(), points.last().takeIf { points.size > 1 })
            val overlays = lines + EndpointsOverlay(endpoints, density, fallback)
            val provider = MapTileProviderBasic(context.applicationContext, TileSourceFactory.MAPNIK)
            val pad = (28 * density).toInt()
            val box = BoundingBox.fromGeoPointsSafe(points)
            val zoom = MapView.getTileSystem()
                .getBoundingBoxZoom(box, (width - 2 * pad).coerceAtLeast(1), (height - 2 * pad).coerceAtLeast(1))
                .coerceIn(3.0, 17.0)
            val projection = Projection(zoom, width, height, box.centerWithDateLine, 0f, true, true, 0, 0)
            val main = Handler(Looper.getMainLooper())
            val snapshot = MapSnapshot({ shot ->
                if (shot.status == MapSnapshot.Status.CANVAS_OK) {
                    val bitmap = shot.bitmap?.copy(Bitmap.Config.ARGB_8888, false)
                    if (bitmap != null) main.post { picture.value = bitmap }
                }
            }, MapSnapshot.INCLUDE_FLAG_UPTODATE or MapSnapshot.INCLUDE_FLAG_EXPIRED or MapSnapshot.INCLUDE_FLAG_SCALED,
                provider, overlays, projection)
            val worker = Executors.newSingleThreadExecutor()
            worker.execute(snapshot)
            onDispose {
                snapshot.onDetach()
                provider.detach()
                worker.shutdown()
            }
        }
        val bitmap = picture.value
        if (bitmap != null) {
            Image(bitmap.asImageBitmap(), contentDescription = stringResource(R.string.plan_route_overview),
                contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            CircularProgressIndicator(Modifier.size(28.dp).align(Alignment.Center), strokeWidth = 2.5.dp)
        }
        Surface(
            Modifier.align(Alignment.BottomEnd).padding(10.dp),
            shape = RoundedCornerShape(50),
            color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
            shadowElevation = 2.dp,
        ) {
            Row(Modifier.padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Map, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                Text(stringResource(R.string.plan_map_open), Modifier.padding(start = 6.dp),
                    style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

/** The interactive map, full screen, optionally zoomed to one step. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RouteMapDialog(journey: Journey, focus: List<GeoPoint>?, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.surface) {
            Column(Modifier.fillMaxSize()) {
                TopAppBar(
                    title = { Text(stringResource(R.string.plan_map_title)) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, stringResource(R.string.action_close)) }
                    },
                )
                // osmdroid draws past its bounds; clip so the map can't cover the top bar.
                Box(Modifier.fillMaxSize().clipToBounds()) {
                    RouteMap(journey, focus, Modifier.fillMaxSize().clipToBounds())
                }
            }
        }
    }
}

@Composable
private fun RouteMap(journey: Journey, focus: List<GeoPoint>?, modifier: Modifier) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val fallback = MaterialTheme.colorScheme.primary.toArgb()
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
        mapView.onResume()
        onDispose {
            lifecycle.removeObserver(observer)
            mapView.onPause()
            mapView.onDetach()
        }
    }

    AndroidView(factory = { mapView }, modifier = modifier, update = { map ->
        map.overlays.clear()
        val (lines, all) = routeOverlays(journey, density, fallback, walkColor)
        map.overlays.addAll(lines)
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
