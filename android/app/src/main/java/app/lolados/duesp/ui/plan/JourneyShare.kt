package app.lolados.duesp.ui.plan

import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.lolados.duesp.R
import app.lolados.duesp.data.JourneyShareException
import app.lolados.duesp.data.JourneyShareRepository
import app.lolados.duesp.data.SharedJourney
import app.lolados.duesp.domain.Journey
import app.lolados.duesp.ui.appContainer
import kotlinx.coroutines.launch
import java.time.LocalDate

/** Share state for a journey detail: creates (or reuses) the link, then opens the system share sheet. */
class JourneySharer(private val createLink: suspend (Journey, LocalDate) -> String, private val context: Context) {
    var isCreating by mutableStateOf(false)
        private set

    suspend fun share(journey: Journey, serviceDay: LocalDate, existingUrl: String? = null) {
        val url = existingUrl ?: run {
            isCreating = true
            try {
                createLink(journey, serviceDay)
            } catch (e: JourneyShareException) {
                Toast.makeText(context, R.string.plan_share_failed, Toast.LENGTH_LONG).show()
                return
            } finally {
                isCreating = false
            }
        }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, url)
            putExtra(Intent.EXTRA_TITLE, context.getString(R.string.plan_share_title))
        }
        context.startActivity(Intent.createChooser(send, context.getString(R.string.plan_share_title)))
    }
}

@Composable
fun rememberJourneySharer(): JourneySharer {
    val container = appContainer()
    val context = LocalContext.current
    return remember(container, context) { JourneySharer(container.journeyShare::create, context) }
}

fun canShare(journey: Journey): Boolean = JourneyShareRepository.request(journey, LocalDate.now()) != null

/** A journey someone shared (https://sptrans.lolados.app/j/<token>), opened from an App Link. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SharedJourneyScreen(token: String, onBack: () -> Unit) {
    val repository = appContainer().journeyShare
    var shared by remember(token) { mutableStateOf<SharedJourney?>(null) }
    var failed by remember(token) { mutableStateOf<JourneyShareException?>(null) }
    var attempt by remember(token) { mutableStateOf(0) }
    LaunchedEffect(token, attempt) {
        failed = null
        try {
            shared = repository.load(token)
        } catch (e: JourneyShareException) {
            failed = e
        }
    }
    val current = shared
    if (current != null) {
        val sharer = rememberJourneySharer()
        val scope = rememberCoroutineScope()
        JourneyDetailScreen(
            journey = current.journey,
            originLabel = current.from,
            destinationLabel = current.to,
            onBack = onBack,
            isSharing = sharer.isCreating,
            onShare = { scope.launch { sharer.share(current.journey, LocalDate.now(), existingUrl = current.url) } },
        )
        return
    }
    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.plan_shared_title)) },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) } },
        )
        Column(
            Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val error = failed
            if (error == null) {
                CircularProgressIndicator()
                Text(stringResource(R.string.plan_shared_loading))
            } else {
                Text(
                    stringResource(if (error.notFound) R.string.plan_shared_not_found else R.string.plan_shared_unavailable),
                    style = MaterialTheme.typography.titleMedium,
                )
                if (!error.notFound) Button(onClick = { attempt++ }) { Text(stringResource(R.string.action_retry)) }
            }
        }
    }
}
