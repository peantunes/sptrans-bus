package app.lolados.duesp.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.Subway
import androidx.compose.material.icons.filled.Train
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import app.lolados.duesp.AppContainer
import app.lolados.duesp.DueSPApplication
import app.lolados.duesp.R
import app.lolados.duesp.domain.TransitMode

@Composable
fun appContainer(): AppContainer = (LocalContext.current.applicationContext as DueSPApplication).container

/** Creates a ViewModel with access to the [AppContainer]. */
@Composable
inline fun <reified VM : ViewModel> containerViewModel(key: String? = null, crossinline create: (AppContainer) -> VM): VM {
    val container = appContainer()
    return viewModel(key = key) { create(container) }
}

fun parseHexColor(hex: String?, fallback: Color): Color {
    val clean = hex.orEmpty().trim().removePrefix("#")
    if (clean.length != 6) return fallback
    return clean.toLongOrNull(16)?.let { Color(0xFF000000 or it) } ?: fallback
}

/** Official line colors, used when the status API does not send one. */
fun railLineColor(number: String): Color = when (number) {
    "1" -> Color(0xFF0455A1)
    "2" -> Color(0xFF007E5E)
    "3" -> Color(0xFFEE372F)
    "4" -> Color(0xFFFFD400)
    "5" -> Color(0xFF9B3894)
    "7" -> Color(0xFFCA016B)
    "8" -> Color(0xFF97A098)
    "9" -> Color(0xFF01A9A7)
    "10" -> Color(0xFF008B8B)
    "11" -> Color(0xFFF04E23)
    "12" -> Color(0xFF083D8B)
    "13" -> Color(0xFF00B352)
    "15" -> Color(0xFF9E9E9E)
    "17" -> Color(0xFFBF9E2D)
    else -> Color(0xFF607D8B)
}

fun TransitMode.icon(): ImageVector = when (this) {
    TransitMode.BUS -> Icons.Filled.DirectionsBus
    TransitMode.METRO -> Icons.Filled.Subway
    TransitMode.TRAIN -> Icons.Filled.Train
}

@Composable
fun RouteBadge(name: String, background: Color, textColor: Color, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .background(background, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        Text(name, color = textColor, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun LoadingBox(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
fun ErrorBox(message: String?, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(message ?: stringResource(R.string.error_generic), style = MaterialTheme.typography.bodyMedium)
        Button(onClick = onRetry) { Text(stringResource(R.string.action_retry)) }
    }
}
