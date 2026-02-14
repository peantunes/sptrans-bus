import SwiftUI

struct OverallStatusCard: View {
    let status: String
    let severity: RailStatusSeverity

    @State private var isAnimating: Bool = false

    private var iconName: String {
        switch severity {
        case .normal:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .alert:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch severity {
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
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(tint)
                    .scaleEffect(isAnimating ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
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
        OverallStatusCard(status: "Operação Normal", severity: .normal)
    }
}

