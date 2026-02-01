import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            HomeView(viewModel: dependencies.homeViewModel, dependencies: dependencies)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // Placeholder for NearbyView
            Text("Nearby View")
                .tabItem {
                    Label("Nearby", systemImage: "location.fill")
                }

            SearchView(viewModel: dependencies.searchViewModel, dependencies: dependencies) // Assuming SearchViewModel exists in dependencies
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            SystemStatusView(viewModel: dependencies.systemStatusViewModel) // Assuming SystemStatusViewModel exists in dependencies
                .tabItem {
                    Label("Status", systemImage: "waveform.path.ecg")
                }

            MapExplorerView(viewModel: dependencies.mapExplorerViewModel, dependencies: dependencies) // Assuming MapExplorerViewModel exists in dependencies
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
        }
    }
}

#Preview {
    MainTabView(dependencies: AppDependencies())
}
