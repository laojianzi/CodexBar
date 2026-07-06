import CodexBarCore
import SwiftUI

struct LegacyCreditsHistoryMenuView: View {
    private let breakdown: [OpenAIDashboardDailyBreakdown]
    private let width: CGFloat
    @State private var selectedID: String?

    init(breakdown: [OpenAIDashboardDailyBreakdown], width: CGFloat) {
        self.breakdown = breakdown
        self.width = width
    }

    var body: some View {
        let bars = Self.bars(from: self.breakdown)
        VStack(alignment: .leading, spacing: 10) {
            if bars.isEmpty {
                Text(L("No credits history data."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LegacyHistoryBarChartView(bars: bars, selectedID: self.$selectedID)
                let detail = Self.detail(selectedID: self.selectedID, bars: bars)
                Self.detailView(detail)
                if let total = Self.totalCreditsUsed(from: self.breakdown) {
                    Text(String(
                        format: L("Total (30d): %@ credits"),
                        total.formatted(.number.precision(.fractionLength(0...2)))))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private static func bars(from breakdown: [OpenAIDashboardDailyBreakdown]) -> [LegacyHistoryBarChartView.Bar] {
        breakdown
            .sorted { $0.day < $1.day }
            .compactMap { day in
                guard day.totalCreditsUsed > 0 else { return nil }
                let label = self.axisLabel(day.day)
                let total = day.totalCreditsUsed.formatted(.number.precision(.fractionLength(0...2)))
                let services = day.services
                    .sorted { lhs, rhs in
                        if lhs.creditsUsed == rhs.creditsUsed { return lhs.service < rhs.service }
                        return lhs.creditsUsed > rhs.creditsUsed
                    }
                    .prefix(3)
                    .map { "\($0.service) \($0.creditsUsed.formatted(.number.precision(.fractionLength(0...2))))" }
                    .joined(separator: " · ")
                return LegacyHistoryBarChartView.Bar(
                    id: day.day,
                    axisLabel: label,
                    segments: [.init(id: day.day, value: day.totalCreditsUsed, color: self.barColor)],
                    detailPrimary: String(format: L("%@: %@ credits"), label, total),
                    detailSecondary: services.isEmpty ? nil : services)
            }
    }

    private static func totalCreditsUsed(from breakdown: [OpenAIDashboardDailyBreakdown]) -> Double? {
        let total = breakdown.reduce(0) { $0 + $1.totalCreditsUsed }
        return total > 0 ? total : nil
    }

    private static func detail(
        selectedID: String?,
        bars: [LegacyHistoryBarChartView.Bar]) -> (primary: String, secondary: String?)
    {
        guard let selectedID, let bar = bars.first(where: { $0.id == selectedID }) else {
            return (L("Hover a bar for details"), nil)
        }
        return (bar.detailPrimary, bar.detailSecondary)
    }

    fileprivate static func detailView(_ detail: (primary: String, secondary: String?)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(detail.primary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 16, alignment: .leading)
            Text(detail.secondary ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 16, alignment: .leading)
                .opacity(detail.secondary == nil ? 0 : 1)
        }
    }

    fileprivate static func axisLabel(_ key: String) -> String {
        guard let date = dateFromDayKey(key) else { return key }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    fileprivate static func dateFromDayKey(_ key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }

        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone.current
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return comps.date
    }

    private static let barColor = Color(red: 73 / 255, green: 163 / 255, blue: 176 / 255)
}

struct LegacyUsageBreakdownMenuView: View {
    private let breakdown: [OpenAIDashboardDailyBreakdown]
    private let width: CGFloat
    @State private var selectedID: String?

    init(breakdown: [OpenAIDashboardDailyBreakdown], width: CGFloat) {
        self.breakdown = OpenAIDashboardDailyBreakdown.removingSkillUsageServices(from: breakdown)
        self.width = width
    }

    var body: some View {
        let services = Self.serviceOrder(from: self.breakdown)
        let bars = Self.bars(from: self.breakdown, services: services)
        VStack(alignment: .leading, spacing: 10) {
            if bars.isEmpty {
                Text(L("No usage breakdown data."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LegacyHistoryBarChartView(bars: bars, selectedID: self.$selectedID)
                LegacyCreditsHistoryMenuView.detailView(Self.detail(selectedID: self.selectedID, bars: bars))
                self.legend(services: services)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private static func bars(
        from breakdown: [OpenAIDashboardDailyBreakdown],
        services: [String]) -> [LegacyHistoryBarChartView.Bar]
    {
        breakdown
            .sorted { $0.day < $1.day }
            .compactMap { day in
                let segments = services.compactMap { service -> LegacyHistoryBarChartView.Segment? in
                    guard let entry = day.services.first(where: { $0.service == service }),
                          entry.creditsUsed > 0 else { return nil }
                    return .init(id: service, value: entry.creditsUsed, color: self.color(for: service))
                }
                guard !segments.isEmpty else { return nil }
                let label = LegacyCreditsHistoryMenuView.axisLabel(day.day)
                let total = day.totalCreditsUsed.formatted(.number.precision(.fractionLength(0...2)))
                let topServices = day.services
                    .sorted { lhs, rhs in
                        if lhs.creditsUsed == rhs.creditsUsed { return lhs.service < rhs.service }
                        return lhs.creditsUsed > rhs.creditsUsed
                    }
                    .prefix(3)
                    .map { "\($0.service) \($0.creditsUsed.formatted(.number.precision(.fractionLength(0...2))))" }
                    .joined(separator: " · ")
                return LegacyHistoryBarChartView.Bar(
                    id: day.day,
                    axisLabel: label,
                    segments: segments,
                    detailPrimary: String(format: L("%@: %@ credits"), label, total),
                    detailSecondary: topServices.isEmpty ? nil : topServices)
            }
    }

    private static func detail(
        selectedID: String?,
        bars: [LegacyHistoryBarChartView.Bar]) -> (primary: String, secondary: String?)
    {
        guard let selectedID, let bar = bars.first(where: { $0.id == selectedID }) else {
            return (L("Hover a bar for details"), nil)
        }
        return (bar.detailPrimary, bar.detailSecondary)
    }

    private func legend(services: [String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)],
            alignment: .leading,
            spacing: 6)
        {
            ForEach(services, id: \.self) { service in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Self.color(for: service))
                        .frame(width: 7, height: 7)
                    Text(service)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private static func serviceOrder(from breakdown: [OpenAIDashboardDailyBreakdown]) -> [String] {
        var totals: [String: Double] = [:]
        for day in breakdown {
            for service in day.services {
                totals[service.service, default: 0] += service.creditsUsed
            }
        }
        return totals
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .map(\.key)
    }

    private static func color(for service: String) -> Color {
        let lower = service.lowercased()
        if lower == "cli" {
            return Color(red: 0.26, green: 0.55, blue: 0.96)
        }
        if lower.contains("github"), lower.contains("review") {
            return Color(red: 0.94, green: 0.53, blue: 0.18)
        }
        let palette: [Color] = [
            Color(red: 0.46, green: 0.75, blue: 0.36),
            Color(red: 0.80, green: 0.45, blue: 0.92),
            Color(red: 0.26, green: 0.78, blue: 0.86),
            Color(red: 0.94, green: 0.74, blue: 0.26),
        ]
        return palette[abs(service.hashValue) % palette.count]
    }
}
