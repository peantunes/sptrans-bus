package app.lolados.duesp.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LineColorTest {
    @Test
    fun yellowLineGetsDarkBadgeTextAndDarkerTextOnWhite() {
        // The API sends white text for Metrô L4 (FFD700).
        assertEquals(LineColor.DARK_TEXT, LineColor.badgeText("FFD700", "FFFFFF"))
        val readable = LineColor.readable("FFD700", "FFFFFF", LineColor.TEXT_CONTRAST)!!
        assertTrue(LineColor.contrast(LineColor.parse(readable)!!, LineColor.parse("FFFFFF")!!) >= LineColor.TEXT_CONTRAST)
    }

    @Test
    fun readableColorsAreKeptAndDarkSurfacesLighten() {
        assertEquals("FFFFFF", LineColor.badgeText("002F6C", "FFFFFF"))
        assertEquals("002F6C", LineColor.readable("002F6C", "FFFFFF", LineColor.TEXT_CONTRAST))
        val onDark = LineColor.readable("002F6C", "1C1C1E", LineColor.GRAPHIC_CONTRAST)!!
        assertTrue(LineColor.contrast(LineColor.parse(onDark)!!, LineColor.parse("1C1C1E")!!) >= LineColor.GRAPHIC_CONTRAST)
    }

    @Test
    fun invalidColorsFallBack() {
        assertNull(LineColor.readable("", "FFFFFF", 3.0))
        assertEquals(LineColor.LIGHT_TEXT, LineColor.badgeText(null, null))
        assertEquals("FFAA00", LineColor.hex(LineColor.parse("#fa0")!!))
    }
}
