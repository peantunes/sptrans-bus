import SwiftUI

struct MetroLineCard: View {
    let line: RailLineStatusItem

    private var statusColor: Color {
        let providedHex = line.statusColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !providedHex.isEmpty {
            return Color(hex: providedHex)
        }

        switch line.severity {
        case .normal:
            return AppColors.statusNormal
        case .warning:
            return AppColors.statusWarning
        case .alert:
            return AppColors.statusAlert
        }
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: line.lineColorHex))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text(line.badgeText)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(line.displayTitle)
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Text(line.status)
                        .font(AppFonts.subheadline())
                        .foregroundColor(statusColor)

                    Text(line.detailText)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    let sample = RailLineStatusItem(
        id: "metro-1-azul",
        source: "metro",
        lineNumber: "1",
        lineName: "Azul",
        status: "Operação Normal",
        statusDetail: "Situação Normal",
        statusColorHex: "00E000",
        lineColorHex: "0455A1",
        sourceUpdatedAt: "2026-02-14 14:06:09",
        severity: .normal
    )

    return ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        MetroLineCard(line: sample)
    }
}
