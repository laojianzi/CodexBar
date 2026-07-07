import SwiftUI
import WidgetKit

@main
struct CodexBarWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        CodexBarSwitcherWidget()
        // ponytail: WidgetBundleBuilder on macOS 12 accepts single-arm availability, not if/else.
        LegacyCodexBarUsageWidget()
        LegacyCodexBarHistoryWidget()
        LegacyCodexBarCreditsWidget()
        LegacyCodexBarTodayCostWidget()
        LegacyCodexBarLast30DaysCostWidget()
        LegacyCodexBarSessionBurnDownWidget()
        LegacyCodexBarWeeklyBurnDownWidget()
        LegacyCodexBarCombinedBurnDownWidget()
        if #available(macOS 14.0, *) {
            CodexBarUsageWidget()
            CodexBarHistoryWidget()
            CodexBarCompactWidget()
            CodexBarBurnDownWidget()
            CodexBarCombinedBurnDownWidget()
        }
    }
}

struct CodexBarSwitcherWidget: Widget {
    private let kind = "CodexBarSwitcherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: CodexBarSwitcherTimelineProvider())
        { entry in
            CodexBarSwitcherWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Switcher")
        .description("Usage widget with a provider switcher.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LegacyCodexBarUsageWidget: Widget {
    private let kind = "CodexBarLegacyUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyCodexBarTimelineProvider())
        { entry in
            CodexBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Usage")
        .description("Session and weekly usage with credits and costs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LegacyCodexBarHistoryWidget: Widget {
    private let kind = "CodexBarLegacyHistoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyCodexBarTimelineProvider())
        { entry in
            CodexBarHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar History")
        .description("Usage history chart with recent totals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct LegacyCodexBarCreditsWidget: Widget {
    private let kind = "CodexBarLegacyCreditsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyCodexBarCompactTimelineProvider(metric: .credits))
        { entry in
            CodexBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Credits")
        .description("Compact widget for credits remaining.")
        .supportedFamilies([.systemSmall])
    }
}

struct LegacyCodexBarTodayCostWidget: Widget {
    private let kind = "CodexBarLegacyTodayCostWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyCodexBarCompactTimelineProvider(metric: .todayCost))
        { entry in
            CodexBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Today Cost")
        .description("Compact widget for current session cost.")
        .supportedFamilies([.systemSmall])
    }
}

struct LegacyCodexBarLast30DaysCostWidget: Widget {
    private let kind = "CodexBarLegacyLast30DaysCostWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyCodexBarCompactTimelineProvider(metric: .last30DaysCost))
        { entry in
            CodexBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar 30d Cost")
        .description("Compact widget for recent total cost.")
        .supportedFamilies([.systemSmall])
    }
}

struct LegacyCodexBarSessionBurnDownWidget: Widget {
    private let kind = "CodexBarLegacySessionBurnDownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyBurnDownTimelineProvider(window: .session))
        { entry in
            LegacyBurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Session Burn Down")
        .description("Session budget compared with remaining time.")
        .supportedFamilies([.systemMedium])
    }
}

struct LegacyCodexBarWeeklyBurnDownWidget: Widget {
    private let kind = "CodexBarLegacyWeeklyBurnDownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyBurnDownTimelineProvider(window: .weekly))
        { entry in
            LegacyBurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Weekly Burn Down")
        .description("Weekly budget compared with remaining time.")
        .supportedFamilies([.systemMedium])
    }
}

struct LegacyCodexBarCombinedBurnDownWidget: Widget {
    private let kind = "CodexBarLegacyCombinedBurnDownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: self.kind,
            provider: LegacyCombinedBurnDownTimelineProvider())
        { entry in
            LegacyCombinedBurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Burn Down (Combined)")
        .description("Session and weekly burn-down status in one tile.")
        .supportedFamilies([.systemMedium])
    }
}

@available(macOS 14.0, *)
struct CodexBarUsageWidget: Widget {
    private let kind = "CodexBarUsageWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: CodexBarTimelineProvider())
        { entry in
            CodexBarUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Usage")
        .description("Session and weekly usage with credits and costs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(macOS 14.0, *)
struct CodexBarHistoryWidget: Widget {
    private let kind = "CodexBarHistoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: ProviderSelectionIntent.self,
            provider: CodexBarTimelineProvider())
        { entry in
            CodexBarHistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar History")
        .description("Usage history chart with recent totals.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@available(macOS 14.0, *)
struct CodexBarCompactWidget: Widget {
    private let kind = "CodexBarCompactWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: CompactMetricSelectionIntent.self,
            provider: CodexBarCompactTimelineProvider())
        { entry in
            CodexBarCompactWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Metric")
        .description("Compact widget for credits or cost.")
        .supportedFamilies([.systemSmall])
    }
}

@available(macOS 14.0, *)
struct CodexBarBurnDownWidget: Widget {
    private let kind = "CodexBarBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnDownSelectionIntent.self,
            provider: BurnDownTimelineProvider())
        { entry in
            BurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Burn Down")
        .description("Remaining budget compared with an ideal steady burn rate.")
        .supportedFamilies([.systemMedium])
    }
}

@available(macOS 14.0, *)
struct CodexBarCombinedBurnDownWidget: Widget {
    private let kind = "CodexBarCombinedBurnDownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: self.kind,
            intent: BurnProviderSelectionIntent.self,
            provider: CombinedBurnDownTimelineProvider())
        { entry in
            CombinedBurnDownWidgetView(entry: entry)
        }
        .configurationDisplayName("CodexBar Burn Down (Combined)")
        .description("Session and weekly burn-down charts in one tile.")
        .supportedFamilies([.systemMedium])
    }
}
