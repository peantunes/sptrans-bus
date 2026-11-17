package app.lolados.duesp

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import app.lolados.duesp.alerts.RailAlertNotifications
import app.lolados.duesp.alerts.RailAlertsScreen
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Directions
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import app.lolados.duesp.data.JourneyShareRepository
import app.lolados.duesp.ui.plan.SharedJourneyScreen
import app.lolados.duesp.ui.plan.canShare
import app.lolados.duesp.ui.plan.rememberJourneySharer
import kotlinx.coroutines.launch
import androidx.compose.material.icons.filled.Map
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lolados.duesp.ui.containerViewModel
import app.lolados.duesp.ui.plan.JourneyDetailScreen
import app.lolados.duesp.ui.plan.PlanScreen
import app.lolados.duesp.ui.plan.PlanViewModel
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Train
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import app.lolados.duesp.domain.Stop
import app.lolados.duesp.ui.map.MapScreen
import app.lolados.duesp.ui.search.SearchScreen
import app.lolados.duesp.ui.settings.PremiumScreen
import app.lolados.duesp.ui.settings.SettingsScreen
import app.lolados.duesp.ui.status.StatusScreen
import app.lolados.duesp.ui.stop.StopDetailScreen
import app.lolados.duesp.ui.theme.DueSPTheme
import kotlinx.serialization.json.Json

private enum class Tab(val route: String, val label: Int, val icon: ImageVector) {
    MAP("map", R.string.tab_map, Icons.Filled.Map),
    PLAN("plan", R.string.tab_plan, Icons.Filled.Directions),
    STATUS("status", R.string.tab_status, Icons.Filled.Train),
    SETTINGS("settings", R.string.tab_settings, Icons.Filled.Settings),
}

class MainActivity : ComponentActivity() {
    private val openStatusRequests = mutableIntStateOf(0)
    /** Token of a shared journey link (https://sptrans.lolados.app/j/<token>) waiting to be shown. */
    private val sharedJourneyToken = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null && intent.opensRailStatus()) openStatusRequests.intValue++
        if (savedInstanceState == null) sharedJourneyToken.value = JourneyShareRepository.token(intent.data)
        setContent {
            DueSPTheme {
                DueSPApp(openStatusRequests.intValue, sharedJourneyToken.value) { sharedJourneyToken.value = null }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.opensRailStatus()) openStatusRequests.intValue++
        JourneyShareRepository.token(intent.data)?.let { sharedJourneyToken.value = it }
    }

    /** Taps on rail alert notifications: ours (foreground) or FCM's system notification (data extras). */
    private fun Intent.opensRailStatus(): Boolean =
        getBooleanExtra(RailAlertNotifications.EXTRA_OPEN_STATUS, false) ||
            getStringExtra("type")?.startsWith("rail_status") == true
}

/** One planner view model per "plan" back stack entry, shared with the journey detail. */
@androidx.compose.runtime.Composable
private fun planViewModel(owner: androidx.lifecycle.ViewModelStoreOwner): PlanViewModel =
    containerViewModel(owner) { c ->
        PlanViewModel(
            planTrip = { origin, destination, departure, priority, maxTransfers ->
                c.transitRepository.planTrip(origin, destination, departure, priority, maxTransfers)
            },
            suggest = c.places::suggestions,
            currentLocation = c.location::currentLocation,
            storage = c.planner,
            isPremium = c.premium.hasPremium,
        )
    }

@androidx.compose.runtime.Composable
private fun DueSPApp(openStatusRequest: Int, sharedJourneyToken: String?, onSharedJourneyShown: () -> Unit) {
    val nav = rememberNavController()
    LaunchedEffect(sharedJourneyToken) {
        val token = sharedJourneyToken ?: return@LaunchedEffect
        nav.navigate("shared/$token") { launchSingleTop = true }
        onSharedJourneyShown()
    }
    LaunchedEffect(openStatusRequest) {
        if (openStatusRequest > 0) {
            nav.navigate(Tab.STATUS.route) {
                popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                launchSingleTop = true
            }
        }
    }
    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val showTabs = Tab.entries.any { it.route == currentRoute }

    val openStop: (Stop) -> Unit = { stop -> nav.navigate("stop/${Uri.encode(Json.encodeToString(stop))}") }
    val openPremium: () -> Unit = { nav.navigate("premium") }

    Scaffold(
        bottomBar = {
            if (showTabs) {
                NavigationBar {
                    Tab.entries.forEach { tab ->
                        NavigationBarItem(
                            selected = currentRoute == tab.route,
                            onClick = {
                                nav.navigate(tab.route) {
                                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(tab.icon, null) },
                            label = { Text(stringResource(tab.label)) },
                        )
                    }
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            NavHost(nav, startDestination = Tab.MAP.route) {
                composable(Tab.MAP.route) { MapScreen(onOpenStop = openStop, onOpenSearch = { nav.navigate("search") }) }
                composable(Tab.PLAN.route) { entry ->
                    PlanScreen(
                        vm = planViewModel(entry),
                        onOpenJourney = { id -> nav.navigate("plan/journey/$id") },
                        onOpenPremium = openPremium,
                    )
                }
                composable("plan/journey/{id}", arguments = listOf(navArgument("id") { type = NavType.IntType })) { entry ->
                    val parent = remember(entry) { nav.getBackStackEntry(Tab.PLAN.route) }
                    val vm = planViewModel(parent)
                    val state by vm.state.collectAsStateWithLifecycle()
                    val journey = vm.journey(entry.arguments?.getInt("id") ?: -1)
                    val sharer = rememberJourneySharer()
                    val scope = rememberCoroutineScope()
                    val serviceDay = state.context?.departure?.toLocalDate()
                    JourneyDetailScreen(
                        journey = journey,
                        originLabel = state.context?.origin?.name.orEmpty(),
                        destinationLabel = state.context?.destination?.name.orEmpty(),
                        onBack = nav::popBackStack,
                        isSharing = sharer.isCreating,
                        onShare = if (journey != null && serviceDay != null && canShare(journey)) {
                            { scope.launch { sharer.share(journey, serviceDay) } }
                        } else {
                            null
                        },
                    )
                }
                composable("shared/{token}", arguments = listOf(navArgument("token") { type = NavType.StringType })) { entry ->
                    SharedJourneyScreen(token = entry.arguments?.getString("token").orEmpty(), onBack = {
                        if (!nav.popBackStack()) nav.navigate(Tab.MAP.route)
                    })
                }
                composable(Tab.STATUS.route) { StatusScreen(onOpenPremium = openPremium, onOpenAlerts = { nav.navigate("alerts") }) }
                composable("alerts") { RailAlertsScreen(onBack = nav::popBackStack) }
                composable(Tab.SETTINGS.route) { SettingsScreen(onOpenPremium = openPremium) }
                composable("search") { SearchScreen(onBack = nav::popBackStack, onOpenStop = openStop) }
                composable("premium") { PremiumScreen(onBack = nav::popBackStack) }
                composable("stop/{stop}", arguments = listOf(navArgument("stop") { type = NavType.StringType })) { entry ->
                    val stop = Json.decodeFromString<Stop>(entry.arguments?.getString("stop").orEmpty())
                    StopDetailScreen(stop, onBack = nav::popBackStack, onOpenPremium = openPremium)
                }
            }
        }
    }
}
