import SwiftUI

struct RouteBadge: View {
    let routeShortName: String
    let routeColor: String
    let routeTextColor: String

    var body: some View {
        Text(routeShortName)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: routeColor))
            .foregroundColor(Color(hex: routeTextColor))
            .cornerRadius(5)
    }
}

#Preview {
    HStack {
        RouteBadge(routeShortName: "1012-10", routeColor: "509E2F", routeTextColor: "FFFFFF")
        RouteBadge(routeShortName: "L1", routeColor: "0455A1", routeTextColor: "FFFFFF")
    }
}
