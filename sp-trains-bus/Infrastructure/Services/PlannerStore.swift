import Foundation

/// Saved planner routes, the daily search count (free tier limit) and the last form.
protocol PlannerStorage: AnyObject {
    func savedRoutes() -> [SavedRoute]
    func setSavedRoutes(_ routes: [SavedRoute])
    /// [day] is a São Paulo calendar day, "yyyy-MM-dd".
    func searches(on day: String) -> Int
    /// Counts one search on [day] and returns the new total for that day.
    func recordSearch(on day: String) -> Int
    func lastForm() -> PlanFormSnapshot?
    func saveForm(_ form: PlanFormSnapshot)
}

final class PlannerStore: PlannerStorage {
    private let defaults: UserDefaults
    private let routesKey = "planner_saved_routes_v1"
    private let dayKey = "planner_search_day_v1"
    private let countKey = "planner_search_count_v1"
    private let formKey = "planner_last_form_v1"

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func savedRoutes() -> [SavedRoute] {
        guard let data = defaults.data(forKey: routesKey) else { return [] }
        return (try? JSONDecoder().decode([SavedRoute].self, from: data)) ?? []
    }

    func setSavedRoutes(_ routes: [SavedRoute]) {
        defaults.set(try? JSONEncoder().encode(routes), forKey: routesKey)
    }

    func searches(on day: String) -> Int {
        defaults.string(forKey: dayKey) == day ? defaults.integer(forKey: countKey) : 0
    }

    func recordSearch(on day: String) -> Int {
        let total = searches(on: day) + 1
        defaults.set(day, forKey: dayKey)
        defaults.set(total, forKey: countKey)
        return total
    }

    func lastForm() -> PlanFormSnapshot? {
        guard let data = defaults.data(forKey: formKey) else { return nil }
        return try? JSONDecoder().decode(PlanFormSnapshot.self, from: data)
    }

    func saveForm(_ form: PlanFormSnapshot) {
        defaults.set(try? JSONEncoder().encode(form), forKey: formKey)
    }
}

/// Keeps everything in memory (previews and tests).
final class InMemoryPlannerStore: PlannerStorage {
    var routes: [SavedRoute] = []
    var counts: [String: Int] = [:]
    var form: PlanFormSnapshot?

    func savedRoutes() -> [SavedRoute] { routes }
    func setSavedRoutes(_ routes: [SavedRoute]) { self.routes = routes }
    func searches(on day: String) -> Int { counts[day] ?? 0 }
    func recordSearch(on day: String) -> Int { counts[day, default: 0] += 1; return counts[day]! }
    func lastForm() -> PlanFormSnapshot? { form }
    func saveForm(_ form: PlanFormSnapshot) { self.form = form }
}
