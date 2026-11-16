package app.lolados.duesp.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import app.lolados.duesp.domain.PlanFormSnapshot
import app.lolados.duesp.domain.SavedRoute
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import java.time.LocalDate

/** Saved planner routes and the daily search count (free tier limit). */
interface PlannerStorage {
    val savedRoutes: Flow<List<SavedRoute>>
    suspend fun setSavedRoutes(routes: List<SavedRoute>)
    suspend fun searchesOn(day: LocalDate): Int
    /** Counts one search on [day] and returns the new total for that day. */
    suspend fun recordSearch(day: LocalDate): Int
    suspend fun lastForm(): PlanFormSnapshot?
    suspend fun saveForm(form: PlanFormSnapshot)
}

class PlannerStore(private val context: Context) : PlannerStorage {
    private val routesKey = stringPreferencesKey("planner_saved_routes_v1")
    private val dayKey = stringPreferencesKey("planner_search_day_v1")
    private val countKey = intPreferencesKey("planner_search_count_v1")
    private val formKey = stringPreferencesKey("planner_last_form_v1")
    private val json = Json { ignoreUnknownKeys = true }

    override val savedRoutes: Flow<List<SavedRoute>> = context.dataStore.data.map { prefs ->
        prefs[routesKey]?.let { runCatching { json.decodeFromString<List<SavedRoute>>(it) }.getOrNull() }.orEmpty()
    }

    override suspend fun setSavedRoutes(routes: List<SavedRoute>) {
        context.dataStore.edit { it[routesKey] = json.encodeToString(routes) }
    }

    override suspend fun searchesOn(day: LocalDate): Int {
        val prefs = context.dataStore.data.first()
        return if (prefs[dayKey] == day.toString()) prefs[countKey] ?: 0 else 0
    }

    override suspend fun lastForm(): PlanFormSnapshot? =
        context.dataStore.data.first()[formKey]?.let { runCatching { json.decodeFromString<PlanFormSnapshot>(it) }.getOrNull() }

    override suspend fun saveForm(form: PlanFormSnapshot) {
        context.dataStore.edit { it[formKey] = json.encodeToString(form) }
    }

    override suspend fun recordSearch(day: LocalDate): Int {
        var total = 0
        context.dataStore.edit { prefs ->
            total = if (prefs[dayKey] == day.toString()) (prefs[countKey] ?: 0) + 1 else 1
            prefs[dayKey] = day.toString()
            prefs[countKey] = total
        }
        return total
    }
}
