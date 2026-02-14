import SwiftUI

struct StopAnnotation: View {
    let stop: Stop

    private var iconName: String {
        switch stop.transportType {
        case .bus:
            return "bus.fill"
        case .metro:
            return "tram.fill"
        case .train:
            return "train.side.front.car"
        }
    }

    private var iconColor: Color {
        switch stop.transportType {
        case .bus:
            return AppColors.accent.opacity(0.8)
        case .metro:
            return AppColors.metroL1Azul.opacity(0.8)
        case .train:
            return AppColors.metroL5Lilas.opacity(0.8)
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.callout)
            .foregroundColor(.white)
            .padding(6)
            .background(iconColor)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            .accessibilityLabel(Text(stop.stopName))
    }
}

#Preview {
    StopAnnotation(stop: Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, routes: "METRÔ", stopCode: "SP1", wheelchairBoarding: 0))
}
