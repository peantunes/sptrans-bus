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

            Text(String(format: localized("stop_detail.eta_format"), estimatedTime))
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.7))
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

#Preview {
    BusProgressIndicator(progress: 0.7, estimatedTime: "2 min")
        .padding()
}
