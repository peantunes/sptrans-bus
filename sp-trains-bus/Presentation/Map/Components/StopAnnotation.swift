import SwiftUI

struct StopAnnotation: View {
    let stop: Stop

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "bus.fill")
                .font(.callout)
                .foregroundColor(.white)
                .padding(6)
                .background(Color.blue)
                .clipShape(Circle())

            Text(stop.stopName)
                .font(.caption2)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
                .background(.white.opacity(0.8))
                .cornerRadius(5)
        }
    }
}

#Preview {
    StopAnnotation(stop: Stop(stopId: "1", stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP1", wheelchairBoarding: 0))
}
