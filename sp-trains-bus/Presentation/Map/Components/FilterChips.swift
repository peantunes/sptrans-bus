import SwiftUI

enum TransitFilter: String, CaseIterable {
    case bus = "Bus"
    case metro = "Metro"
    case train = "Train"
}

struct FilterChips: View {
    @Binding var selectedFilter: TransitFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(TransitFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter.rawValue)
                            .font(AppFonts.subheadline())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 15)
                            .background(selectedFilter == filter ? AppColors.accent : AppColors.lightGray)
                            .foregroundColor(selectedFilter == filter ? .white : AppColors.text)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    @State var selectedFilter: TransitFilter = .bus
    return FilterChips(selectedFilter: $selectedFilter)
}
