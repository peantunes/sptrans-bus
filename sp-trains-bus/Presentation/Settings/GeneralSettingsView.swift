import SwiftUI
import StoreKit
import UIKit

struct GeneralSettingsView: View {
    @Environment(\.requestReview) private var requestReview
    @AppStorage(AppTheme.selectedPrimaryColorHexKey) private var selectedPrimaryColorHex = AppTheme.defaultPrimaryColorHex

    private let supportURL = URL(string: "https://lolados.app/contact.php")
    private let policyURL = URL(string: "https://sptrans.lolados.app/policy.html")
    private let termsURL = URL(string: "https://sptrans.lolados.app/terms.html")

    var body: some View {
        List {
            Section("About") {
                HStack(spacing: 12) {
                    appIconView

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appName)
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.text)

                        Text("Version \(appVersionText)")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.65))
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Appearance") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accent Color")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(AppTheme.accentColorOptions) { option in
                                Button {
                                    selectedPrimaryColorHex = option.hex
                                } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(option.color)
                                            .frame(width: 32, height: 32)
                                            .overlay {
                                                Circle()
                                                    .stroke(selectedPrimaryColorHex == option.hex ? AppColors.text : .clear, lineWidth: 2)
                                            }
                                            .overlay {
                                                if selectedPrimaryColorHex == option.hex {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }

                                        Text(option.name)
                                            .font(AppFonts.caption2())
                                            .foregroundColor(AppColors.text.opacity(0.75))
                                    }
                                    .frame(minWidth: 52)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(option.name) accent color")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Support") {
                Button {
                    requestReview()
                } label: {
                    settingsRow(title: "Review the App", systemImage: "star.bubble")
                }
                .buttonStyle(.plain)

                if let supportURL {
                    Link(destination: supportURL) {
                        settingsRow(title: "Contact Us", systemImage: "envelope", isExternal: true)
                    }
                }
            }

            Section("Legal") {
                if let policyURL {
                    Link(destination: policyURL) {
                        settingsRow(title: "Policy", systemImage: "doc.text", isExternal: true)
                    }
                }

                if let termsURL {
                    Link(destination: termsURL) {
                        settingsRow(title: "Terms of Use", systemImage: "doc.plaintext", isExternal: true)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let iconImage = Bundle.main.appIcon {
            Image(uiImage: iconImage)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.primary.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
        }
    }

    private var appName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty {
            return displayName
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty {
            return bundleName
        }
        return "sp-trains-bus"
    }

    private var appVersionText: String {
        let marketingVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        let buildVersion = (Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String) ?? "1"
        return "\(marketingVersion) (\(buildVersion))"
    }

    private func settingsRow(title: String, systemImage: String, isExternal: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(AppColors.primary)
                .frame(width: 22)

            Text(title)
                .font(AppFonts.body())
                .foregroundColor(AppColors.text)

            Spacer()

            Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.text.opacity(0.35))
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

private extension Bundle {
    var appIcon: UIImage? {
        guard
            let icons = object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last
        else {
            return nil
        }

        return UIImage(named: iconName)
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
    }
}
