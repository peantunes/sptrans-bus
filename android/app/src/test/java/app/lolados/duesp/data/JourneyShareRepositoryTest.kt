package app.lolados.duesp.data

import app.lolados.duesp.data.api.PlanResponse
import app.lolados.duesp.domain.Place
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

class JourneyShareRepositoryTest {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    @Test
    fun shareLinksAreRecognisedStrictly() {
        assertEquals("Hv8EVpDjMTV2", JourneyShareRepository.token("https://sptrans.lolados.app/j/Hv8EVpDjMTV2"))
        assertNull(JourneyShareRepository.token("https://sptrans.lolados.app/j/short"))
        assertNull(JourneyShareRepository.token("https://evil.example/j/Hv8EVpDjMTV2"))
        assertNull(JourneyShareRepository.token("http://sptrans.lolados.app/j/Hv8EVpDjMTV2"))
        assertNull(JourneyShareRepository.token("https://sptrans.lolados.app/api/share.php?t=Hv8EVpDjMTV2"))
        assertNull(JourneyShareRepository.token(null as String?))
    }

    @Test
    fun shareRequestSendsReferencesOnly() {
        val body = requireNotNull(javaClass.getResource("/planner/planner-multimodal.json")).readText()
        val plan = TripPlanMapper(json).map(json.decodeFromString<PlanResponse>(body).result,
            Place("Home", -23.55, -46.63), Place("Work", -23.53, -46.64))
        val journey = plan.journeys.first()
        val request = requireNotNull(JourneyShareRepository.request(journey, LocalDate.of(2026, 11, 16)))
        assertEquals("2026-11-16", request.date)
        assertEquals(journey.rides.size, request.legs.size)
        assertEquals(journey.rides.first().tripId, request.legs.first().tripId)
        assertEquals(journey.rides.first().board.time, request.legs.first().departure)
        assertFalse("origin/destination must never be sent", json.encodeToString(request).contains("lat"))
        assertNull(JourneyShareRepository.request(plan.walkOnly!!, LocalDate.of(2026, 11, 16)))
    }
}
