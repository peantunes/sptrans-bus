package app.lolados.duesp.data

import android.net.Uri
import app.lolados.duesp.data.api.ApiException
import app.lolados.duesp.data.api.ShareLeg
import app.lolados.duesp.data.api.ShareRequest
import app.lolados.duesp.data.api.TransitApi
import app.lolados.duesp.domain.Journey
import java.time.LocalDate

/** A journey someone shared, ready for the detail screen. */
data class SharedJourney(val token: String, val url: String, val from: String, val to: String, val state: String, val journey: Journey)

class JourneyShareException(val notFound: Boolean) : Exception()

/**
 * Shared journey links: https://sptrans.lolados.app/j/<token> (server: inc/JourneyShare.class.php).
 * The app sends references only (trip, stops, time); the server rebuilds and stores the journey, so a
 * link cannot be edited into something else. Origin and destination are never sent.
 */
class JourneyShareRepository(private val api: TransitApi, private val mapper: TripPlanMapper = TripPlanMapper()) {

    suspend fun create(journey: Journey, serviceDay: LocalDate): String {
        val request = request(journey, serviceDay) ?: throw JourneyShareException(notFound = false)
        return runCatching { api.createShare(request).url }.getOrElse { throw JourneyShareException(notFound = false) }
    }

    suspend fun load(token: String): SharedJourney {
        val response = try {
            api.sharedJourney(token)
        } catch (e: ApiException) {
            throw JourneyShareException(notFound = e.message?.contains("404") == true)
        } catch (e: Exception) {
            throw JourneyShareException(notFound = false)
        }
        val journey = mapper.mapShared(response.journey, response.from, response.to) ?: throw JourneyShareException(notFound = true)
        return SharedJourney(response.token, response.url, response.from, response.to, response.state, journey)
    }

    companion object {
        const val HOST = "sptrans.lolados.app"
        private val TOKEN = Regex("^[A-Za-z0-9]{12}$")

        /** The token of a shared journey link, or null for any other URL. */
        fun token(uri: Uri?): String? = token(uri?.toString())

        fun token(url: String?): String? {
            val uri = runCatching { java.net.URI(url ?: return null) }.getOrNull() ?: return null
            if (uri.scheme != "https" || uri.host?.lowercase() != HOST || uri.rawQuery != null) return null
            val parts = uri.path.orEmpty().split('/').filter { it.isNotEmpty() }
            return parts.getOrNull(1)?.takeIf { parts.size == 2 && parts[0] == "j" && TOKEN.matches(it) }
        }

        /** Every vehicle leg needs its trip, stops and departure time; walk-only journeys are not shared. */
        fun request(journey: Journey, serviceDay: LocalDate): ShareRequest? {
            if (journey.isWalkOnly || journey.rides.isEmpty()) return null
            val legs = journey.rides.map { leg ->
                ShareLeg(
                    tripId = leg.tripId ?: return null,
                    from = leg.board.id?.toString() ?: return null,
                    to = leg.alight.id?.toString() ?: return null,
                    departure = leg.board.time ?: return null,
                )
            }
            return ShareRequest(serviceDay.toString(), legs)
        }
    }
}
