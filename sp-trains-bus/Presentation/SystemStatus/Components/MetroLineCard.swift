import SwiftUI

struct MetroLineCard: View {
    let line: RailLineStatusItem
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

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

    private var updatedText: String {
        if let sourceUpdatedAt = line.sourceUpdatedAt, !sourceUpdatedAt.isEmpty {
            return "Atualizado: \(sourceUpdatedAt)"
        }
        return "Atualizado: agora"
    }

    var body: some View {
        let lineColor = Color(hex: line.lineColorHex)
        let statusColor = Color(hex: line.statusColorHex)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(lineColor)
                    .frame(width: 46, height: 32)
                    .overlay(
                        Text(line.badgeText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(line.displayTitle)
                    .font(AppFonts.title3().bold())
                    .foregroundColor(AppColors.text)

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.headline)
                        .foregroundColor(isFavorite ? .yellow : AppColors.text.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            let shadowColor = Color.secondary
            let change: CGFloat = 0.3
            let radius: CGFloat = 0.5
            Text(line.status)
                .font(AppFonts.body())
                .fontWeight(.bold)
                .foregroundColor(statusColor)
                .shadow(color: shadowColor, radius: radius, x: change, y: change)
                .shadow(color: shadowColor, radius: radius, x: -change, y: -change)
                .shadow(color: shadowColor, radius: radius, x: -change, y: change)
                .shadow(color: shadowColor, radius: radius, x: change, y: -change)

            Text(line.detailText)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.82))
                .lineLimit(2)

            Text(updatedText)
                .font(AppFonts.caption2())
                .foregroundColor(AppColors.text.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(lineColor.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineColor.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: lineColor.opacity(0.2), radius: 8, x: 0, y: 4)
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
        sourceUpdatedAt: "14/02 14:06",
        severity: .normal
    )

    return ZStack {
//        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
//            .ignoresSafeArea()
        MetroLineCard(
            line: sample,
            isFavorite: true,
            onToggleFavorite: {}
        )
        .padding()
    }
}
