import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .glassEffectIfAvailable()
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

extension View {
    @ViewBuilder
    func glassEffectIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.clear, in: .rect(cornerRadius: 12))
        } else {
            background(.ultraThinMaterial)
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        GlassCard {
            VStack {
                Text("Glass Card Title")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("This is a beautiful glassmorphism card example.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }
}
