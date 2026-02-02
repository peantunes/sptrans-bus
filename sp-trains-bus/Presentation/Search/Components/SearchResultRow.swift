import SwiftUI

struct SearchResultRow: View {
    let stop: Stop
    var distance: Double? // Distance in meters, if available

    var body: some View {
        HStack {
            Image(systemName: "bus.fill")
                .foregroundColor(AppColors.accent)
                .font(.body)
            VStack(alignment: .leading) {
                Text(stop.stopName)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)
                if !stop.stopCode.isEmpty {
                    Text(stop.stopCode)
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.8))
                }
            }
            Spacer()
            if let distance = distance {
                Text(String(format: "%.0f m", distance))
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.text.opacity(0.6))
            }
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    let sampleStop = Stop(stopId: 1, stopName: "Av. Paulista, 1000", location: Location(latitude: -23.561414, longitude: -46.656166), stopSequence: 1, stopCode: "SP-1234", wheelchairBoarding: 0)
    return SearchResultRow(stop: sampleStop, distance: 150.5)
        .padding()
}
