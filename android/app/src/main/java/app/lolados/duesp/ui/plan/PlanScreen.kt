package app.lolados.duesp.ui.plan

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.RadioButtonChecked
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.BookmarkAdd
import androidx.compose.material.icons.filled.ClearAll
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Bookmarks
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.ui.text.style.TextAlign
import app.lolados.duesp.domain.PlannerLimits
import app.lolados.duesp.domain.SavedRoute
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lolados.duesp.R
import app.lolados.duesp.data.PlaceSuggestion
import app.lolados.duesp.ui.appContainer
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun PlanScreen(vm: PlanViewModel, onOpenJourney: (Int) -> Unit, onOpenPremium: () -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    val currentLabel = stringResource(R.string.plan_current_location)
    val location = appContainer().location
    val focusManager = LocalFocusManager.current
    var showSaved by rememberSaveable { mutableStateOf(false) }

    if (showSaved) {
        SavedRoutesSheet(
            state = state,
            onDismiss = { showSaved = false },
            onUse = { route -> showSaved = false; vm.useRoute(route, currentLabel) },
            onDelete = { vm.deleteRoute(it.id) },
            onSaveCurrent = vm::saveCurrentRoute,
        )
    }
    state.premiumPrompt?.let { prompt ->
        PremiumPromptDialog(prompt, onDismiss = vm::dismissPremiumPrompt, onOpenPremium = {
            vm.dismissPremiumPrompt()
            showSaved = false
            onOpenPremium()
        })
    }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { granted ->
        if (granted.values.any { it }) vm.useCurrentLocation(currentLabel)
    }
    val useCurrentLocation = {
        focusManager.clearFocus()
        if (location.hasPermission()) vm.useCurrentLocation(currentLabel)
        else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
    }
    LaunchedEffect(Unit) { vm.fillOriginIfEmpty(currentLabel) }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Row(Modifier.padding(top = 8.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.plan_title), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f))
                FilledTonalIconButton(onClick = { focusManager.clearFocus(); showSaved = true }, modifier = Modifier.testTag("plan.saved")) {
                    Icon(Icons.Filled.Bookmarks, stringResource(R.string.plan_saved_routes))
                }
            }
        }
        item {
            PlanForm(
                state = state,
                vm = vm,
                onUseCurrentLocation = useCurrentLocation,
                onSearch = { focusManager.clearFocus(); vm.plan() },
            )
        }
        if (state.locationUnavailable) {
            item {
                Text(stringResource(R.string.plan_location_unavailable), color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium)
            }
        }
        state.error?.let { error ->
            item {
                Text(error.ifBlank { stringResource(R.string.error_generic) }, color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium, modifier = Modifier.testTag("plan.error"))
            }
        }
        val plan = state.plan
        val context = state.context
        if (plan != null && context != null) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(R.string.plan_results_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text("${context.origin.name} → ${context.destination.name}", style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(context.departure.format(DISPLAY_DATE_TIME), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (plan.all.isEmpty()) {
                item {
                    Column(Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Filled.DirectionsBus, null, Modifier.size(36.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(stringResource(R.string.plan_no_results), style = MaterialTheme.typography.titleMedium)
                        Text(stringResource(R.string.plan_no_results_hint), style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            items(plan.all, key = { it.id }) { journey ->
                JourneyOptionCard(journey) { onOpenJourney(journey.id) }
            }
            if (plan.all.isNotEmpty()) {
                item {
                    Text(stringResource(R.string.plan_results_note), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun PlanForm(state: PlanUiState, vm: PlanViewModel, onUseCurrentLocation: () -> Unit, onSearch: () -> Unit) {
    val focusManager = LocalFocusManager.current
    var showPreferences by rememberSaveable { mutableStateOf(false) }
    var pickingDate by rememberSaveable { mutableStateOf(false) }
    var pickingTimeFor by rememberSaveable { mutableStateOf<String?>(null) }

    PlanCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    PlaceInput(PlanField.ORIGIN, state.origin.text, stringResource(R.string.plan_from), Icons.Filled.RadioButtonChecked,
                        vm, onSearch)
                    HorizontalDivider(Modifier.padding(start = 40.dp))
                    PlaceInput(PlanField.DESTINATION, state.destination.text, stringResource(R.string.plan_to), Icons.Filled.Place,
                        vm, onSearch)
                }
                FilledTonalIconButton(onClick = vm::swap, modifier = Modifier.padding(start = 8.dp)) {
                    Icon(Icons.Filled.SwapVert, stringResource(R.string.plan_swap))
                }
            }

            state.activeField?.let { field ->
                if (state.isSuggesting && state.suggestions.isEmpty()) {
                    Row(Modifier.padding(start = 40.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                        Text(stringResource(R.string.plan_finding_places), style = MaterialTheme.typography.bodySmall)
                    }
                }
                state.suggestions.forEach { suggestion ->
                    SuggestionRow(suggestion) {
                        focusManager.clearFocus()
                        vm.selectSuggestion(field, suggestion)
                    }
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onUseCurrentLocation) {
                    Icon(Icons.Filled.MyLocation, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.plan_use_current_location))
                }
                Spacer(Modifier.weight(1f))
                if (state.hasFormContent) {
                    TextButton(onClick = { focusManager.clearFocus(); vm.clearForm() }, modifier = Modifier.testTag("plan.clear")) {
                        Icon(Icons.Filled.ClearAll, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(R.string.plan_clear))
                    }
                }
            }
            HorizontalDivider()

            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Schedule, null)
                Spacer(Modifier.width(10.dp))
                Text(stringResource(R.string.plan_departure), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f))
            }
            Row {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    SegmentedButton(selected = state.departAt == null, onClick = { vm.setDeparture(null) },
                        shape = SegmentedButtonDefaults.itemShape(0, 2)) { Text(stringResource(R.string.plan_now)) }
                    SegmentedButton(
                        selected = state.departAt != null,
                        onClick = { if (vm.requestChooseTime()) pickingDate = true },
                        shape = SegmentedButtonDefaults.itemShape(1, 2),
                        icon = { if (!state.isPremium) Icon(Icons.Filled.Lock, null, Modifier.size(16.dp)) },
                    ) { Text(stringResource(R.string.plan_choose_time)) }
                }
            }
            state.departAt?.let { departAt ->
                Text(
                    stringResource(R.string.plan_leave_at, departAt.format(DISPLAY_DATE_TIME)),
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.clickable { if (vm.requestChooseTime()) pickingDate = true }.padding(vertical = 4.dp),
                )
            }
            Text(stringResource(R.string.plan_sao_paulo_time), style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)

            Row(
                Modifier.fillMaxWidth().clickable { showPreferences = !showPreferences }.padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Tune, null, tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(10.dp))
                Text(stringResource(R.string.plan_preferences), color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Icon(if (showPreferences) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, null)
            }
            AnimatedVisibility(showPreferences) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.plan_sort_by), style = MaterialTheme.typography.labelLarge)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        PlanPriority.entries.forEach { priority ->
                            FilterChip(selected = state.priority == priority, onClick = { vm.setPriority(priority) },
                                label = { Text(stringResource(priority.label())) })
                        }
                    }
                    Text(stringResource(R.string.plan_max_transfers), style = MaterialTheme.typography.labelLarge)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        (0..4).forEach { n ->
                            FilterChip(selected = state.maxTransfers == n, onClick = { vm.setMaxTransfers(n) }, label = { Text("$n") })
                        }
                    }
                    Text(stringResource(R.string.plan_max_transfers_note), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            Button(
                onClick = onSearch,
                enabled = state.canPlan,
                modifier = Modifier.fillMaxWidth().testTag("plan.search"),
                shape = CircleShape,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 14.dp),
            ) {
                if (state.isPlanning) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.onPrimary)
                    Spacer(Modifier.width(10.dp))
                    Text(stringResource(R.string.plan_searching), style = MaterialTheme.typography.titleMedium)
                } else {
                    Text(stringResource(R.string.plan_search), style = MaterialTheme.typography.titleMedium)
                }
            }
            state.searchesLeft?.let { left ->
                Text(
                    stringResource(R.string.plan_free_searches_left, left, PlannerLimits.FREE_DAILY_SEARCHES),
                    style = MaterialTheme.typography.bodySmall,
                    color = if (left == 0) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }

    if (pickingDate) {
        val initial = state.departAt ?: LocalDateTime.now(PlanViewModel.SAO_PAULO)
        val dateState = rememberDatePickerState(initialSelectedDateMillis = initial.toLocalDate().atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { pickingDate = false },
            confirmButton = {
                TextButton(onClick = {
                    val millis = dateState.selectedDateMillis
                    pickingDate = false
                    if (millis != null) pickingTimeFor = Instant.ofEpochMilli(millis).atOffset(ZoneOffset.UTC).toLocalDate().toString()
                }) { Text(stringResource(R.string.plan_next)) }
            },
            dismissButton = { TextButton(onClick = { pickingDate = false }) { Text(stringResource(R.string.plan_cancel)) } },
        ) { DatePicker(dateState) }
    }
    pickingTimeFor?.let { date ->
        val initial = state.departAt ?: LocalDateTime.now(PlanViewModel.SAO_PAULO)
        val timeState = rememberTimePickerState(initial.hour, initial.minute, is24Hour = true)
        AlertDialog(
            onDismissRequest = { pickingTimeFor = null },
            confirmButton = {
                TextButton(onClick = {
                    vm.setDeparture(java.time.LocalDate.parse(date).atTime(timeState.hour, timeState.minute))
                    pickingTimeFor = null
                }) { Text(stringResource(R.string.plan_done)) }
            },
            dismissButton = { TextButton(onClick = { pickingTimeFor = null }) { Text(stringResource(R.string.plan_cancel)) } },
            text = { TimePicker(timeState) },
        )
    }
}

@Composable
private fun PlaceInput(
    field: PlanField,
    text: String,
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    vm: PlanViewModel,
    onSearch: () -> Unit,
) {
    TextField(
        value = text,
        onValueChange = { vm.onTextChange(field, it) },
        label = { Text(label) },
        placeholder = { Text(stringResource(R.string.plan_place_hint)) },
        leadingIcon = { Icon(icon, null, tint = MaterialTheme.colorScheme.primary) },
        trailingIcon = if (text.isNotEmpty()) {
            {
                IconButton(onClick = { vm.clearField(field) }) {
                    Icon(Icons.Filled.Close, stringResource(R.string.plan_clear_field))
                }
            }
        } else {
            null
        },
        singleLine = true,
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = { onSearch() }),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
        modifier = Modifier
            .fillMaxWidth()
            .testTag(if (field == PlanField.ORIGIN) "plan.origin" else "plan.destination")
            .onFocusChanged { if (it.isFocused) vm.onFocus(field) },
    )
}

@Composable
private fun SuggestionRow(suggestion: PlaceSuggestion, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(suggestion.title, fontWeight = FontWeight.Medium) },
        supportingContent = suggestion.subtitle?.let { { Text(it, maxLines = 2) } },
        leadingContent = {
            Icon(if (suggestion.isStop) Icons.Filled.DirectionsBus else Icons.Filled.Place, null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant)
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SavedRoutesSheet(
    state: PlanUiState,
    onDismiss: () -> Unit,
    onUse: (SavedRoute) -> Unit,
    onDelete: (SavedRoute) -> Unit,
    onSaveCurrent: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.plan_saved_routes), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f))
                if (!state.isPremium) {
                    Text(stringResource(R.string.plan_saved_count, state.savedRoutes.size, PlannerLimits.FREE_SAVED_ROUTES),
                        style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (state.savedRoutes.isEmpty()) {
                Text(stringResource(R.string.plan_saved_empty), style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            state.savedRoutes.forEach { route ->
                PlanCard(onClick = { onUse(route) }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(route.origin.name.takeUnless { route.originIsCurrentLocation } ?: stringResource(R.string.plan_current_location),
                                style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, maxLines = 1)
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Icon(Icons.Filled.ArrowDownward, null, Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(route.destination.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1)
                            }
                            Text(stringResource(R.string.plan_saved_use_now), style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.primary)
                        }
                        IconButton(onClick = { onDelete(route) }) {
                            Icon(Icons.Filled.DeleteOutline, stringResource(R.string.plan_saved_delete))
                        }
                    }
                }
            }
            OutlinedButton(
                onClick = onSaveCurrent,
                enabled = state.canSaveCurrentRoute,
                modifier = Modifier.fillMaxWidth().testTag("plan.saveCurrent"),
                shape = CircleShape,
            ) {
                Icon(Icons.Filled.BookmarkAdd, null, Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(
                    when {
                        state.currentRouteIsSaved -> stringResource(R.string.plan_saved_already)
                        state.origin.place == null || state.destination.place == null -> stringResource(R.string.plan_saved_choose_first)
                        else -> stringResource(R.string.plan_saved_save_current)
                    },
                )
            }
            if (!state.isPremium) {
                Text(stringResource(R.string.plan_saved_free_note, PlannerLimits.FREE_SAVED_ROUTES),
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun PremiumPromptDialog(prompt: PremiumPrompt, onDismiss: () -> Unit, onOpenPremium: () -> Unit) {
    val message = when (prompt) {
        PremiumPrompt.SAVE_LIMIT -> stringResource(R.string.plan_premium_save_limit, PlannerLimits.FREE_SAVED_ROUTES)
        PremiumPrompt.SEARCH_LIMIT -> stringResource(R.string.plan_premium_search_limit, PlannerLimits.FREE_DAILY_SEARCHES)
        PremiumPrompt.CHOOSE_TIME -> stringResource(R.string.plan_premium_choose_time)
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Icon(Icons.Filled.WorkspacePremium, null) },
        title = { Text(stringResource(R.string.premium_locked)) },
        text = { Text(message) },
        confirmButton = { TextButton(onClick = onOpenPremium) { Text(stringResource(R.string.plan_see_premium)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.plan_not_now)) } },
    )
}

private fun PlanPriority.label(): Int = when (this) {
    PlanPriority.ARRIVES_FIRST -> R.string.plan_sort_arrive_first
    PlanPriority.FEWEST_TRANSFERS -> R.string.plan_sort_fewest_transfers
    PlanPriority.LEAST_WALKING -> R.string.plan_sort_least_walking
}

private val DISPLAY_DATE_TIME: DateTimeFormatter = DateTimeFormatter.ofPattern("EEE, d MMM · HH:mm", Locale.forLanguageTag("pt-BR"))
