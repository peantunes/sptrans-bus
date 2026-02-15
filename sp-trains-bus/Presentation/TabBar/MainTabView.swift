import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies
    
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
                    MapExplorerView(viewModel: dependencies.mapExplorerViewModel, dependencies: dependencies) // Assuming MapExplorerViewModel exists in dependencies
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
                    SystemStatusView(viewModel: dependencies.systemStatusViewModel)
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
    MainTabView(dependencies: AppDependencies())
}
