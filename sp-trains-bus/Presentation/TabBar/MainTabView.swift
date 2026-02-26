import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies
    @ObservedObject var navigationCoordinator: AppNavigationCoordinator
    
    enum TabOption: String {
        case home
        case nearby
        case search
        case status
        case map
        case settings
    }

    @AppStorage("main_tab_selection") private var storedTabSelection: String = TabOption.map.rawValue
    @State private var hasTrackedInitialTabSelection = false

    private var tabSelectionBinding: Binding<TabOption> {
        Binding(
            get: {
                guard let stored = TabOption(rawValue: storedTabSelection) else {
                    return .map
                }
                if stored == .search && !FeatureToggles.isSearchEnabled {
                    return .map
                }
                return stored
            },
            set: { newValue in
                storedTabSelection = newValue.rawValue
            }
        )
    }

    init(dependencies: AppDependencies, navigationCoordinator: AppNavigationCoordinator) {
        self.dependencies = dependencies
        self.navigationCoordinator = navigationCoordinator
    }

    var body: some View {
        TabView(selection: tabSelectionBinding) {
//            Tab("Home", systemImage: "house.fill", value: .home){
//                HomeView(
//                    viewModel: dependencies.homeViewModel,
//                    dependencies: dependencies,
//                    onOpenMap: { tabSelection = .map },
//                    onOpenStatus: { tabSelection = .status }
//                )
//            }

            Tab(localized("tab.map"), systemImage: "map.fill", value: .map, role: .search) {
                NavigationStack {
                    MapExplorerView(
                        viewModel: dependencies.mapExplorerViewModel,
                        dependencies: dependencies,
                        navigationCoordinator: navigationCoordinator
                    )
                }
            }

            if FeatureToggles.isSearchEnabled {
                Tab(localized("tab.search"), systemImage: "magnifyingglass", value: .search, role: .search) {
                    NavigationStack {
                        SearchView(viewModel: dependencies.searchViewModel, dependencies: dependencies)
                    }
                }
            }
            
            Tab(localized("tab.status"), systemImage: "tram", value: .status) {
                NavigationStack {
                    SystemStatusView(
                        viewModel: dependencies.systemStatusViewModel,
                        navigationCoordinator: navigationCoordinator
                    )
                }
            }

            Tab(localized("tab.settings"), systemImage: "gearshape.fill", value: .settings) {
                NavigationStack {
                    GeneralSettingsView(analyticsService: dependencies.analyticsService)
                }
            }

        }
        .onAppear {
            trackTabSelection(for: storedTabSelection, trigger: "initial")
        }
        .onChange(of: storedTabSelection) { _, newValue in
            trackTabSelection(for: newValue, trigger: "change")
        }
        .onChange(of: navigationCoordinator.pendingTabRawValue) { _, _ in
            guard let pendingTab = navigationCoordinator.consumePendingTab() else { return }
            guard let tab = TabOption(rawValue: pendingTab) else { return }
            if tab == .search && !FeatureToggles.isSearchEnabled {
                storedTabSelection = TabOption.map.rawValue
                return
            }
            storedTabSelection = tab.rawValue
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func trackTabSelection(for rawValue: String, trigger: String) {
        guard let tab = TabOption(rawValue: rawValue) else { return }

        if trigger == "initial" {
            guard !hasTrackedInitialTabSelection else { return }
            hasTrackedInitialTabSelection = true
        }

        dependencies.analyticsService.trackEvent(
            name: "tab_selected",
            properties: [
                "tab": tab.rawValue,
                "trigger": trigger
            ]
        )
    }
}

#Preview {
    MainTabView(
        dependencies: AppDependencies(),
        navigationCoordinator: AppNavigationCoordinator()
    )
}
