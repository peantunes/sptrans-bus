import SwiftUI

enum TransitFilter: String, CaseIterable {
    case bus
    case metro
    case train

    var title: String {
        switch self {
        case .bus:
            return "Bus"
        case .metro:
            return "Metrô"
        case .train:
            return "CPTM"
        }
    }

    var systemImage: String {
        switch self {
        case .bus:
            return "bus.fill"
        case .metro:
            return "tram.fill"
        case .train:
            return "train.side.front.car"
        }
    }

    var isAvailable: Bool {
        self == .bus
    }

    var helperText: String {
        switch self {
        case .bus:
            return "Showing bus stops and corridors."
        case .metro:
            return "Metro mapping is coming soon."
        case .train:
            return "CPTM mapping is coming soon."
        }
    }
}

struct FilterChips: View {
    @Binding var selectedFilter: TransitFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TransitFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: filter.systemImage)
                                .font(.caption.weight(.semibold))

                            Text(filter.title)
                                .font(AppFonts.subheadline())

                            if !filter.isAvailable {
                                Text("Soon")
                                    .font(AppFonts.caption2())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.text.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
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
