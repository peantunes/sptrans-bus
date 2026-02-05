import SwiftUI

struct SearchLocationField: View {
    let title: String
    let placeholder: String
    let systemImage: String
    @Binding var text: String
    var trailingTitle: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.6))

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(AppColors.primary)

                TextField(placeholder, text: $text)
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.text)

                if let trailingTitle, let trailingAction {
                    Button(trailingTitle, action: trailingAction)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppColors.lightGray)
            .cornerRadius(10)
        }
    }
}

#Preview {
    SearchLocationField(
        title: "Origin",
        placeholder: "Current location",
        systemImage: "location.fill",
        text: .constant("Current location"),
        trailingTitle: "Use"
    )
    .padding()
}
