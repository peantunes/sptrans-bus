import SwiftUI

struct UpcomingBusList: View {
    let arrivals: [Arrival]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming Arrivals")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)
                .padding(.horizontal)

            if arrivals.isEmpty {
                Text("No upcoming arrivals at this stop.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.text.opacity(0.7))
                    .padding(.horizontal)
            } else {
                ForEach(arrivals.dropFirst()) { arrival in // Skip the first one as it's in NextBusCard
                    GlassCard {
                        HStack {
                            RouteBadge(routeShortName: arrival.id.uuidString, routeColor: arrival.stopId, routeTextColor: "FFFFFF") // Placeholder colors
                            VStack(alignment: .leading) {
                                Text(arrival.stopHeadsign)
                                    .font(AppFonts.subheadline())
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.text)
                                Text("Arrives at \(arrival.arrivalTime)")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.text.opacity(0.7))
                            }
                            Spacer()
                            Text("\(arrival.waitTime) min")
                                .font(AppFonts.subheadline())
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

//#Preview {
//    let sampleArrivals = [
//        Arrival(tripId: "123", arrivalTime: "10:30", departureTime: "10:30", stopId: 1, stopSequence: 1, stopHeadsign: "Terminal Bandeira", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", waitTime: 5),
//        Arrival(tripId: "124", arrivalTime: "10:45", departureTime: "10:45", stopId: 1, stopSequence: 2, stopHeadsign: "Jardim Paulista", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", waitTime: 20),
//        Arrival(tripId: "125", arrivalTime: "11:00", departureTime: "11:00", stopId: 1, stopSequence: 3, stopHeadsign: "Parque Ibirapuera", pickupType: 0, dropOffType: 0, shapeDistTraveled: "", waitTime: 35)
//    ]
//    return ZStack {
//        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
//            .ignoresSafeArea()
//        UpcomingBusList(arrivals: sampleArrivals)
//    }
//}
