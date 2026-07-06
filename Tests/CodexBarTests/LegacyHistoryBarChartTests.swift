import SwiftUI
import Testing
@testable import CodexBar

struct LegacyHistoryBarChartTests {
    @Test
    func `normalizes bars against the largest stacked total`() {
        let bars = [
            LegacyHistoryBarChartView.Bar(
                id: "a",
                axisLabel: "A",
                segments: [.init(id: "a1", value: 2, color: .blue)],
                detailPrimary: "A"),
            LegacyHistoryBarChartView.Bar(
                id: "b",
                axisLabel: "B",
                segments: [
                    .init(id: "b1", value: 3, color: .blue),
                    .init(id: "b2", value: 1, color: .green),
                ],
                detailPrimary: "B"),
        ]

        let model = LegacyHistoryBarChartView.Model(bars: bars)

        #expect(model.maxValue == 4)
        #expect(model.normalizedTotal(for: bars[0]) == 0.5)
        #expect(model.normalizedTotal(for: bars[1]) == 1)
    }

    @Test
    func `empty bars keep a positive denominator`() {
        let model = LegacyHistoryBarChartView.Model(bars: [])

        #expect(model.maxValue == 1)
    }

    @Test
    func `selection maps x position to bar id`() {
        let bars = (0..<3).map { index in
            LegacyHistoryBarChartView.Bar(
                id: "\(index)",
                axisLabel: "\(index)",
                segments: [.init(id: "\(index)", value: 1, color: .blue)],
                detailPrimary: "\(index)")
        }
        let model = LegacyHistoryBarChartView.Model(bars: bars)

        #expect(model.barID(atX: 0, width: 300) == "0")
        #expect(model.barID(atX: 149, width: 300) == "1")
        #expect(model.barID(atX: 299, width: 300) == "2")
        #expect(model.barID(atX: 301, width: 300) == nil)
    }
}
