package app.lolados.duesp.ui

import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import app.lolados.duesp.R

/**
 * Official sources of the public transport data shown in the app (Google Play Misleading Claims policy:
 * government information must link to its original source).
 */
enum class OfficialSource(val label: Int, val url: String) {
    SPTRANS(R.string.source_sptrans, "https://www.sptrans.com.br/desenvolvedores/"),
    METRO(R.string.source_metro, "https://www.metro.sp.gov.br/"),
    CPTM(R.string.source_cptm, "https://www.cptm.sp.gov.br/"),
    OSM(R.string.source_osm, "https://www.openstreetmap.org/copyright"),
}

fun openUrl(context: android.content.Context, url: String) {
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri())) }
}

/**
 * A short footer for screens that show official data: "Fonte: <links>." plus the non-official notice.
 * Links open the official sites.
 */
@Composable
fun SourceFooter(sources: List<OfficialSource>, modifier: Modifier = Modifier) {
    val linkStyle = TextLinkStyles(SpanStyle(color = MaterialTheme.colorScheme.primary, textDecoration = TextDecoration.Underline))
    val labels = sources.map { stringResource(it.label) }
    val prefix = stringResource(R.string.source_prefix)
    val notice = stringResource(R.string.disclaimer_short)
    val text = buildAnnotatedString {
        append(prefix)
        append(" ")
        sources.forEachIndexed { index, source ->
            if (index > 0) append(" · ")
            withLink(LinkAnnotation.Url(source.url, linkStyle)) { append(labels[index]) }
        }
        append(". ")
        append(notice)
    }
    Column(modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
        Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
