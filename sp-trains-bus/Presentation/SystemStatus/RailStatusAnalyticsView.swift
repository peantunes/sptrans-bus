import SwiftUI
import Charts

struct RailStatusAnalyticsView: View {
    @StateObject private var viewModel: RailStatusAnalyticsViewModel

    init(viewModel: RailStatusAnalyticsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                periodPicker

                if let generatedAt = viewModel.generatedAtText {
                    Text(String(format: localized("status.analytics.generated_at_format"), generatedAt))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.75))
                }

                if let rangeText = viewModel.rangeText {
                    Text(String(format: localized("status.analytics.range_format"), rangeText))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.text.opacity(0.72))
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        LoadingView()
                        Spacer()
                    }
                    .padding(.top, 24)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        viewModel.loadReport()
                    }
                } else if viewModel.lines.isEmpty {
                    Text(localized("status.analytics.empty"))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.8))
                        .padding(.top, 8)
                } else {
                    overviewCards
                    impactByLineChart
                    selectedLineSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [AppColors.background, AppColors.primary.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(localized("status.analytics.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.trackScreenOpened()
            if viewModel.lines.isEmpty {
                viewModel.loadReport()
            }
        }
    }

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("status.analytics.period.title"))
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)

            Picker(localized("status.analytics.period.title"), selection: Binding(
                get: { viewModel.selectedPeriod },
                set: { viewModel.selectPeriod($0) }
            )) {
                ForEach(RailStatusReportPeriod.allCases) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.top, 8)
    }

    private var overviewCards: some View {
        let items: [(title: String, value: String)] = [
            (localized("status.analytics.metric.lines"), "\(viewModel.totals.lineCount)"),
            (localized("status.analytics.metric.samples"), "\(viewModel.totals.sampleCount)"),
            (localized("status.analytics.metric.impact"), percentString(viewModel.totals.impactRatio)),
            (localized("status.analytics.metric.changes"), "\(viewModel.totals.changeCount)")
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items, id: \.title) { item in
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.text.opacity(0.72))
                        Text(item.value)
                            .font(AppFonts.title2().bold())
                            .foregroundColor(AppColors.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var impactByLineChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("status.analytics.chart.lines_impact_title"))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Text(localized("status.analytics.chart.lines_impact_subtitle"))
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.text.opacity(0.72))

                Chart(viewModel.lines) { line in
                    BarMark(
                        x: .value("Line", line.shortLabel),
                        y: .value("Impact", line.impactRatio * 100.0)
                    )
                    .foregroundStyle(impactColor(for: line.impactRatio))
                    .cornerRadius(4)
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let value = value.as(Double.self) {
                                Text("\(Int(value.rounded()))%")
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedLineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let selectedLine = viewModel.selectedLine {
                linePicker(selectedLine: selectedLine)
                lineOverviewCard(line: selectedLine)
                lineDailyImpactChart(line: selectedLine)
                lineStatusMixChart(line: selectedLine)
                lineChangesChart(line: selectedLine)
            }
        }
    }

    private func linePicker(selectedLine: RailStatusAnalyticsLine) -> some View {
        let metroLines = pickerLines(for: "metro")
        let cptmLines = pickerLines(for: "cptm")
        let otherLines = viewModel.lines
            .filter { source in
                let normalized = source.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalized != "metro" && normalized != "cptm"
            }
            .sorted(by: sortForPicker)

        return VStack(alignment: .leading, spacing: 8) {
            Text(localized("status.analytics.line_picker"))
                .font(AppFonts.headline())
                .foregroundColor(AppColors.text)

            Picker(localized("status.analytics.line_picker"), selection: Binding(
                get: { viewModel.selectedLineID ?? selectedLine.id },
                set: { viewModel.selectLine($0) }
            )) {
                if !metroLines.isEmpty {
                    Section(localized("status.section.metro")) {
                        ForEach(metroLines) { line in
                            Text(line.displayName).tag(line.id)
                        }
                    }
                }

                if !cptmLines.isEmpty {
                    Section(localized("status.section.cptm")) {
                        ForEach(cptmLines) { line in
                            Text(line.displayName).tag(line.id)
                        }
                    }
                }

                if !otherLines.isEmpty {
                    Section(localized("status.analytics.section.other")) {
                        ForEach(otherLines) { line in
                            Text(line.displayName).tag(line.id)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func lineOverviewCard(line: RailStatusAnalyticsLine) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: line.lineColorHex))
                        .frame(width: 44, height: 26)
                        .overlay(
                            Text(line.shortLabel)
                                .font(AppFonts.caption2().bold())
                                .foregroundColor(.white)
                        )

                    Text(line.displayName)
                        .font(AppFonts.title3().bold())
                        .foregroundColor(AppColors.text)

                    Spacer()

                    Text(percentString(line.impactRatio))
                        .font(AppFonts.headline())
                        .foregroundColor(impactColor(for: line.impactRatio))
                }

                Text(line.currentStatus)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.text.opacity(0.9))

                HStack(spacing: 16) {
                    Text("\(localized("status.analytics.metric.samples")): \(line.sampleCount)")
                    Text("\(localized("status.analytics.metric.changes")): \(line.changeCount)")
                }
                .font(AppFonts.caption())
                .foregroundColor(AppColors.text.opacity(0.75))
            }
        }
    }

    private func lineDailyImpactChart(line: RailStatusAnalyticsLine) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(format: localized("status.analytics.chart.daily_title"), line.displayName))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Chart(line.dailyTimeline) { point in
                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Impact", point.impactRatio * 100.0)
                    )
                    .foregroundStyle(impactColor(for: max(line.impactRatio, 0.04)).opacity(0.2))

                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Impact", point.impactRatio * 100.0)
                    )
                    .foregroundStyle(impactColor(for: line.impactRatio))
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    if point.changeCount > 0 {
                        PointMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Impact", point.impactRatio * 100.0)
                        )
                        .symbolSize(Double(28 + min(point.changeCount * 8, 50)))
                        .foregroundStyle(Color.orange)
                    }
                }
                .frame(height: 210)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let value = value.as(Double.self) {
                                Text("\(Int(value.rounded()))%")
                            }
                        }
                    }
                }
            }
        }
    }

    private func lineStatusMixChart(line: RailStatusAnalyticsLine) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("status.analytics.chart.status_mix_title"))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                Chart(line.statusMix.prefix(6)) { item in
                    BarMark(
                        x: .value("Samples", item.count),
                        y: .value("Status", item.status)
                    )
                    .foregroundStyle(impactColor(for: item.impactLevel))
                    .cornerRadius(4)
                }
                .frame(height: 220)
            }
        }
    }

    private func lineChangesChart(line: RailStatusAnalyticsLine) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("status.analytics.chart.changes_title"))
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.text)

                if line.changes.isEmpty {
                    Text(localized("status.analytics.chart.changes_none"))
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.text.opacity(0.75))
                } else {
                    Chart(line.changes.suffix(40)) { change in
                        LineMark(
                            x: .value("Timestamp", change.date),
                            y: .value("Impact", change.impactScore)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(impactColor(for: change.impactLevel))

                        PointMark(
                            x: .value("Timestamp", change.date),
                            y: .value("Impact", change.impactScore)
                        )
                        .foregroundStyle(impactColor(for: change.impactLevel))
                        .symbolSize(36)
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 1, 2]) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let score = value.as(Int.self) {
                                    Text(impactLabel(score: score))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(line.changes.suffix(5).reversed())) { change in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(impactColor(for: change.impactLevel))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(change.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(AppFonts.caption())
                                        .foregroundColor(AppColors.text.opacity(0.7))
                                    Text(String(format: localized("status.analytics.change.from_to"), change.fromStatus, change.toStatus))
                                        .font(AppFonts.subheadline())
                                        .foregroundColor(AppColors.text)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func percentString(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    private func impactColor(for impactRatio: Double) -> Color {
        if impactRatio >= 0.2 {
            return AppColors.statusAlert
        }
        if impactRatio >= 0.05 {
            return AppColors.statusWarning
        }
        return AppColors.statusNormal
    }

    private func impactColor(for level: RailStatusImpactLevel) -> Color {
        switch level {
        case .none:
            return AppColors.statusNormal
        case .low:
            return AppColors.statusWarning
        case .high:
            return AppColors.statusAlert
        }
    }

    private func impactLabel(score: Int) -> String {
        switch score {
        case 0:
            return localized("status.analytics.impact.none")
        case 2:
            return localized("status.analytics.impact.high")
        default:
            return localized("status.analytics.impact.low")
        }
    }

    private func pickerLines(for source: String) -> [RailStatusAnalyticsLine] {
        viewModel.lines
            .filter { $0.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == source }
            .sorted(by: sortForPicker)
    }

    private func sortForPicker(_ lhs: RailStatusAnalyticsLine, _ rhs: RailStatusAnalyticsLine) -> Bool {
        let lhsNumber = Int(lhs.lineNumber.filter(\.isNumber)) ?? Int.max
        let rhsNumber = Int(rhs.lineNumber.filter(\.isNumber)) ?? Int.max

        if lhsNumber == rhsNumber {
            return lhs.displayName < rhs.displayName
        }
        return lhsNumber < rhsNumber
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
