package app.lolados.duesp.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import app.lolados.duesp.domain.Stop
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json

internal val Context.dataStore by preferencesDataStore(name = "due_sp_prefs")

/** Favorites (equivalent of iOS `FavoriteStopModel`). */
class FavoritesRepository(private val context: Context) {
    private val key = stringPreferencesKey("favorite_stops_v1")
    private val json = Json { ignoreUnknownKeys = true }

    val favorites: Flow<List<Stop>> = context.dataStore.data.map { prefs ->
        prefs[key]?.let { runCatching { json.decodeFromString<List<Stop>>(it) }.getOrNull() }.orEmpty()
    }

    suspend fun toggle(stop: Stop) {
        context.dataStore.edit { prefs ->
            val current = prefs[key]?.let { runCatching { json.decodeFromString<List<Stop>>(it) }.getOrNull() }.orEmpty()
            val updated = if (current.any { it.id == stop.id }) {
                current.filterNot { it.id == stop.id }
            } else {
                current + stop.copy(distanceMeters = null)
            }
            prefs[key] = json.encodeToString(updated)
        }
    }
}

/**
 * Premium entitlement gate, mirroring iOS `PremiumAccessGate`.
 * Free: map, nearby, search, arrivals now, rail status, disruption alerts.
 * Premium (`app.lolados.data.weekly` / `app.lolados.data.yearly`): unlimited journey planning,
 * custom date/time and previous/next arrivals pages.
 *
 * The flag is a cache of the Google Play entitlement kept up to date by [PremiumBilling].
 */
class PremiumAccess(private val context: Context) {
    private val key = booleanPreferencesKey("premium_subscription_is_active_v1")

    val hasPremium: Flow<Boolean> = context.dataStore.data.map { it[key] ?: false }
    val hasArrivalsHistoryAccess: Flow<Boolean> get() = hasPremium

    suspend fun setPremium(active: Boolean) {
        context.dataStore.edit { it[key] = active }
    }

    companion object {
        const val PRODUCT_WEEKLY = "app.lolados.data.weekly"
        const val PRODUCT_YEARLY = "app.lolados.data.yearly"
    }
}
