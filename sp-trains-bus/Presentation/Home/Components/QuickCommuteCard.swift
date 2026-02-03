import SwiftUI

struct QuickCommuteCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Plan Your Trip")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Spacer()

                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(AppColors.primary)
                }

                Text("Smart routes across buses, Metrô and CPTM.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.65))

                HStack(spacing: 8) {
                    Button(action: {
                        // Action for Plan a Trip
                    }) {
                        Label("Plan", systemImage: "magnifyingglass")
                            .font(AppFonts.callout())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(AppColors.primary.opacity(0.85))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        // Action for To Work
                    }) {
                        Label("Work", systemImage: "briefcase.fill")
                            .font(AppFonts.callout())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(AppColors.secondary.opacity(0.85))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        // Action for To Home
                    }) {
                        Label("Home", systemImage: "house.fill")
                            .font(AppFonts.callout())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(AppColors.accent.opacity(0.85))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }

                Text("ETA preview and live alerts included.")
                    .font(AppFonts.caption2())
                    .foregroundColor(AppColors.text.opacity(0.6))
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
