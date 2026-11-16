package app.lolados.duesp.alerts

import app.lolados.duesp.domain.RailLineStatus
import app.lolados.duesp.domain.RailSource
import org.junit.Assert.assertEquals
import org.junit.Test

class AlertLineTest {
    private fun status(source: RailSource, number: String, name: String) =
        RailLineStatus(source, number, name, "Operação Normal", "", "", null)

    @Test
    fun lineIdMatchesIosFormat() {
        assertEquals(AlertLine("metro-1", "metro", "1", "Azul"), AlertLine.from(status(RailSource.METRO, "1", "Azul")))
        assertEquals("cptm-11", AlertLine.from(status(RailSource.CPTM, " 11 ", "Coral")).id)
    }

    @Test
    fun lineIdFallsBackToName() {
        assertEquals("cptm-expresso-turístico", AlertLine.from(status(RailSource.CPTM, "", "Expresso Turístico")).id)
    }
}
