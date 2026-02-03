import SwiftUI

struct RailStatusSection: View {
    let items: [RailStatusItem]
    let onOpenStatus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rail Status")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Spacer()

                Button(action: onOpenStatus) {
                    Text("See all")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.horizontal)

            GlassCard {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        RailStatusRow(item: item)

                        if item.id != items.last?.id {
                            Divider()
                                .background(AppColors.text.opacity(0.1))
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(AppColors.text.opacity(0.5))

                        Text("Updated just now")
                            .font(AppFonts.caption2())
                            .foregroundColor(AppColors.text.opacity(0.5))

                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RailStatusItem: Identifiable {
    let id: String
    let title: String
    let status: String
    let detail: String
    let color: Color
    let systemImage: String
}

private struct RailStatusRow: View {
    let item: RailStatusItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(item.color)
                .frame(width: 32, height: 32)
                .background(item.color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text)

                Text(item.detail)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.6))
            }

            Spacer()

            Text(item.status)
                .font(AppFonts.caption())
                .foregroundColor(item.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(item.color.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    RailStatusSection(
        items: [
            RailStatusItem(
                id: "metro",
                title: "Metrô de SP",
                status: "Normal",
                detail: "All lines running normally",
                color: AppColors.statusNormal,
                systemImage: "tram.fill"
            ),
            RailStatusItem(
                id: "cptm",
                title: "CPTM",
                status: "Attention",
                detail: "Speed restriction on Line 9",
                color: AppColors.statusWarning,
                systemImage: "train.side.front.car"
            )
        ],
        onOpenStatus: {}
    )
}
