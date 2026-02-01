import SwiftUI

struct FavoriteStopCard: View {
    let stop: Stop
    var nextArrivalTime: String? // Placeholder for next arrival info

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(stop.stopName)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                if let nextArrivalTime = nextArrivalTime {
                    Text("Next: \(nextArrivalTime)")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.8))
                } else {
                    Text("No upcoming arrivals")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.6))
                }
            }
            .frame(width: 150, alignment: .leading) // Fixed width for horizontal scrolling
        }
    }
}

#Preview {
    let sampleStop = Stop(stopId: "1", stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP", wheelchairBoarding: 0)
    return ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        FavoriteStopCard(stop: sampleStop, nextArrivalTime: "5 min")
    }
}
