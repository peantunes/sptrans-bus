import SwiftUI
import UniformTypeIdentifiers

struct LocalDataSettingsView: View {
    @StateObject private var viewModel: LocalDataSettingsViewModel
    let dependencies: AppDependencies
    @State private var isShowingImporter = false

    init(viewModel: LocalDataSettingsViewModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                modeCard

                importCard

                placesCard

                if let successMessage = viewModel.importSuccessMessage {
                    infoCard(text: successMessage, tint: AppColors.statusNormal)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationTitle(localized("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: viewModel.refreshStatus)
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.folder, .zip],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .alert(localized("local_data.import_error.title"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearMessages() } }
        )) {
            Button(localized("common.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("local_data.header.title"))
                .font(AppFonts.title2())
                .foregroundColor(AppColors.text)

            Text(localized("local_data.header.subtitle"))
                .font(AppFonts.subheadline())
                .foregroundColor(AppColors.text.opacity(0.65))
        }
    }

    private var modeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(localized("local_data.source.title"), systemImage: "externaldrive.connected.to.line.below.fill")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)
                    Spacer()
                    statusBadge(text: localized(viewModel.useLocalData ? "local_data.source.mode.local" : "local_data.source.mode.api"), tint: viewModel.useLocalData ? AppColors.statusNormal : AppColors.secondary)
                }

                Toggle(isOn: Binding(
                    get: { viewModel.useLocalData },
                    set: { viewModel.setLocalDataEnabled($0) }
                )) {
                    Text(localized("local_data.source.toggle"))
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text)
                }
                .toggleStyle(.switch)

                if viewModel.useLocalData && viewModel.currentFeed == nil {
                    Text(localized("local_data.source.missing_feed_warning"))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.statusWarning)
                }
            }
        }
    }

    private var importCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(localized("local_data.import.title"), systemImage: "square.and.arrow.down")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)
                    Spacer()
                    if viewModel.isImporting {
                        ProgressView()
                    }
                }

                if let feed = viewModel.currentFeed {
                    Text(String(format: localized("local_data.import.version_format"), feed.versionIdentifier))
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text)

                    Text(String(format: localized("local_data.import.last_import_format"), format(date: feed.downloadedAt)))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.65))

                    if let sourceURL = feed.sourceURL, !sourceURL.isEmpty {
                        Text(String(format: localized("local_data.import.source_format"), sourceURL))
                            .font(AppFonts.caption2())
                            .foregroundColor(AppColors.text.opacity(0.55))
                            .lineLimit(2)
                    }
                } else {
                    Text(localized("local_data.import.no_feed"))
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.text.opacity(0.7))
                }

                Button(action: { isShowingImporter = true }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text(viewModel.isImporting ? localized("local_data.import.button.importing") : localized("local_data.import.button.import"))
                    }
                    .font(AppFonts.callout())
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isImporting ? AppColors.lightGray : AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isImporting)

                HStack(spacing: 8) {
                    statusBadge(
                        text: localized(viewModel.shouldCheckForUpdates ? "local_data.import.update_due" : "local_data.import.update_up_to_date"),
                        tint: viewModel.shouldCheckForUpdates ? AppColors.statusWarning : AppColors.statusNormal
                    )

                    if viewModel.shouldCheckForUpdates {
                        Button(localized("local_data.import.mark_checked")) {
                            viewModel.markUpdateCheckNow()
                        }
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }

    private var placesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(localized("local_data.places.title"), systemImage: "house.and.flag.fill")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.text)
                    Spacer()
                    statusBadge(text: "\(viewModel.visiblePlacesCount)", tint: AppColors.accent)
                }

                Text(viewModel.placeSummary)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.7))

                NavigationLink {
                    PlacesManagerView(
                        viewModel: PlacesManagerViewModel(
                            storageService: dependencies.storageService,
                            locationService: dependencies.locationService,
                            featureToggles: FeatureToggles.self
                        )
                    )
                } label: {
                    HStack {
                        Text(localized("local_data.places.manage"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(AppFonts.callout())
                    .foregroundColor(AppColors.primary)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func statusBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(AppFonts.caption())
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }

    private func infoCard(text: String, tint: Color) -> some View {
        GlassCard {
            Text(text)
                .font(AppFonts.subheadline())
                .foregroundColor(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            Task {
                let didAccess = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }
                await viewModel.importGTFSSource(selectedURL)
            }
        }
    }
}

#Preview {
    NavigationStack {
        LocalDataSettingsView(
            viewModel: LocalDataSettingsViewModel(
                modeService: UserDefaultsTransitDataModeService(),
                feedService: GTFSFeedService(modelContainer: LocalDataModelContainer.shared),
                importUseCase: ImportGTFSDataUseCase(
                    importService: GTFSImporterService(
                        modelContainer: LocalDataModelContainer.shared,
                        feedService: GTFSFeedService(modelContainer: LocalDataModelContainer.shared)
                    ),
                    modeService: UserDefaultsTransitDataModeService()
                ),
                checkRefreshUseCase: CheckGTFSRefreshUseCase(
                    feedService: GTFSFeedService(modelContainer: LocalDataModelContainer.shared)
                ),
                storageService: SwiftDataStorageService(modelContainer: LocalDataModelContainer.shared)
            ),
            dependencies: AppDependencies()
        )
    }
}
