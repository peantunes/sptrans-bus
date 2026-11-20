package app.lolados.duesp.ui.settings

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Info
import app.lolados.duesp.ui.OfficialSource
import app.lolados.duesp.ui.openUrl
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Policy
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.TextButton
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import app.lolados.duesp.BuildConfig
import app.lolados.duesp.R
import app.lolados.duesp.data.BillingStatus
import app.lolados.duesp.data.PremiumAccess
import app.lolados.duesp.data.PremiumBilling
import app.lolados.duesp.ui.appContainer
import app.lolados.duesp.ui.map.SectionHeader
import kotlinx.coroutines.launch

private const val WEBSITE = "https://sptrans.lolados.app"
private const val CONTACT = "https://lolados.app/contact.php"
private const val PRIVACY = "https://sptrans.lolados.app/privacy.html"
private const val TERMS = "https://sptrans.lolados.app/terms.html"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onOpenPremium: () -> Unit) {
    val context = LocalContext.current
    val hasPremium by appContainer().premium.hasPremium.collectAsState(initial = false)
    fun open(url: String) = context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))

    Column(Modifier.fillMaxSize()) {
        TopAppBar(title = { Text(stringResource(R.string.tab_settings)) })
        Column(Modifier.verticalScroll(rememberScrollState())) {
            SectionHeader(stringResource(R.string.settings_about))
            ListItem(
                headlineContent = { Text(stringResource(R.string.app_name)) },
                supportingContent = { Text(stringResource(R.string.settings_version, BuildConfig.VERSION_NAME)) },
            )
            SectionHeader(stringResource(R.string.settings_sources))
            ListItem(
                leadingContent = { Icon(Icons.Filled.Info, null) },
                headlineContent = { Text(stringResource(R.string.disclaimer_title), fontWeight = FontWeight.SemiBold) },
                supportingContent = { Text(stringResource(R.string.disclaimer_full)) },
            )
            OfficialSource.entries.forEach { source ->
                Row(Icons.AutoMirrored.Filled.OpenInNew, stringResource(source.label)) { openUrl(context, source.url) }
            }
            SectionHeader(stringResource(R.string.settings_support))
            Row(
                Icons.Filled.WorkspacePremium,
                stringResource(R.string.settings_premium),
                trailing = { if (hasPremium) Text(stringResource(R.string.premium_active), color = MaterialTheme.colorScheme.primary) },
                onClick = onOpenPremium,
            )
            Row(Icons.Filled.Language, stringResource(R.string.settings_website)) { open(WEBSITE) }
            Row(Icons.Filled.Email, stringResource(R.string.settings_contact)) { open(CONTACT) }
            SectionHeader(stringResource(R.string.settings_legal))
            Row(Icons.Filled.Policy, stringResource(R.string.settings_privacy)) { open(PRIVACY) }
            Row(Icons.Filled.Description, stringResource(R.string.settings_terms)) { open(TERMS) }
            Text(
                stringResource(R.string.settings_copyright),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(16.dp),
            )
        }
    }
}

@Composable
private fun Row(icon: ImageVector, title: String, trailing: @Composable () -> Unit = {}, onClick: () -> Unit) {
    ListItem(
        modifier = Modifier.clickable(onClick = onClick),
        leadingContent = { Icon(icon, null) },
        headlineContent = { Text(title) },
        trailingContent = trailing,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PremiumScreen(onBack: () -> Unit) {
    val premium = appContainer().premium
    val billing = appContainer().billing
    val hasPremium by premium.hasPremium.collectAsState(initial = false)
    val plans by billing.plans.collectAsState()
    val status by billing.status.collectAsState()
    val pending by billing.pending.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { billing.refresh() }

    Column(Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text(stringResource(R.string.premium_title)) },
            navigationIcon = {
                IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) }
            },
        )
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.premium_badge), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.premium_description), style = MaterialTheme.typography.bodyLarge)
            Text(stringResource(R.string.premium_features_title), style = MaterialTheme.typography.titleMedium)
            listOf(R.string.premium_feature_planner, R.string.premium_feature_arrivals).forEach {
                ListItem(
                    leadingContent = { Icon(Icons.Filled.CheckCircle, null, tint = MaterialTheme.colorScheme.primary) },
                    headlineContent = { Text(stringResource(it)) },
                )
            }
            if (hasPremium) {
                Text(stringResource(R.string.premium_active), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                OutlinedButton(
                    onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, PremiumBilling.manageUrl(context.packageName, null).toUri())) },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.premium_manage)) }
            } else {
                when {
                    plans.isNotEmpty() -> plans.forEach { plan ->
                        val yearly = plan.productId == PremiumAccess.PRODUCT_YEARLY
                        Card(Modifier.fillMaxWidth()) {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(
                                    stringResource(if (yearly) R.string.premium_plan_yearly else R.string.premium_plan_weekly),
                                    style = MaterialTheme.typography.titleMedium,
                                )
                                if (yearly) Text(stringResource(R.string.premium_plan_yearly_badge), color = MaterialTheme.colorScheme.primary)
                                Text(
                                    stringResource(if (yearly) R.string.premium_price_year else R.string.premium_price_week, plan.formattedPrice),
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold,
                                )
                                Button(
                                    onClick = { context.findActivity()?.let { billing.purchase(it, plan) } },
                                    enabled = !pending,
                                    modifier = Modifier.fillMaxWidth(),
                                ) { Text(stringResource(R.string.premium_subscribe)) }
                            }
                        }
                    }
                    status == BillingStatus.Connecting -> CircularProgressIndicator()
                    else -> Text(stringResource(R.string.premium_unavailable), style = MaterialTheme.typography.bodyMedium)
                }
                if (pending) Text(stringResource(R.string.premium_pending), style = MaterialTheme.typography.bodyMedium)
                TextButton(onClick = billing::refresh, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.premium_restore)) }
                Text(stringResource(R.string.premium_terms), style = MaterialTheme.typography.bodySmall)
            }
            if (BuildConfig.DEBUG) {
                ListItem(
                    headlineContent = { Text(stringResource(R.string.premium_debug_toggle)) },
                    trailingContent = {
                        Switch(checked = hasPremium, onCheckedChange = { scope.launch { premium.setPremium(it) } })
                    },
                )
            }
        }
    }
}

/** The Activity behind a Compose context (needed to show the Play purchase sheet). */
private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
