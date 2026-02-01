import SwiftUI

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?

    init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
                .padding(.bottom, 5)

            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.text.opacity(0.8))
                .padding(.horizontal)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Retry")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(AppColors.accent)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .background(AppColors.background)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

#Preview {
    ErrorView(message: "Something went wrong. Please try again later.", retryAction: {
        print("Retrying...")
    })
}
