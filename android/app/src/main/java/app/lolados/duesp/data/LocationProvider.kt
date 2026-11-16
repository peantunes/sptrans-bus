package app.lolados.duesp.data

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull

data class LatLon(val lat: Double, val lon: Double)

class LocationProvider(private val context: Context) {
    private val client = LocationServices.getFusedLocationProviderClient(context)

    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    suspend fun currentLocation(): LatLon? {
        if (!hasPermission()) return null
        // A cold GPS can take a long time (and Play Services tasks may never complete without a fix),
        // so cap the whole lookup and let the caller fall back to the default location.
        return runCatching {
            withTimeoutOrNull(8_000) {
                val location = withTimeoutOrNull(6_000) {
                    client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, CancellationTokenSource().token).await()
                } ?: client.lastLocation.await()
                location?.let { LatLon(it.latitude, it.longitude) }
            }
        }.getOrNull()
    }

    companion object {
        /** Praça da Sé, used when location is unavailable. */
        val DEFAULT = LatLon(-23.5505, -46.6333)
    }
}
