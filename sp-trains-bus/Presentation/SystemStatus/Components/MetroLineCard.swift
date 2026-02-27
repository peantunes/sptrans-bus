import SwiftUI

struct MetroLineCard: View {
    let line: RailLineStatusItem
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    @State private var isShowingDetailSheet = false

    private var statusStyle: RailStatusVisualStyle {
        RailStatusVisualStyle.styleFor(line.severity)
    }

    private var updatedText: String {
        if let sourceUpdatedAt = line.sourceUpdatedAt, !sourceUpdatedAt.isEmpty {
            return String(format: localized("status.line.updated_format"), sourceUpdatedAt)
        }
        return localized("status.line.updated_now")
    }

    private var shouldShowReadMore: Bool {
        line.detailText.count > 120 || line.detailText.contains("\n")
    }

    var body: some View {
        let lineColor = Color(hex: line.lineColorHex)
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
            HStack(spacing: 8) {
                Image(systemName: statusStyle.iconName)
                    .font(.caption.bold())
                    .foregroundColor(statusStyle.textColor)

                Text(line.status)
                    .font(AppFonts.subheadline().weight(.semibold))
                    .foregroundColor(statusStyle.textColor)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(statusStyle.backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(statusStyle.borderColor, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(line.detailText)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.82))
                .lineLimit(2)

            if shouldShowReadMore {
                Button(localized("status.line.read_more")) {
                    isShowingDetailSheet = true
                }
                .font(AppFonts.caption().weight(.semibold))
                .buttonStyle(.plain)
                .foregroundColor(AppColors.primary)
            }

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
        .sheet(isPresented: $isShowingDetailSheet) {
            RailStatusDetailSheet(
                line: line,
                lineColor: lineColor,
                updatedText: updatedText
            )
            .presentationDetents([.fraction(0.42), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct RailStatusDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let line: RailLineStatusItem
    let lineColor: Color
    let updatedText: String
    private var statusStyle: RailStatusVisualStyle {
        RailStatusVisualStyle.styleFor(line.severity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lineColor)
                            .frame(width: 44, height: 30)
                            .overlay(
                                Text(line.badgeText)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        Text(line.displayTitle)
                            .font(AppFonts.title3().bold())
                            .foregroundColor(AppColors.text)

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Image(systemName: statusStyle.iconName)
                            .font(.caption.bold())
                            .foregroundColor(statusStyle.textColor)

                        Text(line.status)
                            .font(AppFonts.headline())
                            .foregroundColor(statusStyle.textColor)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(statusStyle.backgroundColor)
                    )
                    .overlay(
                        Capsule()
                            .stroke(statusStyle.borderColor, lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("status.line.detail_title"))
                            .font(AppFonts.caption().bold())
                            .foregroundColor(AppColors.text.opacity(0.7))

                        Text(line.detailText)
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.text.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.lightGray.opacity(0.18))
                    )

                    Text(updatedText)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))
                }
                .padding(16)
            }
            .navigationTitle(localized("status.line.details_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct RailStatusVisualStyle {
    let textColor: Color
    let backgroundColor: Color
    let borderColor: Color
    let iconName: String

    static func styleFor(_ severity: RailStatusSeverity) -> RailStatusVisualStyle {
        switch severity {
        case .normal:
            return RailStatusVisualStyle(
                textColor: Color(hex: "1B5E20"),
                backgroundColor: Color(hex: "E8F5E9"),
                borderColor: Color(hex: "A5D6A7"),
                iconName: "checkmark.circle.fill"
            )
        case .warning:
            return RailStatusVisualStyle(
                textColor: Color(hex: "7A4F00"),
                backgroundColor: Color(hex: "FFF4E5"),
                borderColor: Color(hex: "FFD08A"),
                iconName: "exclamationmark.triangle.fill"
            )
        case .alert:
            return RailStatusVisualStyle(
                textColor: Color(hex: "8E1C1C"),
                backgroundColor: Color(hex: "FDECEC"),
                borderColor: Color(hex: "F2A8A8"),
                iconName: "xmark.octagon.fill"
            )
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
        statusDetail: "Situação Normal porem tudo pode mudar e alguma coisa pode acontecer. Não sei se isso pode quebrar tudo e acabar ficando muito grande e aí quero ver o resto do conteúdo numa outra janela.",
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
