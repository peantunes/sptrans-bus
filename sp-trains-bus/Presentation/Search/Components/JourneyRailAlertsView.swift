import SwiftUI

struct JourneyRailAlertsView: View {
    let alerts: [JourneyRailLineStatus]
    var compact = false
    var unavailable = false
    var refreshFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(alerts) { alert in
                VStack(alignment: .leading, spacing: 5) {
                    Label(alert.title, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                    Text(alert.status).font(.subheadline)
                    if !compact {
                        if !alert.detail.isEmpty { Text(alert.detail).font(.caption) }
                        if let updated = alert.updatedAt {
                            Text("Source updated: \(updated) (São Paulo)").font(.caption2)
                        }
                    }
                    if refreshFailed || alert.isStale() {
                        Text("Last known status · may be outdated").font(.caption.weight(.medium))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }
            if unavailable {
                Label("Current rail status could not be confirmed for this journey.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !alerts.isEmpty && !compact {
                Text("Latest reported line conditions. Recheck before departure; journey times do not include disruption delays.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct JourneyCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }
}
