import SwiftUI

struct FavoritesSection: View {
    let favoriteStops: [Stop]
    let dependencies: AppDependencies

    var body: some View {
        VStack(alignment: .leading) {
            Text("Your Favorites")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(favoriteStops, id: \.stopId) { stop in
                        NavigationLink(destination: StopDetailView(viewModel: StopDetailViewModel(stop: stop, getArrivalsUseCase: dependencies.getArrivalsUseCase))) {
                            FavoriteStopCard(stop: stop) // TODO: Pass actual next arrival time
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    let sampleStops = [
        Stop(stopId: "1", stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP1", wheelchairBoarding: 0),
        Stop(stopId: "2", stopName: "Rua Augusta, 500", location: Location(latitude: -23.560000, longitude: -46.650000), stopSequence: 2, stopCode: "SP2", wheelchairBoarding: 0),
        Stop(stopId: "3", stopName: "Metro Consolação", location: Location(latitude: -23.553000, longitude: -46.660000), stopSequence: 3, stopCode: "SP3", wheelchairBoarding: 0)
    ]
    return ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        FavoritesSection(favoriteStops: sampleStops, dependencies: AppDependencies())
    }
}
