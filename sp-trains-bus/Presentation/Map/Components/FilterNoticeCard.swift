import SwiftUI

struct FilterNoticeCard: View {
    let text: String

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 32, height: 32)
                    .background(AppColors.accent.opacity(0.12))
                    .clipShape(Circle())

                Text(text)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.7))

                Spacer()
            }
        }
    }
}

#Preview {
    FilterNoticeCard(text: "Metro mapping is coming soon. We're working on station entrances and line geometry.")
        .padding()
}
