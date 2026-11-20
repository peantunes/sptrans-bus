package app.lolados.duesp.ui.map

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lolados.duesp.R
import app.lolados.duesp.data.LatLon
import app.lolados.duesp.domain.RailMapLine
import app.lolados.duesp.domain.RailSource
import app.lolados.duesp.domain.Stop
import app.lolados.duesp.domain.TransitMode
import app.lolados.duesp.ui.ErrorBox
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.icon
import app.lolados.duesp.ui.parseHexColor
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalDensity
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(onOpenStop: (Stop) -> Unit, onOpenSearch: () -> Unit) {
    val vm = containerViewModel { MapViewModel(it.transitRepository, it.location, it.favorites) }
    val state by vm.state.collectAsStateWithLifecycle()
    val favorites by vm.favorites.collectAsStateWithLifecycle()
    val railLines by vm.railLines.collectAsStateWithLifecycle()

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        vm.start()
    }
    LaunchedEffect(Unit) {
        permissionLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }

    var mapCenter by remember { mutableStateOf<LatLon?>(null) }

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.app_name)) },
            actions = {
                IconButton(onClick = onOpenSearch) { Icon(Icons.Filled.Search, stringResource(R.string.action_search)) }
            },
        )
        // osmdroid draws outside its bounds unless clipped.
        Box(Modifier.fillMaxWidth().height(300.dp).clipToBounds()) {
            StopsMap(
                center = state.center,
                recenterRequest = state.recenterRequest,
                user = state.userLocation,
                stops = state.visibleStops,
                railLines = railLines,
                onStopClick = onOpenStop,
                onCenterChanged = { mapCenter = it },
                modifier = Modifier.fillMaxSize(),
            )
            Column(
                Modifier.align(Alignment.BottomEnd).padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SmallFloatingActionButton(onClick = { mapCenter?.let(vm::searchHere) }) {
                    Icon(Icons.Filled.Refresh, stringResource(R.string.action_refresh))
                }
                SmallFloatingActionButton(onClick = vm::locateAndLoad) {
                    Icon(Icons.Filled.MyLocation, null)
                }
            }
        }
        if (state.isLoading) LinearProgressIndicator(Modifier.fillMaxWidth())

        FilterRow(selected = state.filter, onSelect = vm::setFilter)

        LazyColumn(Modifier.fillMaxSize()) {
            if (state.outsideServiceArea) {
                item {
                    Text(
                        stringResource(R.string.nearby_outside_area),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                }
            }
            if (state.usingDefaultLocation) {
                item {
                    Text(
                        stringResource(if (state.hasLocationPermission) R.string.nearby_location_unavailable else R.string.nearby_location_denied),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                }
            }
            if (favorites.isNotEmpty()) {
                item { SectionHeader(stringResource(R.string.favorites_title)) }
                items(favorites, key = { "fav-${it.id}" }) { stop ->
                    StopRow(stop, isFavorite = true, onClick = { onOpenStop(stop) })
                }
            }
            item { SectionHeader(stringResource(R.string.nearby_title)) }
            when {
                state.error != null -> item { ErrorBox(state.error, onRetry = vm::locateAndLoad) }
                !state.isLoading && state.visibleStops.isEmpty() -> item {
                    Text(stringResource(R.string.nearby_empty), Modifier.padding(16.dp))
                }
                else -> items(state.visibleStops, key = { it.id }) { stop ->
                    StopRow(stop, isFavorite = false, onClick = { onOpenStop(stop) })
                }
            }
        }
    }
}

@Composable
private fun FilterRow(selected: TransitMode?, onSelect: (TransitMode?) -> Unit) {
    val options = listOf(
        null to R.string.filter_all,
        TransitMode.BUS to R.string.filter_bus,
        TransitMode.METRO to R.string.filter_metro,
        TransitMode.TRAIN to R.string.filter_train,
    )
    LazyRow(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp),
    ) {
        items(options) { (mode, label) ->
            FilterChip(
                selected = selected == mode,
                onClick = { onSelect(mode) },
                label = { Text(stringResource(label)) },
                leadingIcon = mode?.let { m -> { Icon(m.icon(), null) } },
            )
        }
    }
}

@Composable
fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, top = 12.dp, bottom = 4.dp),
    )
}

@Composable
fun StopRow(stop: Stop, isFavorite: Boolean, onClick: () -> Unit) {
    ListItem(
        modifier = Modifier.clickable(onClick = onClick),
        leadingContent = { Icon(if (isFavorite) Icons.Filled.Star else stop.mode.icon(), null) },
        headlineContent = { Text(stop.name) },
        supportingContent = {
            val routes = stop.routeList.joinToString(" · ")
            if (routes.isNotEmpty()) Text(routes, maxLines = 1, style = MaterialTheme.typography.bodySmall)
        },
        trailingContent = stop.distanceMeters?.let { d -> { Text(stringResource(R.string.distance_meters, d)) } },
    )
    HorizontalDivider()
}

@Composable
private fun StopsMap(
    center: LatLon,
    recenterRequest: Int,
    user: LatLon?,
    stops: List<Stop>,
    railLines: List<RailMapLine>,
    onStopClick: (Stop) -> Unit,
    onCenterChanged: (LatLon) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val density = LocalDensity.current.density
    val currentOnStopClick by rememberUpdatedState(onStopClick)
    val mapView = remember {
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
            controller.setZoom(16.0)
        }
    }
    // Built once per network (not on every recomposition): lines with a dark outline, then the stations.
    val railOverlays = remember(railLines) {
        val icons = HashMap<String, android.graphics.drawable.Drawable>()
        val lines = railLines.flatMap { line ->
            val points = line.stations.map { GeoPoint(it.lat, it.lon) }
            val color = parseHexColor(line.colorHex, androidx.compose.ui.graphics.Color.Gray).toArgb()
            listOf(
                Polyline(mapView).apply {
                    setPoints(points)
                    outlinePaint.color = android.graphics.Color.argb(90, 0, 0, 0)
                    outlinePaint.strokeWidth = 7 * density
                    outlinePaint.strokeCap = android.graphics.Paint.Cap.ROUND
                    outlinePaint.strokeJoin = android.graphics.Paint.Join.ROUND
                    setOnClickListener { _, _, _ -> false }
                },
                Polyline(mapView).apply {
                    setPoints(points)
                    outlinePaint.color = color
                    outlinePaint.strokeWidth = 4.5f * density
                    outlinePaint.strokeCap = android.graphics.Paint.Cap.ROUND
                    outlinePaint.strokeJoin = android.graphics.Paint.Join.ROUND
                    setOnClickListener { _, _, _ -> false }
                },
            )
        }
        val stations = railLines.flatMap { line ->
            val icon = icons.getOrPut(line.colorHex) { stationIcon(context, line.colorHex, density) }
            val routes = when (line.source) {
                RailSource.METRO -> "METRÔ ${line.id}"
                RailSource.CPTM -> "CPTM L" + line.id.removePrefix("L").padStart(2, '0')
            }
            line.stations.map { station ->
                Marker(mapView).apply {
                    position = GeoPoint(station.lat, station.lon)
                    title = station.name
                    this.icon = icon
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                    setInfoWindow(null)
                    setOnMarkerClickListener { _, _ ->
                        if (station.stopId > 0) {
                            currentOnStopClick(Stop(station.stopId, station.name, null, station.lat, station.lon, routes))
                        }
                        true
                    }
                }
            }
        }
        lines + stations
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

    LaunchedEffect(center, recenterRequest) { mapView.controller.animateTo(GeoPoint(center.lat, center.lon)) }

    AndroidView(
        factory = {
            mapView.addMapListener(object : org.osmdroid.events.MapListener {
                override fun onScroll(event: org.osmdroid.events.ScrollEvent?): Boolean {
                    mapView.mapCenter.let { onCenterChanged(LatLon(it.latitude, it.longitude)) }
                    return false
                }
                override fun onZoom(event: org.osmdroid.events.ZoomEvent?): Boolean = false
            })
            mapView
        },
        update = { map ->
            map.overlays.clear()
            map.overlays.addAll(railOverlays)
            // OpenStreetMap tile usage policy: visible attribution on every map.
            map.overlays.add(org.osmdroid.views.overlay.CopyrightOverlay(context))
            stops.forEach { stop ->
                map.overlays.add(
                    Marker(map).apply {
                        position = GeoPoint(stop.lat, stop.lon)
                        title = stop.name
                        icon = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_stop_marker)
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                        setOnMarkerClickListener { _, _ -> currentOnStopClick(stop); true }
                    },
                )
            }
            user?.let {
                map.overlays.add(
                    Marker(map).apply {
                        position = GeoPoint(it.lat, it.lon)
                        icon = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_user_location)
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                        setInfoWindow(null)
                    },
                )
            }
            map.invalidate()
        },
        modifier = modifier,
    )
}

/** Station marker: a circle in the line colour with a white ring and a white train glyph. */
private fun stationIcon(context: android.content.Context, colorHex: String, density: Float): android.graphics.drawable.Drawable {
    val size = (22 * density).toInt()
    val bitmap = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
    val radius = size / 2f
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(radius, radius, radius, paint)
    paint.color = parseHexColor(colorHex, androidx.compose.ui.graphics.Color.Gray).toArgb()
    canvas.drawCircle(radius, radius, radius - 2 * density, paint)
    androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_train_glyph)?.let { glyph ->
        val inset = (5.5f * density).toInt()
        glyph.setBounds(inset, inset, size - inset, size - inset)
        glyph.draw(canvas)
    }
    return android.graphics.drawable.BitmapDrawable(context.resources, bitmap)
}
