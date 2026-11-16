//
//  ClipJourneyView.swift
//  DueSPClip
//
//  The shared journey in the App Clip: same look as the app's journey detail (summary card, one card
//  per leg with every stop, dashed walking blocks, readable line colours), self-contained so the clip
//  stays small.
//

import SwiftUI
import StoreKit

// MARK: - Data

struct ClipSharedJourney: Decodable {
    struct Journey: Decodable {
        let summary: Summary
        let segments: [Segment]
    }

    struct Summary: Decodable {
        let departureTime: String?
        let arrivalTime: String?
        let transferCount: Int?
        let durationMinutes: Int?
        let walkMinutes: Int?
    }

    struct Place: Decodable {
        let name: String?
        let time: String?
    }

    struct Route: Decodable {
        let shortName: String?
        let longName: String?
        let color: String?
        let textColor: String?
    }

    struct Segment: Decodable {
        let type: String
        let mode: String?
        let route: Route?
        let headsign: String?
        let from: Place?
        let to: Place?
        let originStop: Place?
        let destinationStop: Place?
        let departureTime: String?
        let arrivalTime: String?
        let durationMinutes: Int?
        let distanceMeters: Int?
        let headwayMinutes: Int?
        let intermediateStops: [Place]?
    }

    struct Live: Decodable {
        let legs: [String: LineStatus]
    }

    struct LineStatus: Decodable {
        let lineName: String?
        let status: String?
        let level: String?
        let detail: String?
    }

    let token: String
    let url: String
    let from: String
    let to: String
    let state: String
    let departsAt: TimeInterval?
    let journey: Journey
    let live: Live?
}

struct ClipShareClient {
    enum Failure: Error, Equatable { case notFound, unavailable }

    static func token(from url: URL) -> String? {
        guard url.host?.lowercased() == "sptrans.lolados.app" else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count == 2, parts[0] == "j", parts[1].count == 12,
              parts[1].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return String(parts[1])
    }

    func load(token: String) async throws -> ClipSharedJourney {
        var components = URLComponents(string: "https://sptrans.lolados.app/api/share.php")!
        components.queryItems = [URLQueryItem(name: "t", value: token)]
        do {
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 { throw Failure.notFound }
            guard (200...299).contains(status) else { throw Failure.unavailable }
            return try JSONDecoder().decode(ClipSharedJourney.self, from: data)
        } catch let failure as Failure {
            throw failure
        } catch {
            throw Failure.unavailable
        }
    }
}

// MARK: - Root

struct ClipRootView: View {
    @ObservedObject var model: ClipModel
    @State private var showsAppOverlay = false

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .empty:
                    ContentUnavailableView("Due SP", systemImage: "bus.fill",
                        description: Text("Abra um link de viagem compartilhada para ver o trajeto aqui."))
                case .loading:
                    ProgressView("Carregando viagem…")
                case .failed(let notFound):
                    ContentUnavailableView {
                        Label("Viagem compartilhada", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    } description: {
                        Text(notFound ? "Esta viagem não está mais disponível." : "Não foi possível carregar a viagem agora.")
                    } actions: {
                        if !notFound { Button("Tentar de novo") { Task { await model.refresh() } } }
                    }
                case .loaded(let shared):
                    ClipJourneyView(shared: shared)
                        .task { await model.keepRefreshing() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Viagem")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .appStoreOverlay(isPresented: $showsAppOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showsAppOverlay = true
        }
    }
}

// MARK: - Journey

struct ClipJourneyView: View {
    let shared: ClipSharedJourney

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summary
                ForEach(Array(shared.journey.segments.enumerated()), id: \.offset) { index, segment in
                    if segment.type == "walk" {
                        ClipWalkBlock(segment: segment)
                    } else {
                        ClipLegCard(segment: segment, live: shared.live?.legs[String(index)])
                    }
                }
                Text("Horários estimados pela tabela da SPTrans · horário de São Paulo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            // Room for the App Store overlay, so it never hides the last stops.
            .padding(.bottom, 110)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Viagem compartilhada").font(.caption.weight(.semibold)).textCase(.uppercase).opacity(0.8)
                Spacer()
                Text(stateLabel).font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(shared.state == "travelling" ? Color.green : Color.white.opacity(0.16), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(shared.from).font(.title2.bold())
                Image(systemName: "arrow.down").opacity(0.7)
                Text(shared.to).font(.title2.bold())
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Partida").font(.caption).opacity(0.8)
                    Text(clock(shared.journey.summary.departureTime)).font(.largeTitle.bold()).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Chegada").font(.caption).opacity(0.8)
                    Text(clock(shared.journey.summary.arrivalTime)).font(.largeTitle.bold()).monospacedDigit()
                }
            }
            Text(facts).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.06, green: 0.16, blue: 0.31), Color(red: 0.04, green: 0.12, blue: 0.23)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }

    private var stateLabel: String {
        switch shared.state {
        case "travelling": return "Em andamento"
        case "completed": return "Concluída"
        default: return "Em breve"
        }
    }

    private var facts: String {
        let transfers = shared.journey.summary.transferCount ?? 0
        var parts = [transfers == 0 ? "Sem baldeação" : transfers == 1 ? "1 baldeação" : "\(transfers) baldeações"]
        if let minutes = shared.journey.summary.durationMinutes { parts.append(clipDuration(minutes)) }
        return parts.joined(separator: " · ")
    }
}

private func clock(_ time: String?) -> String {
    guard let time else { return "--:--" }
    let parts = time.split(separator: ":")
    guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return time }
    return String(format: "%02d:%02d", hour % 24, minute)
}

private func clipDuration(_ minutes: Int) -> String {
    minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h" + (minutes % 60 == 0 ? "" : " \(minutes % 60) min")
}

struct ClipLegCard: View {
    let segment: ClipSharedJourney.Segment
    let live: ClipSharedJourney.LineStatus?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = ClipPalette(fillHex: segment.route?.color, textHex: segment.route?.textColor, dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(segment.route?.shortName ?? "Linha", systemImage: icon)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .foregroundStyle(palette.onFill)
                        .background(palette.fill, in: RoundedRectangle(cornerRadius: 6))
                    if let name = segment.route?.longName, !name.isEmpty { Text(name).font(.headline) }
                    Text([segment.headsign.map { "sentido \($0)" }, segment.durationMinutes.map(clipDuration)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let headway = segment.headwayMinutes {
                    Text("a cada \(headway) min").font(.caption.weight(.semibold)).foregroundStyle(palette.text)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(palette.stroke.opacity(0.14), in: Capsule())
                }
            }
            if let live, let status = live.status {
                Label(status, systemImage: "circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(live.level == "normal" ? Color.green : live.level == "warning" ? Color.orange : Color.red)
            }
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                let stops = [ClipSharedJourney.Place(name: segment.originStop?.name, time: segment.departureTime)]
                    + (segment.intermediateStops ?? [])
                    + [ClipSharedJourney.Place(name: segment.destinationStop?.name, time: segment.arrivalTime)]
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    ClipStopRow(stop: stop, caption: index == 0 ? "EMBARQUE AQUI" : index == stops.count - 1 ? "DESÇA AQUI" : nil,
                                isFirst: index == 0, isLast: index == stops.count - 1, palette: palette)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    private var icon: String {
        switch segment.mode {
        case "metro": return "tram.fill"
        case "rail": return "train.side.front.car"
        default: return "bus.fill"
        }
    }
}

struct ClipStopRow: View {
    let stop: ClipSharedJourney.Place
    let caption: String?
    let isFirst: Bool
    let isLast: Bool
    let palette: ClipPalette

    var body: some View {
        let major = caption != nil
        HStack(alignment: .top, spacing: 12) {
            Text(clock(stop.time))
                .font(major ? .title3.weight(.bold).monospacedDigit() : .subheadline.monospacedDigit())
                .foregroundStyle(major ? .primary : .secondary)
                .frame(width: 58, alignment: .trailing)
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? .clear : palette.stroke.opacity(0.45)).frame(width: 4, height: major ? 4 : 6)
                Circle().strokeBorder(palette.stroke, lineWidth: major ? 5 : 3.5)
                    .background(Circle().fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    .frame(width: major ? 22 : 14, height: major ? 22 : 14)
                Rectangle().fill(isLast ? .clear : palette.stroke.opacity(0.45)).frame(width: 4).frame(maxHeight: .infinity)
            }
            .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name ?? "").font(major ? .headline : .subheadline)
                if let caption { Text(caption).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(palette.text) }
            }
            .padding(.bottom, isLast ? 0 : (major ? 18 : 12))
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ClipWalkBlock: View {
    let segment: ClipSharedJourney.Segment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk").font(.headline).foregroundStyle(.blue)
            Text(clock(segment.departureTime)).font(.headline.monospacedDigit())
            VStack(alignment: .leading, spacing: 2) {
                Text("Caminhe \(segment.durationMinutes ?? 1) min até \(segment.to?.name ?? "a próxima parada")")
                    .font(.subheadline.weight(.medium))
                if let meters = segment.distanceMeters { Text("\(meters) m").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
    }
}

/// Line colours made readable (same WCAG rules as the app's LineColor).
struct ClipPalette {
    let fill: Color
    let onFill: Color
    let text: Color
    let stroke: Color

    init(fillHex: String?, textHex: String?, dark: Bool) {
        let fillRGB = Self.rgb(fillHex) ?? (0.12, 0.44, 0.92)
        let surface: (Double, Double, Double) = dark ? (0.11, 0.11, 0.118) : (1, 1, 1)
        fill = Self.color(fillRGB)
        let preferred = Self.rgb(textHex)
        if let preferred, Self.contrast(fillRGB, preferred) >= 4.5 {
            onFill = Self.color(preferred)
        } else {
            onFill = Self.contrast(fillRGB, (0.11, 0.11, 0.118)) >= Self.contrast(fillRGB, (1, 1, 1)) ? Color(white: 0.11) : .white
        }
        text = Self.color(Self.readable(fillRGB, on: surface, minimum: 4.5))
        stroke = Self.color(Self.readable(fillRGB, on: surface, minimum: 3))
    }

    private typealias RGB = (Double, Double, Double)

    private static func rgb(_ hex: String?) -> RGB? {
        guard var value = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = UInt32(value, radix: 16) else { return nil }
        return (Double((int >> 16) & 0xFF) / 255, Double((int >> 8) & 0xFF) / 255, Double(int & 0xFF) / 255)
    }

    private static func luminance(_ c: RGB) -> Double {
        func f(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.0) + 0.7152 * f(c.1) + 0.0722 * f(c.2)
    }

    private static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func readable(_ line: RGB, on surface: RGB, minimum: Double) -> RGB {
        if contrast(line, surface) >= minimum { return line }
        let target: RGB = luminance(surface) > 0.5 ? (0, 0, 0) : (1, 1, 1)
        var mixed = line
        for step in 1...20 {
            let t = Double(step) / 20
            mixed = (line.0 + (target.0 - line.0) * t, line.1 + (target.1 - line.1) * t, line.2 + (target.2 - line.2) * t)
            if contrast(mixed, surface) >= minimum { break }
        }
        return mixed
    }

    private static func color(_ c: RGB) -> Color { Color(red: c.0, green: c.1, blue: c.2) }
}
