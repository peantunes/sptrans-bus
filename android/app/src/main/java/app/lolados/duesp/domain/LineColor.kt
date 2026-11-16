package app.lolados.duesp.domain

import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Readable colours for transit lines. Brand colours such as Metrô L4's yellow are too
 * light for white text, or for text and lines on a white card, so they are checked
 * with the WCAG contrast ratio and adjusted when needed. Same rules as the iOS app.
 */
object LineColor {
    data class Rgb(val r: Double, val g: Double, val b: Double)

    /** Text on a badge filled with the line colour (WCAG AA for text). */
    const val TEXT_CONTRAST = 4.5
    /** Lines, rings and icons drawn in the line colour (WCAG for graphics). */
    const val GRAPHIC_CONTRAST = 3.0

    const val DARK_TEXT = "1C1C1E"
    const val LIGHT_TEXT = "FFFFFF"

    fun parse(hex: String?): Rgb? {
        var value = hex?.trim()?.removePrefix("#") ?: return null
        if (value.length == 3) value = value.map { "$it$it" }.joinToString("")
        if (value.length != 6) return null
        val int = value.toIntOrNull(16) ?: return null
        return Rgb(((int shr 16) and 0xFF) / 255.0, ((int shr 8) and 0xFF) / 255.0, (int and 0xFF) / 255.0)
    }

    fun hex(color: Rgb): String {
        fun channel(v: Double) = (min(1.0, max(0.0, v)) * 255).roundToInt()
        return "%02X%02X%02X".format(channel(color.r), channel(color.g), channel(color.b))
    }

    fun luminance(color: Rgb): Double {
        fun linear(c: Double) = if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    fun contrast(a: Rgb, b: Rgb): Double {
        val la = luminance(a)
        val lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /**
     * Text colour for a badge filled with [background]. The API's text colour is kept only
     * when readable (it sends white on Metrô L4's yellow).
     */
    fun badgeText(background: String?, preferred: String?): String {
        val fill = parse(background) ?: return LIGHT_TEXT
        val wanted = parse(preferred)
        if (wanted != null && contrast(fill, wanted) >= TEXT_CONTRAST) return hex(wanted)
        val dark = parse(DARK_TEXT)!!
        val light = parse(LIGHT_TEXT)!!
        return if (contrast(fill, dark) >= contrast(fill, light)) DARK_TEXT else LIGHT_TEXT
    }

    /**
     * The line colour darkened on a light surface (or lightened on a dark one) until it reaches
     * [minimumContrast] against [surfaceHex]. Null when the line colour is missing or invalid.
     */
    fun readable(lineHex: String?, surfaceHex: String, minimumContrast: Double): String? {
        val line = parse(lineHex) ?: return null
        val surface = parse(surfaceHex) ?: return null
        if (contrast(line, surface) >= minimumContrast) return hex(line)
        val target = if (luminance(surface) > 0.5) Rgb(0.0, 0.0, 0.0) else Rgb(1.0, 1.0, 1.0)
        var mixed = line
        for (step in 1..20) {
            val t = step / 20.0
            mixed = Rgb(
                line.r + (target.r - line.r) * t,
                line.g + (target.g - line.g) * t,
                line.b + (target.b - line.b) * t,
            )
            if (contrast(mixed, surface) >= minimumContrast) break
        }
        return hex(mixed)
    }
}
