package app.lolados.duesp.data.api

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

class ApiException(message: String) : IOException(message)

/** Thin client for the Due SP backend (Lolados-server, `apps/sptrans.lolados.app`). */
class TransitApi(
    private val baseUrl: String,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build(),
) {
    @PublishedApi
    internal val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    suspend fun nearby(lat: Double, lon: Double, limit: Int = 30): NearbyStopsResponse =
        get("nearby.php", "lat" to lat.toString(), "lon" to lon.toString(), "limit" to limit.toString())

    suspend fun search(query: String, limit: Int = 40): SearchStopsResponse =
        get("search.php", "q" to query, "limit" to limit.toString())

    suspend fun arrivals(
        stopId: Int,
        limit: Int,
        date: String? = null,
        time: String? = null,
        cursorDate: String? = null,
        cursorTime: String? = null,
        direction: String = "next",
    ): ArrivalsResponse = get(
        "arrivals.php",
        "stop_id" to stopId.toString(),
        "limit" to limit.toString(),
        "direction" to direction,
        "date" to date,
        "time" to time,
        "cursor_date" to cursorDate,
        "cursor_time" to cursorTime,
    )

    suspend fun railStatus(refresh: Boolean = false): RailStatusResponse =
        get("metro_cptm.php", "refresh" to if (refresh) "1" else null)

    suspend fun alertState(installationId: String): AlertStateEnvelope =
        get("rail_alert_subscriptions.php", "installation_id" to installationId)

    suspend fun updateAlerts(request: AlertUpdateRequest): AlertUpdateResponse {
        val body = json.encodeToString(request).toRequestBody(JSON_MEDIA_TYPE)
        return json.decodeFromString(fetch("rail_alert_subscriptions.php", emptyList(), body))
    }

    private suspend inline fun <reified T> get(path: String, vararg params: Pair<String, String?>): T {
        val body = fetch(path, params.toList())
        return json.decodeFromString<T>(body)
    }

    @PublishedApi
    internal suspend fun fetch(path: String, params: List<Pair<String, String?>>, postBody: RequestBody? = null): String =
        withContext(Dispatchers.IO) {
            val url = (baseUrl + path).toHttpUrl().newBuilder().apply {
                params.forEach { (key, value) -> if (value != null) addQueryParameter(key, value) }
            }.build()
            val request = Request.Builder().url(url).header("Accept", "application/json").apply {
                if (postBody != null) post(postBody)
            }.build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw ApiException("HTTP ${response.code} em $path")
                response.body.string()
            }
        }

    private companion object {
        val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
    }
}
