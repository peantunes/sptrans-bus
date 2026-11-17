package app.lolados.duesp.alerts

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import app.lolados.duesp.BuildConfig
import app.lolados.duesp.data.api.AlertLineDto
import app.lolados.duesp.data.api.AlertUpdateRequest
import app.lolados.duesp.data.api.TransitApi
import app.lolados.duesp.domain.RailLineStatus
import app.lolados.duesp.domain.RailSource
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.tasks.await
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

private val Context.alertsStore by preferencesDataStore(name = "due_sp_alerts")

/** A Metrô/CPTM line that can be subscribed to. `id` matches iOS (`metro-1`, `cptm-11`). */
data class AlertLine(val id: String, val source: String, val number: String, val name: String) {
    fun toDto() = AlertLineDto(lineId = id, source = source, lineNumber = number, lineName = name)

    companion object {
        fun from(status: RailLineStatus): AlertLine {
            val source = if (status.source == RailSource.METRO) "metro" else "cptm"
            val id = if (status.number.isNotBlank()) "$source-${status.number.trim()}"
            else "$source-${status.name.lowercase().replace(" ", "-")}"
            return AlertLine(id, source, status.number.trim(), status.name.trim())
        }
    }
}

/**
 * Rail disruption alerts over FCM, using the same backend endpoint as iOS (`rail_alert_subscriptions.php`).
 * The device is identified by a random installation id; the FCM token is sent with every update.
 */
class RailAlertsRepository(private val context: Context, private val api: TransitApi) {
    private val installationKey = stringPreferencesKey("push_installation_id")

    /** False until `app/google-services.json` is added and the app is rebuilt. */
    val isPushConfigured: Boolean
        get() = FirebaseApp.getApps(context).isNotEmpty()

    fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun notificationsEnabled(): Boolean =
        hasNotificationPermission() && NotificationManagerCompat.from(context).areNotificationsEnabled()

    suspend fun installationId(): String {
        context.alertsStore.data.first()[installationKey]?.let { return it }
        val generated = "android-" + UUID.randomUUID().toString()
        context.alertsStore.edit { it[installationKey] = generated }
        return generated
    }

    /** Line ids currently subscribed on the server. */
    suspend fun subscribedLineIds(): Set<String> =
        api.alertState(installationId()).state.subscriptions.map { it.lineId }.toSet()

    /** Replaces the subscribed lines (action "set"). Returns the ids the server confirmed. */
    suspend fun save(lines: List<AlertLine>): Set<String> {
        val response = api.updateAlerts(buildRequest(action = "set", lines = lines, token = fcmToken()))
        context.alertsStore.edit { it[registeredKey] = "1" }
        return response.state.subscriptions.map { it.lineId }.toSet()
    }

    /**
     * Called when FCM rotates the token: refresh it on the server without touching the line list.
     * Skipped until the user has saved alerts once, so installs that never use alerts are not registered.
     */
    suspend fun syncToken(token: String) {
        if (context.alertsStore.data.first()[registeredKey] == null) return
        api.updateAlerts(buildRequest(action = "subscribe", lines = emptyList(), token = token))
    }

    private val registeredKey = stringPreferencesKey("alerts_registered")

    private suspend fun fcmToken(): String? =
        if (isPushConfigured) runCatching { FirebaseMessaging.getInstance().token.await() }.getOrNull() else null

    private suspend fun buildRequest(action: String, lines: List<AlertLine>, token: String?): AlertUpdateRequest {
        val enabled = notificationsEnabled()
        return AlertUpdateRequest(
            installationId = installationId(),
            action = action,
            fcmToken = token,
            notificationsEnabled = enabled && token != null,
            authorizationStatus = if (enabled) "authorized" else "denied",
            locale = Locale.getDefault().toLanguageTag().replace('-', '_'),
            timezone = TimeZone.getDefault().id,
            appVersion = BuildConfig.VERSION_NAME,
            buildVersion = BuildConfig.VERSION_CODE.toString(),
            lines = lines.map { it.toDto() },
        )
    }
}
