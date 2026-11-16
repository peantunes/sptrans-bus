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
import app.lolados.duesp.domain.Stop
import app.lolados.duesp.domain.TransitMode
import app.lolados.duesp.ui.ErrorBox
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.icon
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(onOpenStop: (Stop) -> Unit, onOpenSearch: () -> Unit) {
    val vm = containerViewModel { MapViewModel(it.transitRepository, it.location, it.favorites) }
    val state by vm.state.collectAsStateWithLifecycle()
    val favorites by vm.favorites.collectAsStateWithLifecycle()

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
                user = state.userLocation,
                stops = state.visibleStops,
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
    user: LatLon?,
    stops: List<Stop>,
    onStopClick: (Stop) -> Unit,
    onCenterChanged: (LatLon) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val mapView = remember {
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
            controller.setZoom(16.0)
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

    LaunchedEffect(center) { mapView.controller.animateTo(GeoPoint(center.lat, center.lon)) }

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
            stops.forEach { stop ->
                map.overlays.add(
                    Marker(map).apply {
                        position = GeoPoint(stop.lat, stop.lon)
                        title = stop.name
                        icon = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_stop_marker)
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                        setOnMarkerClickListener { _, _ -> onStopClick(stop); true }
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
