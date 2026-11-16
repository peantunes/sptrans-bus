package app.lolados.duesp.data

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.coroutines.resume
import kotlin.math.roundToInt

data class PlaceSuggestion(
    val title: String,
    val subtitle: String?,
    val lat: Double,
    val lon: Double,
    val isStop: Boolean = false,
)

/**
 * Addresses and places for the planner's origin/destination: the system Geocoder
 * (limited to Greater São Paulo) plus the API's own stop search, which knows stations.
 */
class PlaceSearch(private val context: Context, private val transit: TransitRepository) {

    suspend fun suggestions(query: String): List<PlaceSuggestion> = coroutineScope {
        val places = async { geocode(query) }
        val stops = async {
            runCatching { transit.searchStops(query) }.getOrDefault(emptyList()).take(4).map {
                PlaceSuggestion(it.name, it.description ?: it.routeList.take(3).joinToString(", ").ifBlank { null }, it.lat, it.lon, isStop = true)
            }
        }
        (places.await() + stops.await())
            .distinctBy { "${it.title.lowercase()}|${(it.lat * 1000).roundToInt()}|${(it.lon * 1000).roundToInt()}" }
            .take(8)
    }

    private suspend fun geocode(query: String): List<PlaceSuggestion> {
        if (!Geocoder.isPresent()) return emptyList()
        val geocoder = Geocoder(context, Locale.forLanguageTag("pt-BR"))
        val addresses: List<Address> = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                suspendCancellableCoroutine { cont ->
                    geocoder.getFromLocationName(query, MAX_RESULTS, SOUTH, WEST, NORTH, EAST, object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) { if (cont.isActive) cont.resume(addresses) }
                        override fun onError(errorMessage: String?) { if (cont.isActive) cont.resume(emptyList()) }
                    })
                }
            } else {
                withContext(Dispatchers.IO) {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocationName(query, MAX_RESULTS, SOUTH, WEST, NORTH, EAST).orEmpty()
                }
            }
        }.getOrDefault(emptyList())
        return addresses.filter { it.hasLatitude() && it.hasLongitude() }.map { address ->
            val line = address.getAddressLine(0)
            val feature = address.featureName?.takeUnless { it.all(Char::isDigit) }
            val street = listOfNotNull(address.thoroughfare, address.subThoroughfare).joinToString(", ").ifBlank { null }
            // "Av. Paulista 1000" is an address search: name the street, not a business at that number.
            val title = if (query.any(Char::isDigit)) street ?: feature else feature ?: street
            PlaceSuggestion(
                title = title ?: line ?: query,
                subtitle = line?.takeUnless { it == feature || it == street },
                lat = address.latitude,
                lon = address.longitude,
            )
        }
    }

    private companion object {
        const val MAX_RESULTS = 6
        // Greater São Paulo bounding box.
        const val SOUTH = -24.10
        const val WEST = -47.20
        const val NORTH = -23.20
        const val EAST = -46.20
    }
}
