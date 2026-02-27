import SwiftUI
import UIKit

struct RailDisruptionAlertsView: View {
    @StateObject private var viewModel: RailDisruptionAlertsViewModel
    @Environment(\.openURL) private var openURL

    init(viewModel: RailDisruptionAlertsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("status.alerts.title"))
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.text)
                        Text(localized("status.alerts.subtitle"))
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.text.opacity(0.84))

                        if viewModel.hasSelectableLines {
                            HStack {
                                Text(
                                    String(
                                        format: localized("status.alerts.selected_count_format"),
                                        viewModel.selectedCount,
                                        viewModel.lines.count
                                    )
                                )
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.72))

                                Spacer()

                                Button {
                                    viewModel.toggleSelectAll()
                                } label: {
                                    Text(
                                        viewModel.areAllLinesSelected
                                        ? localized("status.alerts.deselect_all")
                                        : localized("status.alerts.select_all")
                                    )
                                    .font(AppFonts.caption().bold())
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                if viewModel.shouldShowSettingsHint {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localized("status.alerts.notifications_blocked.title"))
                                .font(AppFonts.subheadline().bold())
                                .foregroundColor(AppColors.statusAlert)
                            Text(localized("status.alerts.notifications_blocked.message"))
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.text.opacity(0.8))
                            Button(localized("status.alerts.notifications_blocked.open_settings")) {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                openURL(url)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppColors.statusAlert)
                        }
                    }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        LoadingView()
                        Spacer()
                    }
                    .padding(.top, 20)
                } else if viewModel.lines.isEmpty {
                    Text(localized("status.alerts.empty_lines"))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.8))
                } else {
                    lineSection(title: localized("status.section.metro"), lines: viewModel.metroLines)
                    lineSection(title: localized("status.section.cptm"), lines: viewModel.cptmLines)
                }

                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.statusNormal)
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.statusAlert)
                }

                Button {
                    viewModel.saveSubscriptions()
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text(localized("status.alerts.save"))
                            .font(AppFonts.headline())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .disabled(viewModel.isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle(localized("status.alerts.navigation_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.trackScreenOpened()
            viewModel.loadExistingSubscriptions()
        }
    }

    @ViewBuilder
    private func lineSection(title: String, lines: [RailDisruptionAlertLine]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                ForEach(lines) { line in
                    Button {
                        viewModel.toggle(line)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: viewModel.isSelected(line) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.isSelected(line) ? AppColors.primary : AppColors.text.opacity(0.5))
                            Text(line.displayName)
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.text)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.isSelected(line) ? AppColors.primary.opacity(0.12) : AppColors.background.opacity(0.4))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
