package app.lolados.duesp.data

import app.lolados.duesp.data.api.PlanResponse
import app.lolados.duesp.domain.GtfsTime
import app.lolados.duesp.domain.JourneyStep
import app.lolados.duesp.domain.Place
import app.lolados.duesp.domain.TransitMode
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TripPlanMapperTest {
    // Same configuration as TransitApi.
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }
    private val mapper = TripPlanMapper(json)
    private val origin = Place("Home", -23.55, -46.63)
    private val destination = Place("Work", -23.53, -46.64)

    private fun fixture(name: String): String =
        requireNotNull(javaClass.getResource("/planner/$name")) { "missing fixture $name" }.readText()

    private fun map(body: String) = mapper.map(json.decodeFromString<PlanResponse>(body).result, origin, destination)

    @Test
    fun multimodalKeepsServerOrderModesAndDoorToDoorTimes() {
        val plan = map(fixture("planner-multimodal.json"))
        val journey = plan.journeys.first()
        assertEquals(listOf("walk", "ride", "walk", "ride", "walk", "ride", "walk"),
            journey.steps.map { if (it is JourneyStep.Walk) "walk" else "ride" })
        assertEquals(listOf(TransitMode.BUS, TransitMode.METRO, TransitMode.TRAIN), journey.rides.map { it.mode })
        assertEquals("23:50:00", journey.startTime)
        assertEquals("00:40", GtfsTime.display(journey.endTime))
        assertEquals(2, journey.transfers)
        assertEquals(50, journey.durationMinutes)
        val last = journey.steps.last() as JourneyStep.Walk
        assertTrue(last.toDestination)
        assertEquals("Work", last.to.name)
        assertNotNull(plan.walkOnly)
    }

    @Test
    fun legacyResponseBuildsRidesAndEstimatedWalks() {
        val plan = map(fixture("planner-legacy.json"))
        val journey = plan.journeys.first()
        assertEquals(2, journey.rides.size)
        assertEquals("10:23:42", journey.startTime)
        assertNull(plan.walkOnly)
        // Walks are estimated from the request's origin/destination when far enough.
        journey.steps.filterIsInstance<JourneyStep.Walk>().forEach { assertTrue(it.minutes >= 1) }
    }

    @Test
    fun malformedSegmentsFallBackToLegs() {
        val body = """
            {"result":{"alternatives":[{"type":"direct","summary":{"departureTime":"08:00:00"},
              "legs":[{"route":{"routeId":"8000-10","color":"FFD700","type":"3"},"originStop":{"id":"123","name":"A","lat":"-23.55","lon":-46.63},
                       "destinationStop":{"id":456,"name":"B","lat":-23.54,"lon":-46.62}}],
              "segments":"not a list"}],"walk":{"distanceMeters":"oops"}}}
        """.trimIndent()
        val plan = map(body)
        val ride = plan.journeys.single().rides.single()
        assertEquals(123, ride.board.id)
        assertEquals(-23.55, ride.board.lat!!, 0.0)
        assertEquals("8000-10", ride.route?.displayName)
        assertNull(plan.walkOnly)
    }

    @Test
    fun nonNumericStopIdsDoNotFailDecoding() {
        val body = """
            {"result":{"alternatives":[{"type":"direct","segments":[
              {"type":"transit","mode":"rail","route":{"shortName":"CPTM L11"},
               "originStop":{"id":"ESTACAO-BRAS","name":"Brás"},"destinationStop":{"id":null,"name":"Luz"},
               "departureTime":"08:00:00","arrivalTime":"08:10:00","intermediateStops":[{"id":"X","name":"Mid","time":"08:05:00"}]}]}]}}
        """.trimIndent()
        val ride = map(body).journeys.single().rides.single()
        assertNull(ride.board.id)
        assertEquals("Brás", ride.board.name)
        assertEquals("08:05:00", ride.intermediate.single().time)
        assertEquals(TransitMode.TRAIN, ride.mode)
    }

    @Test
    fun alternativesWithoutVehiclesAreDropped() {
        val plan = map("""{"result":{"alternatives":[{"type":"direct","segments":[{"type":"walk","durationMinutes":3}]}]}}""")
        assertTrue(plan.journeys.isEmpty())
        assertFalse(plan.all.any { !it.isWalkOnly })
    }

    @Test
    fun gtfsTimesWrapPastMidnight() {
        assertEquals("00:40", GtfsTime.display("24:40:00"))
        assertEquals("08:05", GtfsTime.display("8:05"))
        assertNull(GtfsTime.display(null))
        assertEquals("1 h 5 min", GtfsTime.duration(65))
    }
}
