import CodexBarCore
import SwiftUI

struct LegacyCostHistoryMenuView: View {
    typealias DailyEntry = CostUsageDailyReport.Entry

    private let provider: UsageProvider
    private let daily: [DailyEntry]
    private let totalCostUSD: Double?
    private let currencyCode: String
    private let historyDays: Int
    private let windowLabel: String?
    private let width: CGFloat
    @State private var selectedID: String?

    init(
        provider: UsageProvider,
        daily: [DailyEntry],
        totalCostUSD: Double?,
        currencyCode: String,
        historyDays: Int,
        windowLabel: String?,
        width: CGFloat)
    {
        self.provider = provider
        self.daily = daily
        self.totalCostUSD = totalCostUSD
        self.currencyCode = currencyCode
        self.historyDays = max(1, min(365, historyDays))
        self.windowLabel = windowLabel
        self.width = width
    }

    var body: some View {
        let model = Self.model(provider: self.provider, daily: self.daily, currencyCode: self.currencyCode)
        let selectedID = self.selectedID ?? model.bars.last?.id
        VStack(alignment: .leading, spacing: 10) {
            if model.bars.isEmpty {
                Text(L("No cost history data."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LegacyHistoryBarChartView(bars: model.bars, height: 114, selectedID: self.$selectedID)
                self.detail(model: model, selectedID: selectedID)
            }

            if let total = self.totalCostUSD {
                Text(String(
                    format: L("Est. total (%@): %@"),
                    self.windowLabel ?? Self.windowLabel(days: self.historyDays),
                    UsageFormatter.currencyString(total, currencyCode: self.currencyCode)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(height: 16, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .top)
    }

    private func detail(model: Model, selectedID: String?) -> some View {
        let bar = selectedID.flatMap { id in model.bars.first { $0.id == id } }
        let rows = selectedID.flatMap { model.rowsByID[$0] } ?? []
        return VStack(alignment: .leading, spacing: 6) {
            Text(bar?.detailPrimary ?? L("Hover a bar for details"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 16, alignment: .leading)
            if !rows.isEmpty {
                ScrollView(.vertical, showsIndicators: rows.count > 4) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(rows) { row in
                            HStack(alignment: .top, spacing: 8) {
                                Rectangle()
                                    .fill(row.color)
                                    .frame(width: 2, height: 32)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if let subtitle = row.subtitle {
                                        Text(subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(rows.count), 4) * 38, alignment: .topLeading)
            }
        }
    }

    private struct Model {
        let bars: [LegacyHistoryBarChartView.Bar]
        let rowsByID: [String: [DetailRow]]
    }

    private struct DetailRow: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let color: Color
    }

    private static func model(provider: UsageProvider, daily: [DailyEntry], currencyCode: String) -> Model {
        let color = self.barColor(for: provider)
        let sorted = daily.sorted { $0.date < $1.date }
        var rowsByID: [String: [DetailRow]] = [:]
        let bars = sorted.compactMap { entry -> LegacyHistoryBarChartView.Bar? in
            guard let cost = entry.costUSD, cost > 0 else { return nil }
            let label = LegacyCreditsHistoryMenuView.axisLabel(entry.date)
            var detailParts = [UsageFormatter.currencyString(cost, currencyCode: currencyCode)]
            if let tokens = entry.totalTokens {
                detailParts.append("\(UsageFormatter.tokenCountString(tokens)) tokens")
            }
            if let requests = entry.requestCount {
                detailParts.append("\(UsageFormatter.tokenCountString(requests)) requests")
            }
            rowsByID[entry.date] = self.detailRows(entry: entry, currencyCode: currencyCode, color: color)
            return LegacyHistoryBarChartView.Bar(
                id: entry.date,
                axisLabel: label,
                segments: [.init(id: entry.date, value: cost, color: color)],
                detailPrimary: "\(label): \(detailParts.joined(separator: " · "))")
        }
        return Model(bars: bars, rowsByID: rowsByID)
    }

    private static func detailRows(entry: DailyEntry, currencyCode: String, color: Color) -> [DetailRow] {
        guard let breakdown = entry.modelBreakdowns, !breakdown.isEmpty else { return [] }
        return self.orderedBreakdownItems(breakdown)
            .enumerated()
            .map { index, item in
                DetailRow(
                    id: "\(item.modelName)-\(index)",
                    title: UsageFormatter.modelDisplayName(item.modelName),
                    subtitle: UsageFormatter.modelCostDetail(
                        item.modelName,
                        costUSD: item.costUSD,
                        totalTokens: item.totalTokens,
                        currencyCode: currencyCode),
                    color: color.opacity(max(0.35, 1 - Double(index) * 0.12)))
            }
    }

    private static func orderedBreakdownItems(
        _ breakdown: [CostUsageDailyReport.ModelBreakdown]) -> [CostUsageDailyReport.ModelBreakdown]
    {
        breakdown.sorted { lhs, rhs in
            let lCost = lhs.costUSD ?? -1
            let rCost = rhs.costUSD ?? -1
            if lCost != rCost { return lCost > rCost }

            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens > rTokens }

            return lhs.modelName > rhs.modelName
        }
    }

    private static func barColor(for provider: UsageProvider) -> Color {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private static func windowLabel(days: Int) -> String {
        switch days {
        case 1: L("1d")
        case 7: L("7d")
        case 30: L("30d")
        default: String(format: L("%dd"), days)
        }
    }
}
