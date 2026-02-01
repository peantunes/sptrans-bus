import SwiftUI

struct MetroLineCard: View {
    let line: MetroLine
    let status: String // Placeholder for dynamic status
    let description: String // Placeholder for dynamic description

    var body: some View {
        GlassCard {
            HStack {
                Circle()
                    .fill(Color(hex: line.colorHex))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(line.line)
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading) {
                    Text(line.name)
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)
                    Text(status)
                        .font(AppFonts.subheadline())
                        .foregroundColor(status == "Normal" ? .green : .red)
                    Text(description)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))
                }
                Spacer()
            }
        }
    }
}

#Preview {
    let sampleLine = MetroLine(line: "L1", name: "Azul", colorHex: "0455A1")
    return ZStack {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        MetroLineCard(line: sampleLine, status: "Normal", description: "All clear")
    }
}
