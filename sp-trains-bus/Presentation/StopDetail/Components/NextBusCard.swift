import SwiftUI

struct NextBusCard: View {
    let arrival: Arrival
    let routeColorString: String
    let routeTextColorString: String

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading) {
                    Text(arrival.stopHeadsign)
                        .font(AppFonts.title2())
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.text)

                    HStack {
                        RouteBadge(routeShortName: arrival.id.uuidString, routeColor: routeColorString, routeTextColor: routeTextColorString) // Placeholder colors
                        Text("Arrives in")
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.text.opacity(0.8))
                    }
                }
                Spacer()
                CountdownTimer(seconds: arrival.waitTime) // Assuming waitTime is in seconds for now
                    .font(AppFonts.largeTitle())
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.accent)
            }
        }
    }
}

//#Preview {
//    let sampleArrival = Arrival(tripId: "123", arrivalTime: "10:30", departureTime: "10:30", stopId: 1, stopSequence: 1, stopHeadsign: "Terminal Bandeira", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", waitTime: 300)
//    return ZStack {
//        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
//            .ignoresSafeArea()
//        NextBusCard(arrival: sampleArrival)
//    }
//}
