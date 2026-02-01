import SwiftUI

struct QuickCommuteCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading) {
                Text("Quick Commute")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                HStack {
                    Button(action: {
                        // Action for To Work
                    }) {
                        Label("To Work", systemImage: "briefcase.fill")
                            .font(AppFonts.callout())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(AppColors.primary.opacity(0.7))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        // Action for To Home
                    }) {
                        Label("To Home", systemImage: "house.fill")
                            .font(AppFonts.callout())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(AppColors.primary.opacity(0.7))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 5)

                Text("ETA: -- min")
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text.opacity(0.7))
                    .padding(.top, 5)
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        QuickCommuteCard()
    }
}
