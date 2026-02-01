import SwiftUI

struct GreetingHeader: View {
    let greeting: String
    var userName: String = "User" // Placeholder for actual user name

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(greeting)
                    .font(AppFonts.title1())
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)
                Text(userName)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview {
    GreetingHeader(greeting: "Good Morning", userName: "Pedro")
}
