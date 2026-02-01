import SwiftUI

struct BusProgressIndicator: View {
    let progress: Double // 0.0 to 1.0
    let estimatedTime: String

    var body: some View {
        VStack {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent))
                .frame(height: 10)
                .cornerRadius(5)

            Text("ETA: \(estimatedTime)")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.7))
        }
    }
}

#Preview {
    BusProgressIndicator(progress: 0.7, estimatedTime: "2 min")
        .padding()
}
