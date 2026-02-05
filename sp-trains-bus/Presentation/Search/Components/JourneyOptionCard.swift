import SwiftUI

struct JourneyOptionCard: View {
    let alternative: TripPlanAlternative

    private var departureText: String {
        alternative.departureTime ?? "--:--"
    }

    private var arrivalText: String {
        alternative.arrivalTime ?? "--:--"
    }

    private var legText: String {
        let count = alternative.legCount
        return count == 1 ? "1 leg" : "\(count) legs"
    }

    private var stopText: String {
        if let stopCount = alternative.stopCount {
            return stopCount == 1 ? "1 stop" : "\(stopCount) stops"
        }
        return "-- stops"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(departureText)
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.text.opacity(0.6))

                    Text(arrivalText)
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Spacer()

                    Text(legText)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.text.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    Label(stopText, systemImage: "signpost.right.fill")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))

                    if !alternative.lineSummary.isEmpty {
                        Text(alternative.lineSummary)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text)
                            .monospaced()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

//#Preview {
//    JourneyOptionCard(
//        alternative: TripPlanAlternative(
//            type: .transfer,
//            departureTime: "08:10",
//            arrivalTime: "09:02",
//            legCount: 2,
//            stopCount: 18,
//            lineSummary: "1080-0 > 9033-1"
//        )
//    )
//    .padding()
//}
