import SwiftUI

struct OverallStatusCard: View {
    let status: String
    @State private var isAnimating: Bool = false

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "checkmark.circle.fill") // Placeholder for status icon
                    .font(.title2)
                    .foregroundColor(status == "Normal Operation" ? .green : .red)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }

                Text(status)
                    .font(AppFonts.headline())
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)
                Spacer()
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        OverallStatusCard(status: "Normal Operation")
    }
}
