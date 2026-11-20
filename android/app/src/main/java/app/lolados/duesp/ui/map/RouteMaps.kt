package app.lolados.duesp.ui.map

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
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Map
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import app.lolados.duesp.R
import java.util.concurrent.Executors
import org.osmdroid.tileprovider.MapTileProviderBasic
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.drawing.MapSnapshot
import org.osmdroid.views.overlay.CopyrightOverlay
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.Polyline

/** A line drawn on a route map, in an ARGB colour. */
data class MapLine(
    val points: List<GeoPoint>,
    val color: Int,
    val widthDp: Float = 5f,
    val dashed: Boolean = false,
    /** Dark outline under the line, so light colours (e.g. Metrô L4 yellow) stand out. */
    val outlined: Boolean = true,
)

/** A dot (stop, start, end) drawn on a route map. [highlighted] dots are bigger, for the current stop. */
data class MapDot(val point: GeoPoint, val color: Int, val highlighted: Boolean = false)

/** Everything a route map shows; the same description feeds the picture and the interactive map. */
data class RouteMapContent(val lines: List<MapLine>, val dots: List<MapDot>) {
    val allPoints: List<GeoPoint> get() = lines.flatMap { it.points } + dots.map { it.point }
}

private fun RouteMapContent.overlays(density: Float): List<Overlay> {
    val overlays = mutableListOf<Overlay>()
    lines.filter { it.points.size >= 2 }.forEach { line ->
        if (line.outlined) {
            overlays += Polyline().apply {
                setPoints(line.points)
                outlinePaint.color = android.graphics.Color.argb(115, 0, 0, 0)
                outlinePaint.strokeWidth = (line.widthDp + 3) * density
                outlinePaint.strokeCap = Paint.Cap.ROUND
                outlinePaint.strokeJoin = Paint.Join.ROUND
            }
        }
        overlays += Polyline().apply {
            setPoints(line.points)
            outlinePaint.color = line.color
            outlinePaint.strokeWidth = line.widthDp * density
            outlinePaint.strokeCap = Paint.Cap.ROUND
            outlinePaint.strokeJoin = Paint.Join.ROUND
            if (line.dashed) outlinePaint.pathEffect = DashPathEffect(floatArrayOf(6 * density, 6 * density), 0f)
        }
    }
    if (dots.isNotEmpty()) overlays += DotsOverlay(dots, density)
    return overlays
}

/** Dots with a white ring; plain overlay, so it works without a live MapView (pictures). */
private class DotsOverlay(private val dots: List<MapDot>, private val density: Float) : Overlay() {
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE }
    private val point = Point()

    override fun draw(canvas: Canvas, projection: Projection) {
        // Highlighted dots last, so they sit on top.
        (dots.filterNot { it.highlighted } + dots.filter { it.highlighted }).forEach { dot ->
            projection.toPixels(dot.point, point)
            val radius = if (dot.highlighted) 7.5f else 4.5f
            fill.color = dot.color
            canvas.drawCircle(point.x.toFloat(), point.y.toFloat(), (radius + 2.5f) * density, ring)
            canvas.drawCircle(point.x.toFloat(), point.y.toFloat(), radius * density, fill)
        }
    }

    override fun draw(canvas: Canvas, mapView: MapView, shadow: Boolean) {
        if (!shadow) draw(canvas, mapView.projection)
    }
}

/**
 * A still picture of [content] on the map; tap to open the interactive map. The picture is kept in
 * [picture] (state owned by the screen), so scrolling a list never re-renders it or holds a live MapView.
 * Everything the render uses (tile provider, thread) is released when this leaves the composition.
 */
@Composable
fun StaticRouteMap(content: RouteMapContent, picture: MutableState<Bitmap?>, modifier: Modifier, onClick: () -> Unit) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    BoxWithConstraints(
        modifier
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable(onClickLabel = stringResource(R.string.plan_map_open), onClick = onClick),
    ) {
        val width = constraints.maxWidth
        val height = constraints.maxHeight
        DisposableEffect(content, width, height) {
            val points = content.allPoints
            if (picture.value != null || points.isEmpty() || width <= 0 || height <= 0) return@DisposableEffect onDispose { }
            val provider = MapTileProviderBasic(context.applicationContext, TileSourceFactory.MAPNIK)
            val pad = (28 * density).toInt()
            val box = BoundingBox.fromGeoPointsSafe(points)
            val zoom = MapView.getTileSystem()
                .getBoundingBoxZoom(box, (width - 2 * pad).coerceAtLeast(1), (height - 2 * pad).coerceAtLeast(1))
                .takeIf { it.isFinite() }?.coerceIn(3.0, 17.0) ?: 15.0
            val projection = Projection(zoom, width, height, box.centerWithDateLine, 0f, true, true, 0, 0)
            val main = Handler(Looper.getMainLooper())
            var disposed = false
            val snapshot = MapSnapshot({ shot ->
                if (shot.status == MapSnapshot.Status.CANVAS_OK) {
                    val bitmap = shot.bitmap?.copy(Bitmap.Config.ARGB_8888, false)
                    if (bitmap != null) main.post { if (!disposed) picture.value = bitmap }
                }
            }, MapSnapshot.INCLUDE_FLAG_UPTODATE or MapSnapshot.INCLUDE_FLAG_EXPIRED or MapSnapshot.INCLUDE_FLAG_SCALED,
                provider, content.overlays(density), projection)
            val worker = Executors.newSingleThreadExecutor()
            worker.execute(snapshot)
            onDispose {
                disposed = true
                main.removeCallbacksAndMessages(null)
                snapshot.onDetach()
                provider.detach()
                worker.shutdownNow()
            }
        }
        val bitmap = picture.value
        if (bitmap != null) {
            Image(bitmap.asImageBitmap(), contentDescription = stringResource(R.string.plan_route_overview),
                contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            CircularProgressIndicator(Modifier.size(28.dp).align(Alignment.Center), strokeWidth = 2.5.dp)
        }
        // OpenStreetMap tile usage policy: visible attribution on every map.
        Text(
            stringResource(R.string.map_attribution),
            Modifier.align(Alignment.BottomStart)
                .padding(6.dp)
                .background(androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f), RoundedCornerShape(4.dp))
                .padding(horizontal = 4.dp, vertical = 1.dp),
            style = MaterialTheme.typography.labelSmall,
            color = androidx.compose.ui.graphics.Color(0xFF333333),
        )
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

/** The interactive map, full screen, zoomed to [focus] (one point or several) or to the whole content. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RouteMapDialog(title: String, content: RouteMapContent, focus: List<GeoPoint>?, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.surface) {
            Column(Modifier.fillMaxSize()) {
                TopAppBar(
                    title = { Text(title, maxLines = 1) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) { Icon(Icons.Filled.Close, stringResource(R.string.action_close)) }
                    },
                )
                // osmdroid draws past its bounds; clip so the map can't cover the top bar.
                Box(Modifier.fillMaxSize().clipToBounds()) {
                    InteractiveRouteMap(content, focus, Modifier.fillMaxSize().clipToBounds())
                }
            }
        }
    }
}

@Composable
private fun InteractiveRouteMap(content: RouteMapContent, focus: List<GeoPoint>?, modifier: Modifier) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
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
        map.overlays.addAll(content.overlays(density))
        map.overlays.add(CopyrightOverlay(context))
        val target = focus?.takeIf { it.isNotEmpty() } ?: content.allPoints
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
