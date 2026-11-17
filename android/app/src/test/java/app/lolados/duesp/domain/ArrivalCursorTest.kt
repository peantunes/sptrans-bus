package app.lolados.duesp.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ArrivalCursorTest {
    @Test
    fun nextShiftsOneSecondForward() {
        assertEquals(ArrivalCursor("2026-11-16", "09:18:31"), ArrivalCursor.shifted("2026-11-16", "09:18:30", 1))
    }

    @Test
    fun keepsGtfsHoursPastMidnight() {
        assertEquals(ArrivalCursor("2026-11-16", "25:00:01"), ArrivalCursor.shifted("2026-11-16", "25:00:00", 1))
    }

    @Test
    fun previousAtMidnightRollsBackOneDay() {
        assertEquals(ArrivalCursor("2026-11-15", "23:59:59"), ArrivalCursor.shifted("2026-11-16", "00:00:00", -1))
    }

    @Test
    fun invalidInputReturnsNull() {
        assertNull(ArrivalCursor.shifted("nope", "09:00:00", 1))
        assertNull(ArrivalCursor.shifted("2026-11-16", "x", 1))
    }

    @Test
    fun minutesUntilUsesScheduledTimestamp() {
        val arrival = Arrival("t", "5300-10", "", "", "09:37:00", 3, "", "", waitMinutes = 99,
            serviceDate = "2026-11-16", scheduledTimestamp = 1_000_000L, stopSequence = 1)
        assertEquals(3, arrival.minutesUntil(1_000_000L - 150))
        assertEquals(-2, arrival.minutesUntil(1_000_000L + 150))
        assertEquals(99, arrival.copy(scheduledTimestamp = null).minutesUntil(0))
    }

    @Test
    fun stopModeFromRoutes() {
        assertEquals(TransitMode.METRO, TransitMode.fromRoutes("METRÔ L3, METRÔ L3"))
        assertEquals(TransitMode.TRAIN, TransitMode.fromRoutes("CPTM L11"))
        assertEquals(TransitMode.BUS, TransitMode.fromRoutes("626A-10"))
    }
}
