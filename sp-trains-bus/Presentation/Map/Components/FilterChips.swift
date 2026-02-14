import SwiftUI

enum TransitFilter: String, CaseIterable {
    case bus
    case metro
    case train

    var title: String {
        switch self {
        case .bus:
            return localized("map.filter.bus")
        case .metro:
            return localized("map.filter.metro")
        case .train:
            return localized("map.filter.cptm")
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
            return localized("map.filter.helper.bus")
        case .metro:
            return localized("map.filter.helper.metro")
        case .train:
            return localized("map.filter.helper.cptm")
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
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
                                Text(localized("map.filter.soon"))
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

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

#Preview {
    @State var selectedFilter: TransitFilter = .bus
    return FilterChips(selectedFilter: $selectedFilter)
}
