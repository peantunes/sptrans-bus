package app.lolados.duesp

import android.app.Application
import app.lolados.duesp.alerts.RailAlertNotifications
import app.lolados.duesp.alerts.RailAlertsRepository
import app.lolados.duesp.data.FavoritesRepository
import app.lolados.duesp.data.LocationProvider
import app.lolados.duesp.data.PlaceSearch
import app.lolados.duesp.data.PlannerStore
import app.lolados.duesp.data.PremiumAccess
import app.lolados.duesp.data.TransitRepository
import app.lolados.duesp.data.api.TransitApi
import org.osmdroid.config.Configuration

/** Manual dependency container (equivalent of iOS `AppDependencies`). */
class AppContainer(app: Application) {
    private val api = TransitApi(BuildConfig.API_BASE_URL)
    val transitRepository = TransitRepository(api)
    val alerts = RailAlertsRepository(app, api)
    val favorites = FavoritesRepository(app)
    val premium = PremiumAccess(app)
    val location = LocationProvider(app)
    val places = PlaceSearch(app, transitRepository)
    val planner = PlannerStore(app)
}

class DueSPApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        RailAlertNotifications.createChannel(this)
        // OpenStreetMap tile servers require an identifying user agent.
        Configuration.getInstance().userAgentValue = "DueSP-Android/${BuildConfig.VERSION_NAME}"
    }
}
