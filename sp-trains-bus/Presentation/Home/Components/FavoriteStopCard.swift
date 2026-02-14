import SwiftUI

struct FavoriteStopCard: View {
    let stop: Stop
    var nextArrivalTime: String? // Placeholder for next arrival info

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(6)
                        .background(AppColors.primary.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(stop.stopName)
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.text)
                            .lineLimit(2)

                        if !stop.stopCode.isEmpty {
                            Text("#\(stop.stopCode)")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.6))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.text.opacity(0.4))
                }

                if let nextArrivalTime = nextArrivalTime {
                    Text("Next arrival: \(nextArrivalTime)")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.8))
                } else {
                    Text("Tap to view arrivals")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.6))
                }
            }
            .frame(width: 190, alignment: .leading)
        }
    }
}

#Preview {
    let sampleStop = Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, routes: "METRÔ", stopCode: "SP", wheelchairBoarding: 0)
    return ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        FavoriteStopCard(stop: sampleStop, nextArrivalTime: "5 min")
    }
}
