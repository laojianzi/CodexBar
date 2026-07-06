import CodexBarCore
import SwiftUI
import WidgetKit

struct LegacyBurnDownWidgetView: View {
    let entry: BurnDownEntry

    var body: some View {
        let state = BurnDownState(
            snapshot: self.entry.snapshot,
            provider: self.entry.provider,
            selection: self.entry.window)
        ZStack {
            Color.black.opacity(0.02)
            if let state, let window = state.selectedWindow {
                LegacyBurnDownContent(
                    provider: self.entry.provider,
                    updatedAt: state.entry.updatedAt,
                    title: burnWindowLabel(window.windowMinutes),
                    window: window,
                    blankChart: state.blankPrimaryChart,
                    resetOverride: state.selectedResetOverride)
            } else {
                self.emptyState
            }
        }
        .codexWidgetBackground()
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Open CodexBar")
                .font(.body)
                .fontWeight(.semibold)
            Text("Usage data will appear once the app refreshes.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct LegacyCombinedBurnDownWidgetView: View {
    let entry: CombinedBurnDownEntry

    var body: some View {
        let state = BurnDownState(
            snapshot: self.entry.snapshot,
            provider: self.entry.provider,
            selection: .session)
        ZStack {
            Color.black.opacity(0.02)
            if let state {
                VStack(alignment: .leading, spacing: 10) {
                    HeaderView(provider: self.entry.provider, updatedAt: state.entry.updatedAt)
                    VStack(spacing: 8) {
                        if let primary = state.primaryWindow {
                            LegacyBurnDownRow(
                                title: burnWindowLabel(primary.windowMinutes),
                                window: primary,
                                blankChart: state.blankPrimaryChart,
                                resetOverride: state.selectedResetOverride)
                        }
                        if let secondary = state.secondaryWindow {
                            LegacyBurnDownRow(
                                title: burnWindowLabel(secondary.windowMinutes),
                                window: secondary)
                        }
                    }
                }
                .padding(12)
            } else {
                self.emptyState
            }
        }
        .codexWidgetBackground()
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Open CodexBar")
                .font(.body)
                .fontWeight(.semibold)
            Text("Usage data will appear once the app refreshes.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

private struct LegacyBurnDownContent: View {
    let provider: UsageProvider
    let updatedAt: Date
    let title: String
    let window: RateWindow
    var blankChart = false
    var resetOverride: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(provider: self.provider, updatedAt: self.updatedAt)
            LegacyBurnDownRow(
                title: self.title,
                window: self.window,
                blankChart: self.blankChart,
                resetOverride: self.resetOverride,
                expanded: true)
        }
        .padding(12)
    }
}

private struct LegacyBurnDownRow: View {
    let title: String
    let window: RateWindow
    var blankChart = false
    var resetOverride: Date?
    var expanded = false

    var body: some View {
        let remaining = max(0, min(100, self.window.remainingPercent))
        let resetAt = self.resetOverride ?? self.window.resetsAt
        VStack(alignment: .leading, spacing: self.expanded ? 10 : 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let resetAt {
                    Text(resetAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(remaining.rounded()))")
                    .font(self.expanded ? .system(size: 36, weight: .semibold) : .title3.weight(.semibold))
                    .monospacedDigit()
                Text("% left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                    if !self.blankChart {
                        Capsule()
                            .fill(self.progressColor)
                            .frame(width: proxy.size.width * CGFloat(remaining / 100))
                    }
                }
            }
            .frame(height: self.expanded ? 9 : 6)
        }
    }

    private var progressColor: Color {
        if self.window.remainingPercent <= 10 { return .red }
        if self.window.remainingPercent <= 25 { return .orange }
        return .accentColor
    }
}
