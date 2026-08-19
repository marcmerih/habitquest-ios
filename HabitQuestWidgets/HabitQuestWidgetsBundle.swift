import WidgetKit
import SwiftUI

@main
struct HabitQuestWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HabitQuestWidget()
    }
}

struct HabitQuestWidget: Widget {
    let kind = "HabitQuestWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HabitQuestWidgetConfigurationIntent.self,
            provider: HabitQuestWidgetProvider()
        ) { entry in
            HabitQuestWidgetRootView(entry: entry)
        }
        .configurationDisplayName("HabitQuest")
        .description("A calm view of your habits, streak, Momentum, and routines.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
