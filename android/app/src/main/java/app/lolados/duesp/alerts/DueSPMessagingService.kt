package app.lolados.duesp.alerts

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import app.lolados.duesp.DueSPApplication
import app.lolados.duesp.MainActivity
import app.lolados.duesp.R
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Receives rail disruption alerts from FCM.
 * In background, FCM shows the notification itself (channel from the manifest meta-data);
 * in foreground, [onMessageReceived] is called and we post it ourselves.
 */
class DueSPMessagingService : FirebaseMessagingService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNewToken(token: String) {
        val repository = (application as DueSPApplication).container.alerts
        scope.launch { runCatching { repository.syncToken(token) } }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.notification?.title ?: message.data["lineName"] ?: return
        val body = message.notification?.body ?: message.data["status"].orEmpty()
        RailAlertNotifications.show(this, title, body, message.data)
    }
}

object RailAlertNotifications {
    const val CHANNEL_ID = "rail_alerts"
    const val EXTRA_OPEN_STATUS = "open_status"

    fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.alerts_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = context.getString(R.string.alerts_channel_description) }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun show(context: Context, title: String, body: String, data: Map<String, String>) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_STATUS, true)
        }
        val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val tag = listOfNotNull(data["source"], data["lineNumber"]).joinToString("-").ifEmpty { "rail" }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .apply { runCatching { setColor(Color.parseColor(data["color"] ?: "")) } }
            .build()

        runCatching { NotificationManagerCompat.from(context).notify(tag, 0, notification) }
    }
}
