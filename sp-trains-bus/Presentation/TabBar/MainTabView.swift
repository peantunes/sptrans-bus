import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies
    
    enum TabOption {
        case home
        case nearby
        case search
        case status
        case map
    }
    
    @State private var tabSelection: TabOption = .home

    var body: some View {
        TabView(selection: $tabSelection) {
            Tab("Home", systemImage: "house.fill", value: .home){
                HomeView(
                    viewModel: dependencies.homeViewModel,
                    dependencies: dependencies,
                    onOpenMap: { tabSelection = .map },
                    onOpenStatus: { tabSelection = .status }
                )
            }

            // Placeholder for NearbyView
            Tab("Nearby", systemImage: "location.fill", value: .nearby) {
                Text("Nearby View")
            }
            
            Tab("Status", systemImage: "waveform.path.ecg", value: .status) {
                SystemStatusView(viewModel: dependencies.systemStatusViewModel) // Assuming SystemStatusViewModel exists in dependencies
            }

            Tab("Map", systemImage: "map.fill", value: .map) {
                MapExplorerView(viewModel: dependencies.mapExplorerViewModel, dependencies: dependencies) // Assuming MapExplorerViewModel exists in dependencies
            }
            
            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView(viewModel: dependencies.searchViewModel, dependencies: dependencies) // Assuming SearchViewModel exists in dependencies
            }

        }
    }
}

#Preview {
    MainTabView(dependencies: AppDependencies())
}
