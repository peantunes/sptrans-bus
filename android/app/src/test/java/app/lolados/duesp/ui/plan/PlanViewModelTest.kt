package app.lolados.duesp.ui.plan

import app.lolados.duesp.data.LatLon
import app.lolados.duesp.data.PlaceSuggestion
import app.lolados.duesp.data.PlannerStorage
import app.lolados.duesp.domain.Place
import app.lolados.duesp.domain.PlanFormSnapshot
import app.lolados.duesp.domain.PlannerLimits
import app.lolados.duesp.domain.SavedRoute
import app.lolados.duesp.domain.TripPlan
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

@OptIn(ExperimentalCoroutinesApi::class)
class PlanViewModelTest {
    private class FakeStorage : PlannerStorage {
        override val savedRoutes = MutableStateFlow<List<SavedRoute>>(emptyList())
        val counts = mutableMapOf<LocalDate, Int>()
        override suspend fun setSavedRoutes(routes: List<SavedRoute>) { savedRoutes.value = routes }
        override suspend fun searchesOn(day: LocalDate) = counts[day] ?: 0
        override suspend fun recordSearch(day: LocalDate): Int = (counts.getOrDefault(day, 0) + 1).also { counts[day] = it }
        var form: PlanFormSnapshot? = null
        override suspend fun lastForm() = form
        override suspend fun saveForm(form: PlanFormSnapshot) { this.form = form }
    }

    private val home = Place("Home", -23.55, -46.63)
    private val work = Place("Work", -23.53, -46.64)
    private val storage = FakeStorage()
    private val premium = MutableStateFlow(false)
    private val requested = mutableListOf<LocalDateTime>()
    private var clock = LocalDateTime.of(2026, 11, 16, 8, 30)
    private var here: LatLon? = LatLon(-23.56, -46.65)

    private fun viewModel() = PlanViewModel(
        planTrip = { _, _, departure, _, _ -> requested += departure; TripPlan(emptyList()) },
        suggest = { emptyList<PlaceSuggestion>() },
        currentLocation = { here },
        storage = storage,
        isPremium = premium,
        now = { clock },
    )

    private fun PlanViewModel.choose(origin: Place, destination: Place) {
        selectSuggestion(PlanField.ORIGIN, PlaceSuggestion(origin.name, null, origin.lat!!, origin.lon!!))
        selectSuggestion(PlanField.DESTINATION, PlaceSuggestion(destination.name, null, destination.lat!!, destination.lon!!))
    }

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test
    fun nowSearchesSendTheTimeTheButtonIsPressed() = runTest {
        val vm = viewModel()
        vm.choose(home, work)
        vm.plan()
        clock = clock.plusMinutes(7)
        vm.plan()
        assertEquals(listOf(LocalDateTime.of(2026, 11, 16, 8, 30), LocalDateTime.of(2026, 11, 16, 8, 37)), requested)
    }

    @Test
    fun freeUsersGetFiveSearchesPerDay() = runTest {
        val vm = viewModel()
        vm.choose(home, work)
        repeat(PlannerLimits.FREE_DAILY_SEARCHES) { vm.plan() }
        assertEquals(0, vm.state.value.searchesLeft)
        vm.plan()
        assertEquals(PlannerLimits.FREE_DAILY_SEARCHES, requested.size)
        assertEquals(PremiumPrompt.SEARCH_LIMIT, vm.state.value.premiumPrompt)
        // A new day resets the allowance.
        clock = clock.plusDays(1)
        val tomorrow = viewModel()
        tomorrow.choose(home, work)
        tomorrow.plan()
        assertEquals(PlannerLimits.FREE_DAILY_SEARCHES + 1, requested.size)
    }

    @Test
    fun premiumHasUnlimitedSearchesAndChosenTimes() = runTest {
        premium.value = true
        val vm = viewModel()
        vm.choose(home, work)
        val chosen = LocalDateTime.of(2026, 11, 20, 18, 0)
        assertTrue(vm.requestChooseTime())
        vm.setDeparture(chosen)
        repeat(PlannerLimits.FREE_DAILY_SEARCHES + 2) { vm.plan() }
        assertEquals(PlannerLimits.FREE_DAILY_SEARCHES + 2, requested.size)
        assertTrue(requested.all { it == chosen })
        assertNull(vm.state.value.searchesLeft)
    }

    @Test
    fun freeUsersCannotChooseATime() = runTest {
        val vm = viewModel()
        assertEquals(false, vm.requestChooseTime())
        vm.setDeparture(LocalDateTime.of(2026, 11, 20, 18, 0))
        assertNull(vm.state.value.departAt)
        assertEquals(PremiumPrompt.CHOOSE_TIME, vm.state.value.premiumPrompt)
    }

    @Test
    fun freeUsersCanSaveTwoRoutes() = runTest {
        val vm = viewModel()
        vm.choose(home, work)
        vm.saveCurrentRoute()
        vm.choose(work, home)
        vm.saveCurrentRoute()
        vm.choose(home, Place("Gym", -23.5, -46.6))
        vm.saveCurrentRoute()
        assertEquals(PlannerLimits.FREE_SAVED_ROUTES, storage.savedRoutes.value.size)
        assertEquals(PremiumPrompt.SAVE_LIMIT, vm.state.value.premiumPrompt)
    }

    @Test
    fun savedCurrentLocationRouteResolvesWhereYouAreAndSearchesNow() = runTest {
        val vm = viewModel()
        vm.useCurrentLocation("Current location")
        vm.selectSuggestion(PlanField.DESTINATION, PlaceSuggestion("Work", null, work.lat!!, work.lon!!))
        vm.saveCurrentRoute()
        val route = storage.savedRoutes.value.single()
        assertTrue(route.originIsCurrentLocation)

        here = LatLon(-23.60, -46.70)
        vm.useRoute(route, "Current location")
        assertEquals(-23.60, vm.state.value.origin.place!!.lat!!, 0.0)
        assertEquals(1, requested.size)
        assertNotNull(vm.state.value.plan)
    }

    @Test
    fun rewritingTheSameTextKeepsTheSelectedPlace() = runTest {
        val vm = viewModel()
        vm.choose(home, work)
        vm.onTextChange(PlanField.DESTINATION, "Work")
        assertNotNull(vm.state.value.destination.place)
        assertTrue(vm.state.value.canPlan)
        vm.onTextChange(PlanField.DESTINATION, "Work 2")
        assertNull(vm.state.value.destination.place)
    }

    @Test
    fun lastFormIsRememberedAndRestored() = runTest {
        val vm = viewModel()
        vm.choose(home, work)
        vm.setPriority(PlanPriority.LEAST_WALKING)
        assertEquals(home, storage.form?.origin)
        assertEquals(work, storage.form?.destination)

        val reopened = viewModel()
        reopened.fillOriginIfEmpty("Current location")
        assertEquals("Home", reopened.state.value.origin.text)
        assertEquals(work, reopened.state.value.destination.place)
        assertEquals(PlanPriority.LEAST_WALKING, reopened.state.value.priority)
        assertTrue(reopened.state.value.canPlan)
    }

    @Test
    fun rememberedCurrentLocationOriginIsResolvedAgain() = runTest {
        val vm = viewModel()
        vm.useCurrentLocation("Current location")
        vm.selectSuggestion(PlanField.DESTINATION, PlaceSuggestion("Work", null, work.lat!!, work.lon!!))
        assertTrue(storage.form!!.originIsCurrentLocation)
        assertNull(storage.form!!.origin)

        here = LatLon(-23.60, -46.70)
        val reopened = viewModel()
        reopened.fillOriginIfEmpty("Current location")
        assertEquals(-23.60, reopened.state.value.origin.place!!.lat!!, 0.0)
        assertTrue(reopened.state.value.origin.isCurrentLocation)
    }

    @Test
    fun clearingTheFormEmptiesPlacesAndKeepsPreferences() = runTest {
        premium.value = true
        val vm = viewModel()
        vm.choose(home, work)
        vm.setPriority(PlanPriority.FEWEST_TRANSFERS)
        vm.setDeparture(LocalDateTime.of(2026, 11, 20, 18, 0))
        vm.clearField(PlanField.DESTINATION)
        assertNull(vm.state.value.destination.place)
        assertNotNull(vm.state.value.origin.place)
        vm.clearForm()
        assertEquals("", vm.state.value.origin.text)
        assertNull(vm.state.value.departAt)
        assertEquals(PlanPriority.FEWEST_TRANSFERS, vm.state.value.priority)
        assertEquals(false, vm.state.value.hasFormContent)
        assertNull(storage.form?.destination)
    }

    @Test
    fun emptyOriginIsFilledWithTheCurrentLocation() = runTest {
        val vm = viewModel()
        vm.fillOriginIfEmpty("Current location")
        assertEquals("Current location", vm.state.value.origin.text)
        assertTrue(vm.state.value.origin.isCurrentLocation)
    }
}
