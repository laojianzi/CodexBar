import CodexBarCore
import SwiftUI

@MainActor
struct LegacyPlanUtilizationHistoryMenuView: View {
    private enum Layout {
        static let chartHeight: CGFloat = 130
        static let detailHeight: CGFloat = 16
        static let maxPoints = 30
    }

    private struct SeriesSelection: Hashable {
        let name: PlanUtilizationSeriesName
        let windowMinutes: Int

        var id: String {
            "\(self.name.rawValue):\(self.windowMinutes)"
        }
    }

    private struct VisibleSeries: Identifiable, Equatable {
        let selection: SeriesSelection
        let title: String
        let history: PlanUtilizationSeriesHistory

        var id: String {
            self.selection.id
        }
    }

    private struct EntryPointAccumulator {
        let effectiveBoundaryDate: Date
        let displayBoundaryDate: Date
        let observedAt: Date
        let usedPercent: Double
        let hasObservedResetBoundary: Bool
    }

    private struct ResetBoundaryLattice {
        let referenceBoundaryDate: Date
        let windowInterval: TimeInterval
    }

    private struct Point {
        let id: String
        let date: Date
        let usedPercent: Double
        let isObserved: Bool
    }

    private struct Model {
        let points: [Point]
        let bars: [LegacyHistoryBarChartView.Bar]
        let pointsByID: [String: Point]
        let barColor: Color
        let trackColor: Color
    }

    private let visibleSeries: [VisibleSeries]
    private let modelsBySeriesID: [String: Model]
    private let emptyModel: Model
    private let width: CGFloat

    @State private var selectedSeriesID: String?
    @State private var selectedPointID: String?

    init(
        provider: UsageProvider,
        histories: [PlanUtilizationSeriesHistory],
        snapshot: UsageSnapshot? = nil,
        width: CGFloat)
    {
        let visibleSeries = Self.visibleSeries(histories: histories, provider: provider, snapshot: snapshot)
        let referenceDate = Date()
        self.visibleSeries = visibleSeries
        self.modelsBySeriesID = Dictionary(uniqueKeysWithValues: visibleSeries.map {
            ($0.id, Self.makeModel(history: $0.history, provider: provider, referenceDate: referenceDate))
        })
        self.emptyModel = Self.emptyModel(provider: provider)
        self.width = width
    }

    var body: some View {
        let effectiveSelectedSeries = self.visibleSeries.first(where: { $0.id == self.selectedSeriesID })
            ?? self.visibleSeries.first
        let model = effectiveSelectedSeries.flatMap { self.modelsBySeriesID[$0.id] } ?? self.emptyModel

        VStack(alignment: .leading, spacing: 10) {
            if self.visibleSeries.count > 1 {
                Picker(selection: Binding(
                    get: { effectiveSelectedSeries?.id ?? "" },
                    set: { newValue in
                        self.selectedSeriesID = newValue
                        self.selectedPointID = nil
                    })) {
                        ForEach(self.visibleSeries) { series in
                            Text(series.title).tag(series.id)
                        }
                    } label: {
                        EmptyView()
                    }
                    .labelsHidden()
                        .pickerStyle(.segmented)
            }

            if model.bars.isEmpty {
                Text(Self.emptyStateText(title: effectiveSelectedSeries?.title))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.chartHeight + Layout.detailHeight)
            } else {
                LegacyHistoryBarChartView(
                    bars: model.bars,
                    height: Layout.chartHeight,
                    maxValue: 100,
                    selectedID: self.$selectedPointID)
                    .accessibilityLabel(L("Plan utilization chart"))
                    .accessibilityValue(String(format: L("%d utilization samples"), model.points.count))

                Text(self.detailLine(model: model, windowMinutes: effectiveSelectedSeries?.history.windowMinutes ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: Layout.detailHeight, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .topLeading)
        .task(id: self.visibleSeries.map(\.id).joined(separator: ",")) {
            guard let firstVisibleSeries = self.visibleSeries.first else { return }
            guard !self.visibleSeries.contains(where: { $0.id == self.selectedSeriesID }) else { return }
            self.selectedSeriesID = firstVisibleSeries.id
            self.selectedPointID = nil
        }
    }

    private static func visibleSeries(
        histories: [PlanUtilizationSeriesHistory],
        provider: UsageProvider,
        snapshot: UsageSnapshot?) -> [VisibleSeries]
    {
        let metadata = ProviderDescriptorRegistry.metadata[provider]
        let allowedNames = self.visibleSeriesNames(provider: provider, snapshot: snapshot)
        var historiesBySelection: [SeriesSelection: PlanUtilizationSeriesHistory] = [:]
        for history in histories {
            guard !history.entries.isEmpty else { continue }
            guard history.windowMinutes > 0 else { continue }
            guard allowedNames?.contains(history.name) ?? true else { continue }

            let canonicalWindowMinutes = history.name.canonicalWindowMinutes(history.windowMinutes)
            let selection = SeriesSelection(name: history.name, windowMinutes: canonicalWindowMinutes)
            if let existingHistory = historiesBySelection[selection] {
                historiesBySelection[selection] = PlanUtilizationSeriesHistory(
                    name: history.name,
                    windowMinutes: canonicalWindowMinutes,
                    entries: Self.mergedEntries(existingHistory.entries + history.entries))
            } else {
                historiesBySelection[selection] = PlanUtilizationSeriesHistory(
                    name: history.name,
                    windowMinutes: canonicalWindowMinutes,
                    entries: history.entries)
            }
        }

        return historiesBySelection.values
            .sorted { lhs, rhs in
                let lhsOrder = self.seriesSortOrder(lhs.name)
                let rhsOrder = self.seriesSortOrder(rhs.name)
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                if lhs.windowMinutes != rhs.windowMinutes { return lhs.windowMinutes < rhs.windowMinutes }
                return lhs.name.rawValue < rhs.name.rawValue
            }
            .map { history in
                VisibleSeries(
                    selection: SeriesSelection(name: history.name, windowMinutes: history.windowMinutes),
                    title: self.seriesTitle(name: history.name, metadata: metadata),
                    history: history)
            }
    }

    static func mergedEntries(_ entries: [PlanUtilizationHistoryEntry]) -> [PlanUtilizationHistoryEntry] {
        var seen: Set<PlanUtilizationHistoryEntry> = []
        return entries.filter { entry in
            seen.insert(entry).inserted
        }
    }

    private static func visibleSeriesNames(
        provider: UsageProvider,
        snapshot: UsageSnapshot?) -> Set<PlanUtilizationSeriesName>?
    {
        guard let snapshot else { return nil }

        var names: Set<PlanUtilizationSeriesName> = []
        switch provider {
        case .codex:
            if snapshot.primary != nil { names.insert(.session) }
            if snapshot.secondary != nil { names.insert(.weekly) }
        case .claude:
            if snapshot.primary != nil { names.insert(.session) }
            if snapshot.secondary != nil { names.insert(.weekly) }
            if snapshot.tertiary != nil,
               ProviderDescriptorRegistry.metadata[provider]?.supportsOpus == true
            {
                names.insert(.opus)
            }
        default:
            let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
                + (snapshot.extraRateWindows?.filter(\.usageKnown).map(\.window) ?? [])
            guard windows.contains(where: { $0.windowMinutes == 7 * 24 * 60 }) else { return nil }
            names.insert(.weekly)
        }

        return names
    }

    private static func makeModel(
        history: PlanUtilizationSeriesHistory?,
        provider: UsageProvider,
        referenceDate: Date) -> Model
    {
        guard let history else {
            return self.emptyModel(provider: provider)
        }

        var points = self.seriesPoints(history: history, referenceDate: referenceDate)
        if points.count > Layout.maxPoints {
            points = Array(points.suffix(Layout.maxPoints))
        }

        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        let barColor = Color(red: color.red, green: color.green, blue: color.blue)
        let trackColor = MenuHighlightStyle.progressTrack(false)
        let bars = points.map { point in
            let used = max(0, min(100, point.usedPercent))
            return LegacyHistoryBarChartView.Bar(
                id: point.id,
                axisLabel: point.date.formatted(.dateTime.month(.abbreviated).day()),
                segments: [
                    .init(id: "\(point.id)-used", value: used, color: point.isObserved ? barColor : Color.clear),
                    .init(id: "\(point.id)-track", value: max(0, 100 - used), color: trackColor),
                ],
                detailPrimary: self.detailLine(point: point, windowMinutes: history.windowMinutes))
        }

        return Model(
            points: points,
            bars: bars,
            pointsByID: Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) }),
            barColor: barColor,
            trackColor: trackColor)
    }

    private static func emptyModel(provider: UsageProvider) -> Model {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        let barColor = Color(red: color.red, green: color.green, blue: color.blue)
        return Model(
            points: [],
            bars: [],
            pointsByID: [:],
            barColor: barColor,
            trackColor: MenuHighlightStyle.progressTrack(false))
    }

    private static func seriesPoints(history: PlanUtilizationSeriesHistory, referenceDate: Date) -> [Point] {
        guard history.windowMinutes > 0 else { return [] }
        let windowInterval = Double(history.windowMinutes) * 60
        let resetBoundaryLattice = self.resetBoundaryLattice(
            entries: history.entries,
            windowMinutes: history.windowMinutes)
        var strongestObservedPointByPeriod: [Date: EntryPointAccumulator] = [:]

        for entry in history.entries {
            let candidate = self.observedPointCandidate(
                for: entry,
                windowMinutes: history.windowMinutes,
                resetBoundaryLattice: resetBoundaryLattice)

            if let existing = strongestObservedPointByPeriod[candidate.effectiveBoundaryDate],
               !self.shouldPreferObservedPoint(candidate, over: existing)
            {
                continue
            }
            strongestObservedPointByPeriod[candidate.effectiveBoundaryDate] = candidate
        }

        guard !strongestObservedPointByPeriod.isEmpty else { return [] }

        let sortedPeriodBoundaryDates = strongestObservedPointByPeriod.keys.sorted()
        var points: [Point] = []
        var previousPeriodBoundaryDate: Date?

        for periodBoundaryDate in sortedPeriodBoundaryDates {
            if let previousPeriodBoundaryDate {
                var cursor = previousPeriodBoundaryDate.addingTimeInterval(windowInterval)
                while cursor < periodBoundaryDate {
                    points.append(Point(id: self.pointID(cursor), date: cursor, usedPercent: 0, isObserved: false))
                    cursor = cursor.addingTimeInterval(windowInterval)
                }
            }

            if let bucket = strongestObservedPointByPeriod[periodBoundaryDate] {
                points.append(Point(
                    id: self.pointID(bucket.effectiveBoundaryDate),
                    date: bucket.displayBoundaryDate,
                    usedPercent: bucket.usedPercent,
                    isObserved: true))
            }
            previousPeriodBoundaryDate = periodBoundaryDate
        }

        if let lastObservedPeriodBoundaryDate = sortedPeriodBoundaryDates.last {
            let currentPeriodBoundaryDate = self.currentPeriodBoundaryDate(
                for: referenceDate,
                windowMinutes: history.windowMinutes,
                resetBoundaryLattice: resetBoundaryLattice)

            if currentPeriodBoundaryDate > lastObservedPeriodBoundaryDate {
                var cursor = lastObservedPeriodBoundaryDate.addingTimeInterval(windowInterval)
                while cursor <= currentPeriodBoundaryDate {
                    points.append(Point(id: self.pointID(cursor), date: cursor, usedPercent: 0, isObserved: false))
                    cursor = cursor.addingTimeInterval(windowInterval)
                }
            }
        }

        return points
    }

    private static func observedPointCandidate(
        for entry: PlanUtilizationHistoryEntry,
        windowMinutes: Int,
        resetBoundaryLattice: ResetBoundaryLattice?) -> EntryPointAccumulator
    {
        let rawResetBoundaryDate = entry.resetsAt.map(self.normalizedBoundaryDate)
        let effectiveBoundaryDate = self.effectivePeriodBoundaryDate(
            for: entry,
            windowMinutes: windowMinutes,
            rawResetBoundaryDate: rawResetBoundaryDate,
            resetBoundaryLattice: resetBoundaryLattice)
        return EntryPointAccumulator(
            effectiveBoundaryDate: effectiveBoundaryDate,
            displayBoundaryDate: rawResetBoundaryDate ?? effectiveBoundaryDate,
            observedAt: entry.capturedAt,
            usedPercent: max(0, min(100, entry.usedPercent)),
            hasObservedResetBoundary: rawResetBoundaryDate != nil)
    }

    private static func resetBoundaryLattice(
        entries: [PlanUtilizationHistoryEntry],
        windowMinutes: Int) -> ResetBoundaryLattice?
    {
        guard let latestObservedResetBoundaryDate = entries
            .compactMap(\.resetsAt)
            .map(self.normalizedBoundaryDate)
            .max()
        else {
            return nil
        }
        return ResetBoundaryLattice(
            referenceBoundaryDate: latestObservedResetBoundaryDate,
            windowInterval: Double(windowMinutes) * 60)
    }

    private static func normalizedBoundaryDate(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
    }

    private static func effectivePeriodBoundaryDate(
        for entry: PlanUtilizationHistoryEntry,
        windowMinutes: Int,
        rawResetBoundaryDate: Date?,
        resetBoundaryLattice: ResetBoundaryLattice?) -> Date
    {
        if let rawResetBoundaryDate {
            if let resetBoundaryLattice {
                return self.closestPeriodBoundaryDate(
                    to: rawResetBoundaryDate,
                    resetBoundaryLattice: resetBoundaryLattice)
            }
            return rawResetBoundaryDate
        }
        if let resetBoundaryLattice {
            return self.periodBoundaryDate(containing: entry.capturedAt, resetBoundaryLattice: resetBoundaryLattice)
        }
        return self.syntheticBoundaryDate(for: entry.capturedAt, windowMinutes: windowMinutes)
    }

    private static func shouldPreferObservedPoint(
        _ candidate: EntryPointAccumulator,
        over existing: EntryPointAccumulator) -> Bool
    {
        if candidate.usedPercent != existing.usedPercent { return candidate.usedPercent > existing.usedPercent }
        if candidate.hasObservedResetBoundary != existing
            .hasObservedResetBoundary { return candidate.hasObservedResetBoundary }
        if candidate.displayBoundaryDate != existing
            .displayBoundaryDate { return candidate.displayBoundaryDate > existing.displayBoundaryDate }
        return candidate.observedAt >= existing.observedAt
    }

    private static func currentPeriodBoundaryDate(
        for referenceDate: Date,
        windowMinutes: Int,
        resetBoundaryLattice: ResetBoundaryLattice?) -> Date
    {
        if let resetBoundaryLattice {
            return self.periodBoundaryDate(containing: referenceDate, resetBoundaryLattice: resetBoundaryLattice)
        }
        return self.syntheticBoundaryDate(for: referenceDate, windowMinutes: windowMinutes)
    }

    private static func closestPeriodBoundaryDate(
        to rawBoundaryDate: Date,
        resetBoundaryLattice: ResetBoundaryLattice) -> Date
    {
        let offset = rawBoundaryDate.timeIntervalSince(resetBoundaryLattice.referenceBoundaryDate)
        let periodOffset = (offset / resetBoundaryLattice.windowInterval).rounded()
        return resetBoundaryLattice.referenceBoundaryDate
            .addingTimeInterval(periodOffset * resetBoundaryLattice.windowInterval)
    }

    private static func periodBoundaryDate(
        containing capturedAt: Date,
        resetBoundaryLattice: ResetBoundaryLattice) -> Date
    {
        let offset = capturedAt.timeIntervalSince(resetBoundaryLattice.referenceBoundaryDate)
        let periodOffset = ceil(offset / resetBoundaryLattice.windowInterval)
        return resetBoundaryLattice.referenceBoundaryDate
            .addingTimeInterval(periodOffset * resetBoundaryLattice.windowInterval)
    }

    private static func syntheticBoundaryDate(for date: Date, windowMinutes: Int) -> Date {
        let bucketSeconds = Double(windowMinutes) * 60
        let bucketIndex = floor(date.timeIntervalSince1970 / bucketSeconds)
        return Date(timeIntervalSince1970: (bucketIndex + 1) * bucketSeconds)
    }

    private static func pointID(_ date: Date) -> String {
        String(date.timeIntervalSince1970)
    }

    private static func seriesTitle(name: PlanUtilizationSeriesName, metadata: ProviderMetadata?) -> String {
        switch name {
        case .session:
            L(metadata?.sessionLabel ?? "Session")
        case .weekly:
            L(metadata?.weeklyLabel ?? "Weekly")
        case .opus:
            metadata?.opusLabel ?? "Opus"
        default:
            self.fallbackTitle(for: name.rawValue)
        }
    }

    private static func fallbackTitle(for rawValue: String) -> String {
        let words = rawValue
            .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
            .split(separator: " ")
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    private static func seriesSortOrder(_ name: PlanUtilizationSeriesName) -> Int {
        switch name {
        case .session:
            0
        case .weekly:
            1
        case .opus:
            2
        default:
            100
        }
    }

    private static func emptyStateText(title: String?) -> String {
        if let title {
            return String(format: L("No %@ utilization data yet."), title.lowercased())
        }
        return L("No utilization data yet.")
    }

    private func detailLine(model: Model, windowMinutes: Int) -> String {
        let activePoint = self.selectedPointID.flatMap { model.pointsByID[$0] } ?? model.points.last
        return Self.detailLine(point: activePoint, windowMinutes: windowMinutes)
    }

    private static func detailLine(point: Point?, windowMinutes: Int) -> String {
        guard let point else { return "-" }

        let dateLabel = self.detailDateLabel(for: point.date, windowMinutes: windowMinutes)
        let used = max(0, min(100, point.usedPercent))
        if !point.isObserved {
            return "\(dateLabel): -"
        }
        let usedText = used.formatted(.number.precision(.fractionLength(0...1)))
        return L("%@: %@%% used", dateLabel, usedText)
    }

    private static func detailDateLabel(for date: Date, windowMinutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = codexBarLocalizedLocale()
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
        var rendered = formatter.string(from: date).replacingOccurrences(of: "\u{202F}", with: " ")
        let amSymbol = formatter.amSymbol ?? ""
        let pmSymbol = formatter.pmSymbol ?? ""
        if !amSymbol.isEmpty {
            rendered = rendered.replacingOccurrences(of: amSymbol, with: amSymbol.lowercased())
        }
        if !pmSymbol.isEmpty {
            rendered = rendered.replacingOccurrences(of: pmSymbol, with: pmSymbol.lowercased())
        }
        return rendered
    }

    #if DEBUG
    struct ModelSnapshot: Equatable {
        let pointCount: Int
        let selectedSeries: String?
        let visibleSeries: [String]
        let usedPercents: [Double]
        let observedFlags: [Bool]
    }

    static func _modelSnapshotForTesting(
        selectedSeriesRawValue: String? = nil,
        histories: [PlanUtilizationSeriesHistory],
        provider: UsageProvider,
        snapshot: UsageSnapshot? = nil,
        referenceDate: Date? = nil) -> ModelSnapshot
    {
        let visibleSeries = self.visibleSeries(histories: histories, provider: provider, snapshot: snapshot)
        let selectedSeries = visibleSeries.first(where: { $0.id == selectedSeriesRawValue }) ?? visibleSeries.first
        let model = self.makeModel(
            history: selectedSeries?.history,
            provider: provider,
            referenceDate: referenceDate ?? histories.flatMap(\.entries).map(\.capturedAt).max() ?? Date())
        return ModelSnapshot(
            pointCount: model.points.count,
            selectedSeries: selectedSeries?.id,
            visibleSeries: visibleSeries.map(\.id),
            usedPercents: model.points.map(\.usedPercent),
            observedFlags: model.points.map(\.isObserved))
    }
    #endif
}
