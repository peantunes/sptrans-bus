import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
            .scaleEffect(1.5)
            .padding()
            .background(AppColors.background.opacity(0.8))
            .cornerRadius(10)
    }
}

#Preview {
    LoadingView()
}
