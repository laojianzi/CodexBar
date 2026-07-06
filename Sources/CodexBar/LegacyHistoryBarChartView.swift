import SwiftUI

struct LegacyHistoryBarChartView: View {
    struct Segment: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    struct Bar: Identifiable {
        let id: String
        let axisLabel: String
        let segments: [Segment]
        let detailPrimary: String
        var detailSecondary: String?

        var total: Double {
            self.segments.reduce(0) { $0 + max(0, $1.value) }
        }
    }

    struct Model {
        let bars: [Bar]
        let maxValue: Double

        init(bars: [Bar], maxValue: Double? = nil) {
            self.bars = bars
            self.maxValue = max(maxValue ?? bars.map(\.total).max() ?? 0, 1)
        }

        func normalizedTotal(for bar: Bar) -> Double {
            min(max(bar.total / self.maxValue, 0), 1)
        }

        func barID(atX x: CGFloat, width: CGFloat) -> String? {
            guard width > 0, x >= 0, x <= width, !self.bars.isEmpty else { return nil }
            let slotWidth = width / CGFloat(self.bars.count)
            let index = min(max(Int(x / slotWidth), 0), self.bars.count - 1)
            return self.bars[index].id
        }
    }

    let model: Model
    let height: CGFloat
    @Binding var selectedID: String?

    init(bars: [Bar], height: CGFloat = 130, maxValue: Double? = nil, selectedID: Binding<String?>) {
        self.model = Model(bars: bars, maxValue: maxValue)
        self.height = height
        self._selectedID = selectedID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(self.model.bars) { bar in
                            self.barView(bar, availableHeight: proxy.size.height)
                        }
                    }
                    MouseLocationReader { location in
                        self.updateSelection(location: location, width: proxy.size.width)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
            }
            .frame(height: self.height)
            .accessibilityLabel(L("History chart"))
            .accessibilityValue(String(format: L("%d chart bars"), self.model.bars.count))

            self.axisLabels
        }
    }

    private func barView(_ bar: Bar, availableHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            if self.selectedID == bar.id {
                Rectangle()
                    .fill(Color(nsColor: .labelColor).opacity(0.1))
            }
            VStack(spacing: 0) {
                ForEach(bar.segments.reversed()) { segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(height: self.segmentHeight(segment, bar: bar, availableHeight: availableHeight))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var axisLabels: some View {
        HStack {
            if let first = self.model.bars.first {
                Text(first.axisLabel)
                    .font(.caption2)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
            Spacer()
            if let last = self.model.bars.last, last.id != self.model.bars.first?.id {
                Text(last.axisLabel)
                    .font(.caption2)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .frame(height: 16)
    }

    private func segmentHeight(_ segment: Segment, bar: Bar, availableHeight: CGFloat) -> CGFloat {
        guard bar.total > 0 else { return 0 }
        let totalHeight = availableHeight * self.model.normalizedTotal(for: bar)
        return totalHeight * CGFloat(max(0, segment.value) / bar.total)
    }

    private func updateSelection(location: CGPoint?, width: CGFloat) {
        guard let location else { return }
        let nextID = self.model.barID(atX: location.x, width: width)
        if self.selectedID != nextID {
            self.selectedID = nextID
        }
    }
}
