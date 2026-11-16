package app.lolados.duesp.ui.plan

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lolados.duesp.R
import app.lolados.duesp.domain.GtfsTime
import app.lolados.duesp.domain.Journey
import app.lolados.duesp.domain.JourneyStep
import app.lolados.duesp.domain.LineColor
import app.lolados.duesp.domain.PlanRoute
import app.lolados.duesp.domain.RideLeg
import app.lolados.duesp.domain.TimedStop
import app.lolados.duesp.domain.TransitMode
import app.lolados.duesp.ui.icon
import app.lolados.duesp.ui.parseHexColor

/** Card surface used by the planner; line colours are made readable against it. */
@Composable
fun planCardColor(): Color = MaterialTheme.colorScheme.surfaceContainerLowest

private fun Color.hex(): String = "%06X".format(toArgb() and 0xFFFFFF)

/** Line colours made readable on [surface] (see [LineColor]). */
class LinePalette(route: PlanRoute?, fallback: Color, surface: Color) {
    private val fillHex = route?.color?.takeIf { LineColor.parse(it) != null } ?: fallback.hex()
    /** Brand colour, for badge and ring fills. */
    val fill: Color = parseHexColor(fillHex, fallback)
    /** Text on [fill]. */
    val onFill: Color = parseHexColor(LineColor.badgeText(fillHex, route?.textColor), Color.White)
    /** Brand colour adjusted for text on the card. */
    val text: Color = parseHexColor(LineColor.readable(fillHex, surface.hex(), LineColor.TEXT_CONTRAST), fill)
    /** Brand colour adjusted for lines and rings on the card. */
    val stroke: Color = parseHexColor(LineColor.readable(fillHex, surface.hex(), LineColor.GRAPHIC_CONTRAST), fill)
}

@Composable
fun rememberLinePalette(route: PlanRoute?): LinePalette {
    val fallback = MaterialTheme.colorScheme.primary
    val surface = planCardColor()
    return remember(route, fallback, surface) { LinePalette(route, fallback, surface) }
}

@Composable
fun LineBadge(route: PlanRoute?, mode: TransitMode, modifier: Modifier = Modifier) {
    val palette = rememberLinePalette(route)
    Row(
        modifier
            .background(palette.fill, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(mode.icon(), null, tint = palette.onFill, modifier = Modifier.size(16.dp))
        Text(
            route?.displayName ?: stringResource(R.string.plan_line),
            color = palette.onFill,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
    }
}

@Composable
fun PlanCard(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable () -> Unit) {
    val colors = CardDefaults.cardColors(containerColor = planCardColor())
    val shape = RoundedCornerShape(24.dp)
    if (onClick != null) {
        Card(onClick = onClick, modifier = modifier.fillMaxWidth(), shape = shape, colors = colors) {
            Box(Modifier.padding(18.dp)) { content() }
        }
    } else {
        Card(modifier = modifier.fillMaxWidth(), shape = shape, colors = colors) {
            Box(Modifier.padding(18.dp)) { content() }
        }
    }
}

// ---------------------------------------------------------------------------
// Results list
// ---------------------------------------------------------------------------

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun JourneyOptionCard(journey: Journey, onClick: () -> Unit) {
    PlanCard(onClick = onClick) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(GtfsTime.display(journey.startTime) ?: "--:--", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Icon(Icons.AutoMirrored.Filled.ArrowForward, null, Modifier.padding(horizontal = 8.dp).size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(GtfsTime.display(journey.endTime) ?: "--:--", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                journey.durationMinutes?.let {
                    Text(GtfsTime.duration(it), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Text(
                transfersText(journey),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), CircleShape)
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            )
            val metrics = buildList {
                journey.walkMinutes?.let { add(stringResource(R.string.plan_walk_minutes, it)) }
                journey.walkMeters?.let { add(distanceText(it)) }
                journey.stopCount?.takeIf { !journey.isWalkOnly }?.let { add(pluralStringResource(R.plurals.plan_stops, it, it)) }
            }
            if (metrics.isNotEmpty()) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.AutoMirrored.Filled.DirectionsWalk, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(metrics.joinToString("  ·  "), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (journey.rides.isNotEmpty()) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    journey.rides.forEach { LineBadge(it.route, it.mode) }
                }
            }
        }
    }
}

@Composable
fun transfersText(journey: Journey): String = when {
    journey.isWalkOnly -> stringResource(R.string.plan_walk_only)
    journey.transfers == 0 -> stringResource(R.string.plan_no_transfers)
    else -> pluralStringResource(R.plurals.plan_transfers, journey.transfers, journey.transfers)
}

fun distanceText(meters: Int): String =
    if (meters >= 1000) "%.1f km".format(meters / 1000.0) else "$meters m"

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

@Composable
fun JourneySummaryCard(journey: Journey, originLabel: String, destinationLabel: String) {
    val base = MaterialTheme.colorScheme.primary
    val gradient = Brush.linearGradient(listOf(mix(base, Color.Black, 0.5f), mix(base, Color.Black, 0.72f)))
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(gradient)
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        val white = Color.White
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(originLabel, color = white, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Icon(Icons.Filled.ArrowDownward, null, tint = white.copy(alpha = 0.7f))
            Text(destinationLabel, color = white, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        Row(verticalAlignment = Alignment.Bottom) {
            Column {
                Text(stringResource(R.string.plan_departure), color = white.copy(alpha = 0.8f), style = MaterialTheme.typography.labelMedium)
                Text(GtfsTime.display(journey.startTime) ?: "--:--", color = white, fontSize = 32.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End) {
                Text(stringResource(R.string.plan_arrival), color = white.copy(alpha = 0.8f), style = MaterialTheme.typography.labelMedium)
                Text(GtfsTime.display(journey.endTime) ?: "--:--", color = white, fontSize = 32.sp, fontWeight = FontWeight.Bold)
            }
        }
        val line = listOfNotNull(transfersText(journey), journey.durationMinutes?.let { GtfsTime.duration(it) }).joinToString(" · ")
        Text(line, color = white, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        journey.walkMinutes?.takeIf { !journey.isWalkOnly }?.let {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.AutoMirrored.Filled.DirectionsWalk, null, tint = white, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.plan_includes_walking, it), color = white, style = MaterialTheme.typography.bodyMedium)
            }
        }
        Text(stringResource(R.string.plan_scheduled_note), color = white.copy(alpha = 0.8f), style = MaterialTheme.typography.bodySmall)
    }
}

private fun mix(a: Color, b: Color, t: Float) = Color(
    red = a.red + (b.red - a.red) * t,
    green = a.green + (b.green - a.green) * t,
    blue = a.blue + (b.blue - a.blue) * t,
)

/** One vehicle leg: header, then boarding, intermediate and alighting stops, in a single card. */
@Composable
fun RideLegCard(leg: RideLeg, onFocus: () -> Unit) {
    val palette = rememberLinePalette(leg.route)
    var showAll by remember(leg) { mutableStateOf(false) }
    val collapsedLimit = 3
    PlanCard(Modifier.animateContentSize()) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(
                Modifier.fillMaxWidth().clickable(onClick = onFocus),
                verticalAlignment = Alignment.Top,
            ) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    LineBadge(leg.route, leg.mode)
                    leg.route?.longName?.takeIf { it.isNotBlank() }?.let {
                        Text(it, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.semantics { heading() })
                    }
                    val subtitle = listOfNotNull(
                        leg.headsign?.let { stringResource(R.string.plan_towards, it) },
                        leg.durationMinutes?.let { GtfsTime.duration(it) },
                    ).joinToString(" · ")
                    if (subtitle.isNotEmpty()) {
                        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                leg.headwayMinutes?.let {
                    Text(
                        stringResource(R.string.plan_every_minutes, it),
                        color = palette.text,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .padding(start = 8.dp)
                            .background(palette.stroke.copy(alpha = 0.14f), CircleShape)
                            .padding(horizontal = 10.dp, vertical = 5.dp),
                    )
                }
            }
            HorizontalDivider()
            Column {
                val middle = leg.intermediate
                val visible = if (showAll || middle.size <= collapsedLimit) middle else emptyList()
                StopRow(leg.board, stringResource(R.string.plan_board_here), major = true, first = true, last = false, palette = palette)
                visible.forEach { StopRow(it, null, major = false, first = false, last = false, palette = palette) }
                if (middle.size > collapsedLimit) {
                    ToggleRow(middle.size, showAll, palette) { showAll = !showAll }
                }
                StopRow(leg.alight, stringResource(R.string.plan_get_off_here), major = true, first = false, last = true, palette = palette)
            }
        }
    }
}

private val TimeColumn = 64.dp
private val RailColumn = 26.dp

@Composable
private fun StopRow(stop: TimedStop, caption: String?, major: Boolean, first: Boolean, last: Boolean, palette: LinePalette) {
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
        Text(
            GtfsTime.display(stop.time).orEmpty(),
            modifier = Modifier.width(TimeColumn).padding(top = if (major) 0.dp else 2.dp),
            style = if (major) MaterialTheme.typography.titleLarge else MaterialTheme.typography.bodyMedium,
            fontWeight = if (major) FontWeight.Bold else FontWeight.Normal,
            color = if (major) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = androidx.compose.ui.text.style.TextAlign.End,
            maxLines = 1,
        )
        Spacer(Modifier.width(10.dp))
        Rail(first, last, major, showRing = true, palette = palette)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f).padding(bottom = if (last) 0.dp else if (major) 18.dp else 12.dp)) {
            Text(
                stop.name,
                style = if (major) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyLarge,
                fontWeight = if (major) FontWeight.SemiBold else FontWeight.Normal,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            caption?.let {
                Text(it.uppercase(), color = palette.text, style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
            }
        }
    }
}

@Composable
private fun ToggleRow(count: Int, expanded: Boolean, palette: LinePalette, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).clickable(onClick = onClick)) {
        Spacer(Modifier.width(TimeColumn + 10.dp))
        Rail(first = false, last = false, major = false, showRing = false, palette = palette)
        Spacer(Modifier.width(10.dp))
        Row(Modifier.padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, null, tint = palette.text, modifier = Modifier.size(20.dp))
            Text(
                if (expanded) stringResource(R.string.plan_hide_stops) else pluralStringResource(R.plurals.plan_stops_on_the_way, count, count),
                color = palette.text,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

/** Marker column: line from the previous stop, a ring, line to the next stop. */
@Composable
private fun Rail(first: Boolean, last: Boolean, major: Boolean, showRing: Boolean, palette: LinePalette) {
    val ringBackground = planCardColor()
    Canvas(Modifier.width(RailColumn).fillMaxHeight()) {
        val x = size.width / 2
        val ring = if (major) 22.dp.toPx() else 14.dp.toPx()
        val ringTop = if (major) 2.dp.toPx() else 4.dp.toPx()
        val centerY = ringTop + ring / 2
        val line = palette.stroke.copy(alpha = 0.45f)
        val width = 4.dp.toPx()
        if (!first) drawLine(line, Offset(x, 0f), Offset(x, if (showRing) centerY else size.height), width)
        if (!last) drawLine(line, Offset(x, if (showRing) centerY else 0f), Offset(x, size.height), width)
        if (showRing) {
            val stroke = if (major) 5.dp.toPx() else 3.5.dp.toPx()
            drawCircle(ringBackground, ring / 2, Offset(x, centerY))
            drawCircle(palette.stroke, (ring - stroke) / 2, Offset(x, centerY), style = Stroke(stroke))
        }
    }
}

/** Walking between steps: a dashed block, unlike the vehicle cards. */
@Composable
fun WalkBlock(step: JourneyStep.Walk, onFocus: () -> Unit) {
    val outline = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
    val target = if (step.toDestination) stringResource(R.string.plan_your_destination) else step.to.name
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .clickable(onClick = onFocus)
            .dashedBorder(outline)
            .padding(horizontal = 18.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.AutoMirrored.Filled.DirectionsWalk, null, tint = MaterialTheme.colorScheme.primary)
        GtfsTime.display(step.departureTime)?.let {
            Text(it, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        }
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.plan_walk_to, GtfsTime.duration(step.minutes), target),
                style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
            if (step.meters > 0) {
                Text(distanceText(step.meters), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

private fun Modifier.dashedBorder(color: Color): Modifier = this.drawBehind {
    val stroke = 1.5.dp.toPx()
    drawRoundRect(
        color = color,
        topLeft = Offset(stroke / 2, stroke / 2),
        size = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(24.dp.toPx()),
        style = Stroke(width = stroke, cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 5.dp.toPx()))),
    )
}
