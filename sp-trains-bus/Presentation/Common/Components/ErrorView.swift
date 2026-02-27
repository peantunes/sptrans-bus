import SwiftUI

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?
    @State private var isShowingTechnicalDetails = false

    init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.statusAlert.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.statusAlert)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("error.view.title"))
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)

                    Text(localized("error.view.subtitle"))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.7))
                }
            }

            Text(displayMessage)
                .font(AppFonts.body())
                .foregroundColor(AppColors.text.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            if hasTechnicalDetails {
                DisclosureGroup(localized("error.view.technical_details"), isExpanded: $isShowingTechnicalDetails) {
                    Text(normalizedMessage)
                        .font(AppFonts.caption2())
                        .foregroundColor(AppColors.text.opacity(0.66))
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.75))
            }

            if let retryAction {
                Button(action: retryAction) {
                    Label(localized("error.view.retry"), systemImage: "arrow.clockwise")
                        .font(AppFonts.subheadline().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(liquidGlassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.statusWarning.opacity(0.25), lineWidth: 1)
                .padding(0.5)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var normalizedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayMessage: String {
        guard !normalizedMessage.isEmpty else { return localized("error.view.generic_message") }
        if looksTechnical(normalizedMessage) {
            return localized("error.view.generic_message")
        }
        return normalizedMessage
    }

    private var hasTechnicalDetails: Bool {
        !normalizedMessage.isEmpty && displayMessage != normalizedMessage
    }

    private func looksTechnical(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let technicalMarkers = [
            "sql",
            "syntax",
            "prepare failed",
            "json",
            "http",
            "exception",
            "stack",
            "<html",
            "<?xml",
            "fatal",
            "timeout"
        ]
        return technicalMarkers.contains(where: lowered.contains)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private var liquidGlassBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.clear)
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        Color.clear
                            .glassEffect(.clear, in: .rect(cornerRadius: 20))
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.10))
            )
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00173A"), Color(hex: "1B1548")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ErrorView(message: "The network connection was lost.", retryAction: {
            print("Retrying...")
        })
    }
}
