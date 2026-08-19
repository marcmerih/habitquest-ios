import AppIntents
import SwiftUI
import WidgetKit

enum HabitQuestWidgetMode: String, AppEnum, CaseIterable {
    case today
    case habit
    case multiHabit
    case routine
    case progress
    case streak
    case momentum

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Widget Mode")

    static let caseDisplayRepresentations: [HabitQuestWidgetMode: DisplayRepresentation] = [
            .today: DisplayRepresentation(title: "Today"),
            .habit: DisplayRepresentation(title: "Habit"),
            .multiHabit: DisplayRepresentation(title: "Multiple Habits"),
            .routine: DisplayRepresentation(title: "Routine"),
            .progress: DisplayRepresentation(title: "Progress"),
            .streak: DisplayRepresentation(title: "Streak"),
            .momentum: DisplayRepresentation(title: "Momentum")
    ]
}

enum HabitQuestWidgetPresentation: String, AppEnum, CaseIterable {
    case compact
    case balanced
    case spacious

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Presentation")

    static let caseDisplayRepresentations: [HabitQuestWidgetPresentation: DisplayRepresentation] = [
        .compact: DisplayRepresentation(title: "Compact"),
        .balanced: DisplayRepresentation(title: "Balanced"),
        .spacious: DisplayRepresentation(title: "Spacious")
    ]
}

enum HabitQuestWidgetProgressType: String, AppEnum, CaseIterable {
    case today
    case streak
    case momentum
    case completionRate

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Progress Metric")

    static let caseDisplayRepresentations: [HabitQuestWidgetProgressType: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: "Today"),
        .streak: DisplayRepresentation(title: "Daily Streak"),
        .momentum: DisplayRepresentation(title: "Momentum"),
        .completionRate: DisplayRepresentation(title: "Completion Rate")
    ]
}

struct HabitQuestWidgetHabitEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
    static let defaultQuery = HabitQuestWidgetHabitQuery()

    var id: UUID
    var title: String
    var category: String?
    var icon: String?
    var isPaused: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: category.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }
}

struct HabitQuestWidgetDaySectionEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Day Section")
    static let defaultQuery = HabitQuestWidgetDaySectionQuery()

    var id: UUID
    var title: String
    var icon: String?
    var isActive: Bool
    var order: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
    }
}

struct HabitQuestWidgetHabitQuery: EntityQuery {
    func entities(for identifiers: [HabitQuestWidgetHabitEntity.ID]) async throws -> [HabitQuestWidgetHabitEntity] {
        let snapshot = HabitQuestWidgetSnapshotStore.shared.loadSnapshot()
        return snapshot.habits
            .filter { identifiers.contains($0.id) }
            .map { HabitQuestWidgetHabitEntity(id: $0.id, title: $0.title, category: $0.category, icon: $0.icon, isPaused: $0.isPaused) }
    }

    func suggestedEntities() async throws -> [HabitQuestWidgetHabitEntity] {
        let snapshot = HabitQuestWidgetSnapshotStore.shared.loadSnapshot()
        return snapshot.habits
            .filter { !$0.isArchived }
            .prefix(8)
            .map { HabitQuestWidgetHabitEntity(id: $0.id, title: $0.title, category: $0.category, icon: $0.icon, isPaused: $0.isPaused) }
    }

    func defaultResult() async -> HabitQuestWidgetHabitEntity? {
        try? await suggestedEntities().first
    }
}

struct HabitQuestWidgetDaySectionQuery: EntityQuery {
    func entities(for identifiers: [HabitQuestWidgetDaySectionEntity.ID]) async throws -> [HabitQuestWidgetDaySectionEntity] {
        let snapshot = HabitQuestWidgetSnapshotStore.shared.loadSnapshot()
        return snapshot.sections
            .filter { identifiers.contains($0.id) }
            .map { HabitQuestWidgetDaySectionEntity(id: $0.id, title: $0.name, icon: $0.icon, isActive: $0.isActive, order: $0.order) }
    }

    func suggestedEntities() async throws -> [HabitQuestWidgetDaySectionEntity] {
        let snapshot = HabitQuestWidgetSnapshotStore.shared.loadSnapshot()
        return snapshot.sections
            .filter { $0.isActive }
            .prefix(6)
            .map { HabitQuestWidgetDaySectionEntity(id: $0.id, title: $0.name, icon: $0.icon, isActive: $0.isActive, order: $0.order) }
    }

    func defaultResult() async -> HabitQuestWidgetDaySectionEntity? {
        try? await suggestedEntities().first
    }
}

struct HabitQuestWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "HabitQuest Widget"
    static let description = IntentDescription("Customize a calm HabitQuest widget.")

    @Parameter(title: "Widget Mode", default: .today)
    var mode: HabitQuestWidgetMode

    @Parameter(title: "Habit")
    var habit: HabitQuestWidgetHabitEntity?

    @Parameter(title: "First Habit")
    var firstHabit: HabitQuestWidgetHabitEntity?

    @Parameter(title: "Second Habit")
    var secondHabit: HabitQuestWidgetHabitEntity?

    @Parameter(title: "Third Habit")
    var thirdHabit: HabitQuestWidgetHabitEntity?

    @Parameter(title: "Day Section")
    var section: HabitQuestWidgetDaySectionEntity?

    @Parameter(title: "Progress Metric", default: .today)
    var progressType: HabitQuestWidgetProgressType

    @Parameter(title: "Presentation", default: .balanced)
    var presentation: HabitQuestWidgetPresentation
}

struct HabitQuestWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: HabitQuestWidgetSnapshot
    let configuration: HabitQuestWidgetConfigurationIntent
}

struct HabitQuestWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = HabitQuestWidgetConfigurationIntent
    typealias Entry = HabitQuestWidgetEntry

    func placeholder(in context: Context) -> HabitQuestWidgetEntry {
        HabitQuestWidgetEntry(
            date: .now,
            snapshot: .empty,
            configuration: HabitQuestWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: HabitQuestWidgetConfigurationIntent, in context: Context) async -> HabitQuestWidgetEntry {
        HabitQuestWidgetEntry(
            date: .now,
            snapshot: HabitQuestWidgetSnapshotStore.shared.loadSnapshot(),
            configuration: configuration
        )
    }

    func timeline(for configuration: HabitQuestWidgetConfigurationIntent, in context: Context) async -> Timeline<HabitQuestWidgetEntry> {
        let snapshot = HabitQuestWidgetSnapshotStore.shared.loadSnapshot()
        let entry = HabitQuestWidgetEntry(date: snapshot.generatedAt, snapshot: snapshot, configuration: configuration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
    }
}

struct HabitQuestWidgetRootView: View {
    let entry: HabitQuestWidgetEntry

    var body: some View {
        let view = widgetBody
            .padding(16)
            .containerBackground(widgetBackground, for: .widget)

        view
    }

    @ViewBuilder
    private var widgetBody: some View {
        let snapshot = entry.snapshot
        if snapshot.accessTier.allowsAdvancedWidgets {
            switch entry.configuration.mode {
            case .today:
                todayView(snapshot: snapshot)
            case .habit:
                habitView(snapshot: snapshot)
            case .multiHabit:
                multiHabitView(snapshot: snapshot)
            case .routine:
                routineView(snapshot: snapshot)
            case .progress:
                progressView(snapshot: snapshot)
            case .streak:
                streakView(snapshot: snapshot)
            case .momentum:
                momentumView(snapshot: snapshot)
            }
        } else {
            freeFallbackView(snapshot: snapshot)
        }
    }

    private var widgetBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.08, blue: 0.05),
                Color(red: 0.19, green: 0.12, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func todayView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "Today", subtitle: "What matters now")
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                widgetMetric(value: "\(snapshot.metrics.todayCompleted)", label: "Done")
                widgetMetric(value: "\(snapshot.metrics.todayRemaining)", label: "Waiting")
                widgetMetric(value: "\(snapshot.metrics.currentDailyStreak)", label: "Streak")
            }
            widgetProgressBar(completion: completionFraction(from: snapshot.metrics))
            widgetFooter(text: "Momentum \(Int(snapshot.metrics.currentMomentum.rounded()))")
        }
    }

    private func habitView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        let habit = selectedHabit(from: snapshot)
        return VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "Habit", subtitle: habit?.title ?? "No habit selected")
            if let habit {
                widgetHabitRow(habit)
            } else {
                freeFallbackBody(text: "Select a habit to keep this widget focused.")
            }
        }
    }

    private func multiHabitView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        let habits = selectedHabits(from: snapshot)
        return VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "Multiple Habits", subtitle: "A small stack of intentions")
            if habits.isEmpty {
                freeFallbackBody(text: "Choose a few habits to keep here.")
            } else {
                VStack(spacing: 8) {
                    ForEach(habits) { habit in
                        widgetHabitRow(habit)
                    }
                }
            }
        }
    }

    private func routineView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        let section = selectedSection(from: snapshot)
        return VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "Routine", subtitle: section?.name ?? "No routine selected")
            if let section {
                widgetSectionRow(section)
            } else {
                freeFallbackBody(text: "Select a Morning, Afternoon, or Evening section.")
            }
        }
    }

    private func progressView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        let title: String
        let value: String
        let label: String

        switch entry.configuration.progressType {
        case .today:
            title = "Today"
            value = "\(snapshot.metrics.todayCompleted)/\(max(snapshot.metrics.todayCompleted + snapshot.metrics.todayRemaining, 1))"
            label = "complete"
        case .streak:
            title = "Daily Streak"
            value = "\(snapshot.metrics.currentDailyStreak)"
            label = "days"
        case .momentum:
            title = "Momentum"
            value = "\(Int(snapshot.metrics.currentMomentum.rounded()))"
            label = "score"
        case .completionRate:
            title = "Completion"
            value = snapshot.metrics.completionRate.map { "\(Int($0.rounded()))%" } ?? "—"
            label = "rate"
        }

        return VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: title, subtitle: "Quiet progress at a glance")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(value)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
            }
            widgetProgressBar(completion: completionFraction(from: snapshot.metrics))
        }
    }

    private func streakView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "Streak", subtitle: "Current daily streak")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(snapshot.metrics.currentDailyStreak)")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("days")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
            }
            widgetFooter(text: "Best: \(snapshot.metrics.longestDailyStreak) days")
        }
    }

    private func momentumView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "Momentum", subtitle: "A gentle rolling score")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(Int(snapshot.metrics.currentMomentum.rounded()))")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("/ 100")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
            }
            widgetProgressBar(completion: min(max(snapshot.metrics.currentMomentum / 100.0, 0), 1))
        }
    }

    private func freeFallbackView(snapshot: HabitQuestWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(title: "HabitQuest Premium", subtitle: "Advanced widgets are paused")
            freeFallbackBody(text: "This widget becomes richer again when Premium returns.")
            HStack(spacing: 12) {
                widgetMetric(value: "\(snapshot.metrics.currentDailyStreak)", label: "Streak")
                widgetMetric(value: "\(Int(snapshot.metrics.currentMomentum.rounded()))", label: "Momentum")
            }
        }
    }

    private func freeFallbackBody(text: String) -> some View {
        Text(text)
            .font(.system(.callout, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func widgetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func widgetMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func widgetProgressBar(completion: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.12))
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.88))
                    .frame(width: proxy.size.width * completion)
            }
        }
        .frame(height: 8)
    }

    private func widgetFooter(text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
    }

    private func widgetHabitRow(_ habit: HabitQuestWidgetHabitSummary) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 28, height: 28)
                Text((habit.icon ?? "•").prefix(1))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(habit.currentStreak) day streak")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
    }

    private func widgetSectionRow(_ section: HabitQuestWidgetDaySectionSummary) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 28, height: 28)
                Text((section.icon ?? "◌").prefix(1))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(section.name)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(section.subtitle ?? "Routine section")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
    }

    private func selectedHabit(from snapshot: HabitQuestWidgetSnapshot) -> HabitQuestWidgetHabitSummary? {
        let candidates = [entry.configuration.habit?.id, entry.configuration.firstHabit?.id, entry.configuration.secondHabit?.id, entry.configuration.thirdHabit?.id]
            .compactMap { $0 }

        if let match = candidates.compactMap({ id in snapshot.habits.first(where: { $0.id == id }) }).first {
            return match
        }

        return snapshot.habits.first(where: { !$0.isArchived })
    }

    private func selectedHabits(from snapshot: HabitQuestWidgetSnapshot) -> [HabitQuestWidgetHabitSummary] {
        let ids = [entry.configuration.habit?.id, entry.configuration.firstHabit?.id, entry.configuration.secondHabit?.id, entry.configuration.thirdHabit?.id]
            .compactMap { $0 }

        if !ids.isEmpty {
            return ids.compactMap { id in snapshot.habits.first(where: { $0.id == id }) }
        }

        return Array(snapshot.habits.filter { !$0.isArchived }.prefix(3))
    }

    private func selectedSection(from snapshot: HabitQuestWidgetSnapshot) -> HabitQuestWidgetDaySectionSummary? {
        if let sectionID = entry.configuration.section?.id {
            return snapshot.sections.first(where: { $0.id == sectionID })
        }
        return snapshot.sections.first(where: { $0.isActive })
    }

    private func completionFraction(from metrics: HabitQuestWidgetMetricsSummary) -> Double {
        let total = max(metrics.todayCompleted + metrics.todayRemaining, 1)
        return min(max(Double(metrics.todayCompleted) / Double(total), 0), 1)
    }
}

private extension Color {
    init?(hexString: String?) {
        guard let hexString else { return nil }
        let trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}
