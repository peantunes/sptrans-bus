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

            Tab("Map", systemImage: "map.fill", value: .map, role: .search) {
                NavigationStack {
                    MapExplorerView(viewModel: dependencies.mapExplorerViewModel, dependencies: dependencies) // Assuming MapExplorerViewModel exists in dependencies
                }
            }

            if FeatureToggles.isSearchEnabled {
                Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                    NavigationStack {
                        SearchView(viewModel: dependencies.searchViewModel, dependencies: dependencies)
                    }
                }
            }
            
            Tab("Status", systemImage: "tram", value: .status) {
                NavigationStack {
                    SystemStatusView(viewModel: dependencies.systemStatusViewModel)
                }
            }

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                NavigationStack {
                    GeneralSettingsView()
                }
            }

        }
    }
}

#Preview {
    MainTabView(dependencies: AppDependencies())
}
