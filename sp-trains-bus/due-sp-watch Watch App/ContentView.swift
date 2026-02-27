import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var viewModel = WatchTransitViewModel()

    var body: some View {
        NavigationStack {
            TabView {
                List {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    linesSection
                }
                List {
                    nearbyStopsSection
                }
            }
            .navigationTitle("Due SP")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    private var linesSection: some View {
        Section("Lines") {
            if viewModel.favoriteLinesFirst.isEmpty {
                Text("No line status yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.favoriteLinesFirst.prefix(8)) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("L\(line.lineNumber)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colorFromHex(line.lineColorHex).opacity(0.25))
                                .clipShape(Capsule())
                            if line.isFavorite {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption2)
                            }
                            Spacer()
                        }

                        Text(line.lineName.isEmpty ? line.source.uppercased() : line.lineName)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)

                        Text(line.status)
                            .font(.caption2)
                            .foregroundStyle(colorFromHex(line.statusColorHex))
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openOnIPhone(url: WatchDeepLink.status(lineID: line.id))
                    }
                }
            }
        }
    }

    private var nearbyStopsSection: some View {
        Section("Nearby Stops") {
            if viewModel.snapshot.nearbyStops.isEmpty {
                Text("No nearby stops yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.snapshot.nearbyStops.prefix(4)) { stop in
                    NavigationLink {
                        WatchStopDetailView(
                            stop: stop,
                            arrivals: viewModel.arrivals(for: stop)
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.stopName)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(2)
                            if let distance = stop.distanceMeters {
                                Text("\(distance)m")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func openOnIPhone(url: URL?) {
        guard let url else { return }
        WKExtension.shared().openSystemURL(url)
    }

    private func colorFromHex(_ rawHex: String) -> Color {
        let hex = rawHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let r: Double
        let g: Double
        let b: Double

        switch hex.count {
        case 3:
            r = Double((value >> 8) & 0xF) / 15.0
            g = Double((value >> 4) & 0xF) / 15.0
            b = Double(value & 0xF) / 15.0
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        default:
            return .gray
        }

        return Color(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
