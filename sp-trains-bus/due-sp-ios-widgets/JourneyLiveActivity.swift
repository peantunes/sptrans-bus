import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity of a tracked journey (app: JourneyTracker). Tapping it opens the journey in the app.
struct JourneyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JourneyActivityAttributes.self) { context in
            JourneyLockScreenView(attributes: context.attributes, state: context.state)
                .padding(16)
                .activityBackgroundTint(Color(red: 0.05, green: 0.13, blue: 0.25).opacity(0.92))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "duesp://journey"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    JourneyLineBadge(state: context.state).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    JourneyCountdown(state: context.state).font(.title3.weight(.bold))
                        .frame(maxWidth: 72, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        JourneyStepsBar(state: context.state)
                        if !context.state.alternatives.isEmpty {
                            JourneyAlternativesRow(state: context.state)
                        }
                    }
                }
            } compactLeading: {
                JourneyLineBadge(state: context.state, compact: true)
            } compactTrailing: {
                JourneyCountdown(state: context.state).font(.caption.weight(.bold)).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: context.state.modeSymbol)
            }
            .widgetURL(URL(string: "duesp://journey"))
        }
    }
}

private struct JourneyLockScreenView: View {
    let attributes: JourneyActivityAttributes
    let state: JourneyActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                JourneyLineBadge(state: state)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title).font(.headline).foregroundStyle(.white).lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(state.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    if state.phase != .arrived {
                        Text("Next in").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                    }
                    JourneyCountdown(state: state).font(.title2.weight(.bold)).foregroundStyle(.white)
                    if state.usesLocation {
                        Label("GPS", systemImage: "location.fill").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 78, alignment: .trailing)
            }
            JourneyStepsBar(state: state)
            HStack {
                Text("\(attributes.from) → \(attributes.to)").lineLimit(1)
                Spacer()
                Text(state.arrivalDate, format: saoPauloTime)
            }
            .font(.caption).foregroundStyle(.white.opacity(0.7))
            if !state.alternatives.isEmpty {
                JourneyAlternativesRow(state: state)
            }
        }
    }
}

/// Line badge (or the walking / arrived icon), with readable text on the line colour.
private struct JourneyLineBadge: View {
    let state: JourneyActivityAttributes.ContentState
    var compact = false

    var body: some View {
        if let name = state.lineName {
            let fill = Color(hexString: state.lineColorHex) ?? .blue
            HStack(spacing: 4) {
                Image(systemName: state.modeSymbol)
                if !compact { Text(name).lineLimit(1) }
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, compact ? 5 : 8).padding(.vertical, 4)
            .foregroundStyle(readableText(on: state.lineColorHex))
            .background(fill, in: RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: state.modeSymbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.18), in: Circle())
        }
    }
}

private struct JourneyCountdown: View {
    let state: JourneyActivityAttributes.ContentState

    var body: some View {
        if state.phase == .arrived {
            Image(systemName: "checkmark.circle.fill")
        } else if state.nextEventDate > Date() {
            Text(timerInterval: Date()...state.nextEventDate, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("now")
        }
    }
}

/// One segment per step of the journey, filled up to the current one.
private struct JourneyStepsBar: View {
    let state: JourneyActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(state.stepCount, 1), id: \.self) { index in
                Capsule()
                    .fill(index < state.stepIndex || state.phase == .arrived ? Color.white
                          : index == state.stepIndex ? Color.white.opacity(0.7) : Color.white.opacity(0.22))
                    .frame(height: 5)
            }
        }
    }
}

private struct JourneyAlternativesRow: View {
    let state: JourneyActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            Text("Also from here:").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
            ForEach(state.alternatives, id: \.self) { option in
                HStack(spacing: 3) {
                    Text(option.lineName).font(.caption2.weight(.bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .foregroundStyle(readableText(on: option.lineColorHex))
                        .background(Color(hexString: option.lineColorHex) ?? .gray, in: RoundedRectangle(cornerRadius: 4))
                    Text("\(option.minutes) min").font(.caption2).foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .lineLimit(1)
    }
}

/// Journey times are shown in São Paulo time, as in the app, whatever the device time zone.
private let saoPauloTime = Date.FormatStyle(
    date: .omitted,
    time: .shortened,
    timeZone: TimeZone(identifier: "America/Sao_Paulo") ?? .current
)

/// White or near-black text, whichever reads better on the line colour (WCAG contrast).
private func readableText(on hex: String?) -> Color {
    guard let rgb = rgbComponents(hex) else { return .white }
    func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    let luminance = 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
    let withWhite = 1.05 / (luminance + 0.05)
    let withDark = (luminance + 0.05) / (0.0119 + 0.05)
    return withDark >= withWhite ? Color(white: 0.11) : .white
}

private func rgbComponents(_ hex: String?) -> (Double, Double, Double)? {
    guard var value = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.count == 6, let int = UInt32(value, radix: 16) else { return nil }
    return (Double((int >> 16) & 0xFF) / 255, Double((int >> 8) & 0xFF) / 255, Double(int & 0xFF) / 255)
}

private extension Color {
    init?(hexString: String?) {
        guard let rgb = rgbComponents(hexString) else { return nil }
        self.init(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}
