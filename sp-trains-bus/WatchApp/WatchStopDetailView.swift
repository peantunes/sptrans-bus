#if os(watchOS)
import SwiftUI
import WatchKit

struct WatchStopDetailView: View {
    let stop: WatchStopSnapshot
    let arrivals: [WatchArrivalSnapshot]

    var body: some View {
        List {
            Section("Stop") {
                Text(stop.stopName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(3)
                if !stop.stopCode.isEmpty {
                    Text("Code: \(stop.stopCode)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let routes = stop.routes, !routes.isEmpty {
                    Text(routes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Section("Arrivals") {
                if arrivals.isEmpty {
                    Text("No arrival data yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(arrivals.prefix(8)) { arrival in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(arrival.routeShortName)
                                    .font(.caption.weight(.semibold))
                                Text(arrival.headsign)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(waitText(for: arrival.waitTime))
                                .font(.caption.weight(.bold))
                        }
                    }
                }
            }

            Section {
                Button("Open on iPhone") {
                    guard let url = AppDeepLinkBuilder.stopDetail(stop: stop) else { return }
                    WKExtension.shared().openSystemURL(url)
                }
            }
        }
        .navigationTitle("Stop")
    }

    private func waitText(for waitMinutes: Int) -> String {
        if waitMinutes <= 0 {
            return "Now"
        }
        if waitMinutes == 1 {
            return "1 min"
        }
        return "\(waitMinutes) min"
    }
}
#endif
