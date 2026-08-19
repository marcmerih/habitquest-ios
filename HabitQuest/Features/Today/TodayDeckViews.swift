import Foundation
import SwiftUI

struct TodayDeckView: View {
    let onOpenHabits: () -> Void

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(HabitQuestProfileKeys.displayName) private var displayName = "Local member"

    @State private var habitsByID: [UUID: Habit] = [:]
    @State private var daySectionsByID: [UUID: HabitDaySection] = [:]
    @State private var persistedStates: [DailyHabitState] = []
    @State private var orderedStates: [DailyHabitState] = []
    @State private var momentumSummary: MomentumSummary?
    @State private var loadErrorMessage: String?
    @State private var isLoading = true
    @State private var isSavingAction = false
    @State private var inspectionContext: TodayHabitInspectionContext?
    @State private var programmaticSwipeRequest: TodayProgrammaticSwipeRequest?

    init(onOpenHabits: @escaping () -> Void = {}) {
        self.onOpenHabits = onOpenHabits
    }

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            ScrollView {
                VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    headerSection
                    deckSection
                    if showsSwipeActions {
                        actionButtons
                        todayAtAGlanceCard
                    }
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.sm)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.md)
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.01) : HabitQuestDesignSystem.Motion.card, value: deckStateKey)
        .task {
            await reloadDeck()
        }
        .refreshable {
            await reloadDeck()
        }
        .sheet(item: $inspectionContext) { context in
            TodayHabitInspectionView(context: context)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await reloadDeck() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await reloadDeck() }
        }
    }

    private var heroHeading: String {
        if isDayComplete {
            return "Day complete"
        }

        switch currentRhythmContext.title {
        case "Morning":
            return greetingTitle(for: "Morning")
        case "Day":
            return greetingTitle(for: "Afternoon")
        case "Evening":
            return greetingTitle(for: "Evening")
        default:
            return greetingTitle(for: "Night")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(heroHeading)
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Spacer(minLength: 0)

                Text(environment.dateService.now.formatted(date: .abbreviated, time: .omitted))
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                TodayMetricStat(
                    icon: "flame.fill",
                    value: "\(currentStreak)",
                    tint: HabitQuestDesignSystem.Palette.success(for: colorScheme)
                )
                TodayMetricStat(
                    icon: "gauge.with.dots.needle.67percent",
                    value: momentumDisplayText,
                    tint: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                )
                TodayMetricStat(
                    icon: "circle.lefthalf.filled",
                    value: "\(Int((completionProgress * 100).rounded()))%",
                    tint: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func greetingTitle(for period: String) -> String {
        "Good \(period)\(greetingSuffix)"
    }

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack {
                Text("Today Deck")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Spacer(minLength: 0)

                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.dangerMuted(for: colorScheme))
                        .multilineTextAlignment(.trailing)
                }
            }

            if isLoading {
                loadingStateCard
            } else if isDayComplete {
                completedDayCard
            } else if actionableStates.isEmpty, !waitingStates.isEmpty {
                waitingStateCard
            } else if let emptyReason = emptyStateReason {
                emptyStateCard(for: emptyReason)
            } else {
                deckStack
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deckStateKey: String {
        if isLoading {
            return "loading"
        }

        if isDayComplete {
            return "complete"
        }

        if actionableStates.isEmpty, !waitingStates.isEmpty {
            return "waiting"
        }

        if let emptyReason = emptyStateReason {
            return "empty-\(String(describing: emptyReason))"
        }

        return "deck"
    }

    private var showsSwipeActions: Bool {
        !isLoading && emptyStateReason == nil && !actionableStates.isEmpty
    }

    private var loadingStateCard: some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            ProgressView()
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            Text("Preparing today’s cards")
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("HabitQuest is loading your current deck and restoring any saved daily state.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .habitQuestSurface(.raised)
    }

    private var completedDayCard: some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
            Spacer(minLength: 0)

            Circle()
                .fill(HabitQuestDesignSystem.Palette.success(for: colorScheme).opacity(0.14))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.success(for: colorScheme))
                )

            VStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                Text("Day complete")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(completionQuote)
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                SummaryBadge(title: "\(currentStreak) day streak", accent: HabitQuestDesignSystem.Palette.success(for: colorScheme))
                SummaryBadge(title: "\(completedStates.count) completed", accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 386)
        .multilineTextAlignment(.center)
        .habitQuestSurface(.raised)
    }

    private var todayAtAGlanceCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today at a glance")
                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Spacer(minLength: 0)

                Text("\(completedStates.count)/\(totalRelevantStates)")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            }

            if completedStates.isEmpty {
                Text("Nothing completed yet.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    @ViewBuilder
    private func emptyStateCard(for reason: TodayEmptyStateReason) -> some View {
        switch reason {
        case .noHabitsCreated:
            CalmEmptyStateCard(
                icon: "sparkles",
                title: "Create your first habit",
                message: "Habits you create will appear here when they’re due.",
                accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme),
                supportingText: "Start in Habits when you’re ready.",
                primaryActionTitle: "Open Habits",
                primaryAction: onOpenHabits,
            )
        case .allHabitsPaused:
            CalmEmptyStateCard(
                icon: "pause.circle",
                title: "All habits are paused",
                message: "Nothing is expected right now.",
                accent: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                supportingText: "Resume one in Habits when the timing feels right.",
                primaryActionTitle: "Open Habits",
                primaryAction: onOpenHabits,
            )
        case .archivedOnlyLibrary:
            CalmEmptyStateCard(
                icon: "archivebox",
                title: "Your active library is archived",
                message: "No active habits are available for Today.",
                accent: HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme),
                supportingText: "Restore one in Habits when you want it back.",
                primaryActionTitle: "Open Habits",
                primaryAction: onOpenHabits,
            )
        case .noHabitsDueToday:
            CalmEmptyStateCard(
                icon: "calendar",
                title: "Nothing is due right now",
                message: "Check back later, or adjust a habit if you want it to appear sooner.",
                accent: HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme),
                supportingText: nil,
                primaryActionTitle: "Open Habits",
                primaryAction: onOpenHabits,
            )
        }
    }

    private var waitingStateCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("\(completedStates.count) done · \(waitingStates.count) waiting for later")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("You’ve finished the current pass. The remaining cards are resting quietly and will return when they are ready.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if let nextReturn = waitingStates.compactMap(\.nextEligibleAt).min() {
                Text("Next return around \(nextReturn.formatted(date: .omitted, time: .shortened)).")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var deckStack: some View {
        let deckEntries = actionableStates.compactMap { state -> TodayDeckEntry? in
            guard let habit = habitsByID[state.habitID] else { return nil }
            return TodayDeckEntry(
                habit: habit,
                state: state,
                daySection: habit.daySectionID.flatMap { daySectionsByID[$0] }
            )
        }
        let visibleEntries = Array(deckEntries.prefix(4))

        return ZStack(alignment: .top) {
            ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, state in
                TodayDeckCardView(
                    entry: state,
                    isTopCard: index == 0,
                    isBusy: isSavingAction,
                    reduceMotion: reduceMotion,
                    programmaticSwipeRequest: index == 0 ? programmaticSwipeRequest : nil,
                    onThresholdCrossed: {
                        environment.hapticService.play(.swipeThresholdCrossed)
                    },
                    onInspect: {
                        inspectionContext = TodayHabitInspectionContext(habit: state.habit, state: state.state)
                    },
                    onComplete: {
                        Task { await resolveTopCard(action: .complete, source: .todayDeckSwipe) }
                    },
                    onDefer: {
                        Task { await resolveTopCard(action: .notNow) }
                    },
                    onProgrammaticSwipeFinished: { direction in
                        Task { await handleProgrammaticSwipeFinished(direction) }
                    }
                )
                .offset(y: CGFloat(index) * 10)
                .scaleEffect(1 - (CGFloat(index) * 0.02))
                .opacity(1 - (CGFloat(index) * 0.10))
                .zIndex(Double(visibleEntries.count - index))
            }
        }
        .frame(height: 438)
    }

    private var actionButtons: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            Button {
                triggerProgrammaticSwipe(.notNow)
            } label: {
                Label("Not Now", systemImage: "arrow.uturn.left")
            }
            .buttonStyle(HabitQuestButtonStyle(role: .secondary))
            .disabled(actionableStates.isEmpty || isSavingAction || programmaticSwipeRequest != nil)

            Button {
                triggerProgrammaticSwipe(.complete)
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .buttonStyle(HabitQuestButtonStyle(role: .primary))
            .disabled(actionableStates.isEmpty || isSavingAction || programmaticSwipeRequest != nil)
        }
        .accessibilityElement(children: .contain)
    }

    private var actionableStates: [DailyHabitState] {
        orderedStates.filter(\.isActionable)
    }

    private var completedStates: [DailyHabitState] {
        orderedStates.filter { $0.status == .completed }
    }

    private var waitingStates: [DailyHabitState] {
        orderedStates.filter { $0.status == .deferred }
    }

    private var remainingCount: Int {
        actionableStates.count + waitingStates.count
    }

    private var isDayComplete: Bool {
        totalRelevantStates > 0 && remainingCount == 0
    }

    private var completionProgress: Double {
        guard totalRelevantStates > 0 else {
            return 0
        }

        return Double(completedStates.count) / Double(totalRelevantStates)
    }

    private var totalRelevantStates: Int {
        completedStates.count + remainingCount
    }

    private var completedHabitSummaries: [CompletedHabitSummary] {
        completedStates.compactMap { state in
            guard let habit = habitsByID[state.habitID] else { return nil }
            return CompletedHabitSummary(id: state.id, title: habit.title, icon: habit.icon, category: habit.category)
        }
    }

    private var currentStreak: Int {
        computeCurrentStreak()
    }

    private var momentumDisplayText: String {
        guard let momentumSummary else {
            return "0"
        }

        return "\(Int(momentumSummary.currentMomentum.rounded()))"
    }

    private var completionQuote: String {
        let quotes = [
            "A quiet win still counts.",
            "Progress can be gentle and still be progress.",
            "You showed up today, and that matters.",
            "Small habits keep shaping the day.",
            "Calm consistency is still momentum.",
            "One finished day is a strong day."
        ]

        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: environment.dateService.now) ?? 0
        let index = abs(dayIndex) % quotes.count
        return quotes[index]
    }

    private var greetingSuffix: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "local member" else {
            return ""
        }

        return ", \(trimmed)"
    }

    private var currentRhythmContext: CurrentRhythmContext {
        rhythmContext(for: environment.dateService.now)
    }

    private var emptyStateReason: TodayEmptyStateReason? {
        let habits = Array(habitsByID.values)

        guard !habits.isEmpty else {
            return .noHabitsCreated
        }

        if habits.allSatisfy(\.isArchived) {
            return .archivedOnlyLibrary
        }

        let nonArchivedHabits = habits.filter { !$0.isArchived }
        if !nonArchivedHabits.isEmpty, nonArchivedHabits.allSatisfy(\.isPaused) {
            return .allHabitsPaused
        }

        if actionableStates.isEmpty, waitingStates.isEmpty, completedStates.isEmpty {
            return .noHabitsDueToday
        }

        return nil
    }

    @MainActor
    private func reloadDeck() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let now = environment.dateService.now
            let calendar = environment.dateService.calendar
            _ = try environment.dayResolutionService.resolveElapsedDays(
                upTo: now,
                calendar: calendar
            )
            let habits = try environment.habitRepository.fetchHabits()
            let customSections = try environment.habitDaySectionStore.loadSections()
            let sectionsByID = Dictionary(uniqueKeysWithValues: HabitDaySectionCatalog.allSections(customSections: customSections).map { ($0.id, $0) })
            let persistedStates = try environment.dailyHabitStateStore.loadStates()
            let events = try environment.completionEventStore.loadEvents()
            let snapshot = environment.dailyHabitInstanceEngine.generateSnapshot(
                for: habits,
                persistedStates: persistedStates,
                daySectionsByID: sectionsByID,
                on: now,
                now: now,
                calendar: calendar
            )
            let momentumSummary = environment.momentumCalculator.summary(
                for: habits,
                completionEvents: events,
                upTo: now,
                calendar: calendar
            )

            try environment.dailyHabitStateStore.saveStates(
                mergedStates(existing: persistedStates, snapshotStates: snapshot.states, calendar: calendar)
            )

            habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
            daySectionsByID = sectionsByID
            self.persistedStates = persistedStates
            orderedStates = snapshot.states
            self.momentumSummary = momentumSummary
            loadErrorMessage = nil
        } catch {
            habitsByID = [:]
            persistedStates = []
            orderedStates = []
            momentumSummary = nil
            loadErrorMessage = error.localizedDescription
        }
    }

    private func computeCurrentStreak() -> Int {
        do {
            let habits = try environment.habitRepository.fetchHabits()
            let states = try environment.dailyHabitStateStore.loadStates()
            let events = try environment.completionEventStore.loadEvents()

            return environment.dailyStreakCalculator.summary(
                for: habits,
                states: states,
                completionEvents: events,
                upTo: environment.dateService.now,
                calendar: environment.dateService.calendar
            ).currentDailyStreak
        } catch {
            return 0
        }
    }

    private func rhythmContext(for now: Date) -> CurrentRhythmContext {
        let configuration = environment.rhythmConfiguration
        let calendar = environment.dateService.calendar

        if configuration.morningWindow.contains(now, calendar: calendar) {
            return CurrentRhythmContext(
                title: "Morning",
                rangeText: "\(formattedTime(configuration.morningWindow.start)) - \(formattedTime(configuration.morningWindow.end))",
                description: "Morning habits should feel more immediate right now."
            )
        }

        if configuration.dayWindow.contains(now, calendar: calendar) {
            return CurrentRhythmContext(
                title: "Day",
                rangeText: "\(formattedTime(configuration.dayWindow.start)) - \(formattedTime(configuration.dayWindow.end))",
                description: "Day habits can carry the middle of the schedule without urgency."
            )
        }

        if configuration.eveningWindow.contains(now, calendar: calendar) {
            return CurrentRhythmContext(
                title: "Evening",
                rangeText: "\(formattedTime(configuration.eveningWindow.start)) - \(formattedTime(configuration.eveningWindow.end))",
                description: "Evening habits are gently prioritized as the day slows down."
            )
        }

        return CurrentRhythmContext(
            title: "Anytime",
            rangeText: "All day",
            description: "Anytime habits stay quietly available through the whole day."
        )
    }

    private func formattedTime(_ time: HabitClockTime) -> String {
        var components = DateComponents()
        components.calendar = environment.dateService.calendar
        components.hour = time.hour
        components.minute = time.minute

        let date = components.date ?? .now
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    @MainActor
    private func resolveTopCard(action: TodayDeckAction, source: CompletionSource? = nil) async {
        guard !isSavingAction, let topState = actionableStates.first, let habit = habitsByID[topState.habitID] else {
            return
        }

        isSavingAction = true
        defer { isSavingAction = false }

        do {
            let now = environment.dateService.now

            switch action {
            case .complete:
                guard let source else { return }
                let isFinalCompletion = remainingCount == 1
                let result = try environment.completionProcessor.processCompletion(
                    for: habit,
                    state: topState,
                    source: source,
                    at: now,
                    calendar: environment.dateService.calendar
                )

                if result.didCreateEvent {
                    environment.analyticsTracker.track(.habitCompleted(habit.id))
                }

                environment.hapticService.play(isFinalCompletion ? .fullDayCompleted : .habitCompleted)
                if !result.newAchievements.isEmpty {
                    environment.hapticService.play(.milestoneReached)
                }
                await environment.notificationScheduler.syncReminders(
                    for: habit,
                    state: result.updatedState,
                    now: now,
                    calendar: environment.dateService.calendar
                )
                environment.widgetRefreshService.refreshSnapshots()
            case .notNow:
                let updatedState = environment.dailyHabitInstanceEngine.deferState(
                    topState,
                    habit: habit,
                    remainingActionableHabits: max(actionableStates.count - 1, 0),
                    at: now,
                    calendar: environment.dateService.calendar
                )
                try environment.dailyHabitStateStore.upsertState(updatedState, calendar: environment.dateService.calendar)
                environment.hapticService.play(.habitDeferred)
                await environment.notificationScheduler.syncReminders(
                    for: habit,
                    state: updatedState,
                    now: now,
                    calendar: environment.dateService.calendar
                )
                environment.widgetRefreshService.refreshSnapshots()
            }

            await reloadDeck()
        } catch {
            loadErrorMessage = error.localizedDescription
            environment.hapticService.play(.habitDeferred)
        }
    }

    private func mergedStates(
        existing: [DailyHabitState],
        snapshotStates: [DailyHabitState],
        calendar: Calendar
    ) -> [DailyHabitState] {
        var merged = existing

        for state in snapshotStates {
            if let index = merged.firstIndex(where: { $0.habitID == state.habitID && calendar.isDate($0.date, inSameDayAs: state.date) }) {
                merged[index] = state
            } else {
                merged.append(state)
            }
        }

        return merged
    }

    private func triggerProgrammaticSwipe(_ direction: TodaySwipeDirection) {
        guard !actionableStates.isEmpty, programmaticSwipeRequest == nil, !isSavingAction else {
            return
        }

        programmaticSwipeRequest = TodayProgrammaticSwipeRequest(direction: direction)
    }

    @MainActor
    private func handleProgrammaticSwipeFinished(_ direction: TodaySwipeDirection) async {
        guard programmaticSwipeRequest != nil else { return }
        programmaticSwipeRequest = nil

        switch direction {
        case .complete:
            await resolveTopCard(action: .complete, source: .todayDeckButton)
        case .notNow:
            await resolveTopCard(action: .notNow)
        }
    }
}

private struct TodayDeckEntry: Identifiable, Sendable {
    let habit: Habit
    let state: DailyHabitState
    let daySection: HabitDaySection?

    var id: UUID {
        state.id
    }
}

private enum TodayDeckAction {
    case complete
    case notNow
}

private enum TodaySwipeDirection {
    case complete
    case notNow
}

private struct TodayProgrammaticSwipeRequest: Identifiable {
    let id = UUID()
    let direction: TodaySwipeDirection
}

private enum TodayEmptyStateReason {
    case noHabitsCreated
    case allHabitsPaused
    case archivedOnlyLibrary
    case noHabitsDueToday
}

private struct TodayHabitInspectionContext: Identifiable {
    let habit: Habit
    let state: DailyHabitState

    var id: UUID {
        state.id
    }
}

private struct TodayDeckCardView: View {
    let entry: TodayDeckEntry
    let isTopCard: Bool
    let isBusy: Bool
    let reduceMotion: Bool
    let programmaticSwipeRequest: TodayProgrammaticSwipeRequest?
    let onThresholdCrossed: () -> Void
    let onInspect: () -> Void
    let onComplete: () -> Void
    let onDefer: () -> Void
    let onProgrammaticSwipeFinished: (TodaySwipeDirection) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var dragOffset: CGSize = .zero
    @State private var isDismissed = false
    @State private var hasCrossedThreshold = false
    @State private var isDragging = false
    @State private var idleHintOffset: CGFloat = 0

    private let threshold: CGFloat = 118
    private let dismissalDistance: CGFloat = 520

    var body: some View {
        Group {
            if isTopCard && !isBusy {
                decoratedCard.gesture(dragGesture)
            } else {
                decoratedCard
            }
        }
        .task(id: idleHintTaskKey) {
            await runIdleHintLoopIfNeeded()
        }
        .task(id: programmaticSwipeTaskKey) {
            await runProgrammaticSwipeIfNeeded()
        }
    }

    private var decoratedCard: some View {
        cardBody
            .offset(
                x: isTopCard ? dragOffset.width + idleHintOffset : 0,
                y: isTopCard ? dragOffset.height : 0
            )
            .rotationEffect(.degrees(isTopCard && !reduceMotion ? Double((dragOffset.width + idleHintOffset) / 20) : 0))
            .scaleEffect(isTopCard ? 1 : 0.98)
            .opacity(isDismissed ? 0 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.08) : HabitQuestDesignSystem.Motion.card, value: dragOffset)
            .contentShape(RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(isTopCard && !isBusy ? .isButton : [])
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)
            .accessibilityAction {
                guard isTopCard, !isBusy, !isDismissed else { return }
                onInspect()
            }
            .accessibilityAction(named: Text("Complete")) {
                guard isTopCard, !isBusy, !isDismissed else { return }
                onComplete()
            }
            .accessibilityAction(named: Text("Not Now")) {
                guard isTopCard, !isBusy, !isDismissed else { return }
                onDefer()
            }
            .accessibilityAction(named: Text("Open Details")) {
                guard isTopCard, !isBusy, !isDismissed else { return }
                onInspect()
            }
            .onTapGesture {
                guard isTopCard, !isBusy, !isDismissed else { return }
                onInspect()
            }
            .overlay(alignment: .bottom) {
                if let swipeFeedbackState {
                    swipeFeedbackBadge(for: swipeFeedbackState)
                        .padding(.bottom, HabitQuestDesignSystem.Spacing.md)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
    }

    private var accessibilityLabel: String {
        "\(entry.habit.title), \(entry.habit.dailyRhythm.displayTitle)"
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if let daySection {
            parts.append(daySection.displayTitle)
        }
        parts.append(scheduleSubtitle)
        parts.append(statusTitle)

        if entry.state.deferCount > 0 {
            parts.append("\(entry.state.deferCount) deferrals")
        }

        parts.append(todaySummary)

        if let notes = entry.habit.notes, !notes.isEmpty {
            parts.append("Notes available")
        }

        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        guard isTopCard, !isBusy, !isDismissed else {
            return "This habit is currently in the stack."
        }

        return "Double tap to open details. Use the accessible actions to mark this habit complete or move it to later."
    }

    private var cardBody: some View {
        return ZStack {
            roundedBackground

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                HStack(alignment: .center, spacing: HabitQuestDesignSystem.Spacing.md) {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text(displayIcon)
                                .font(HabitQuestDesignSystem.Typography.headline.weight(.semibold))
                                .foregroundStyle(accentColor)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.habit.title)
                            .font(HabitQuestDesignSystem.Typography.title2)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            .lineLimit(2)
                        Text(scheduleSubtitle)
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    if let daySection {
                        TodayDeckPill(
                            title: daySection.displayTitle,
                            accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                        )
                    }
                    TodayDeckPill(
                        title: entry.habit.dailyRhythm.displayTitle,
                        accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                    )
                    TodayDeckPill(
                        title: statusTitle,
                        accent: statusAccent
                    )
                }

                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    Text("Today")
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    Text(todaySummary)
                        .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let notes = entry.habit.notes, !notes.isEmpty {
                    Text(notes)
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(HabitQuestDesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 386)
        .habitQuestSurface(.raised, cornerRadius: HabitQuestDesignSystem.Radius.xl, padding: 0)
        .overlay(alignment: .topTrailing) {
            Text("\(entry.state.deferCount) deferrals")
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme).opacity(0.72))
                )
                .padding(HabitQuestDesignSystem.Spacing.md)
        }
    }

    private var roundedBackground: some View {
        let shape = RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)

        return shape
            .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme))
            .overlay(
                shape.stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
            )
            .overlay(
                shape
                    .fill(accentColor.opacity(0.06))
                    .blur(radius: 20)
                    .opacity(isTopCard ? 1 : 0.55)
            )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard !isDismissed else { return }
                isDragging = true
                idleHintOffset = 0
                dragOffset = value.translation

                let crossed = abs(value.translation.width) >= threshold
                if crossed, !hasCrossedThreshold {
                    hasCrossedThreshold = true
                    onThresholdCrossed()
                } else if !crossed {
                    hasCrossedThreshold = false
                }
            }
            .onEnded { value in
                guard !isDismissed else { return }
                hasCrossedThreshold = false
                isDragging = false

                let horizontal = value.translation.width
                if horizontal > threshold {
                    commit(direction: .complete)
                } else if horizontal < -threshold {
                    commit(direction: .notNow)
                } else {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.08) : HabitQuestDesignSystem.Motion.card) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func commit(direction: TodaySwipeDirection) {
        commit(direction: direction, completion: nil)
    }

    private func commit(direction: TodaySwipeDirection, completion: (() -> Void)?) {
        guard !isDismissed else { return }
        isDismissed = true

        let verticalOffset = dragOffset.height * 0.20
        let target = CGSize(
            width: direction == .complete ? dismissalDistance : -dismissalDistance,
            height: verticalOffset
        )

        withAnimation(reduceMotion ? .easeOut(duration: 0.08) : HabitQuestDesignSystem.Motion.card) {
            dragOffset = target
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: reduceMotion ? 60_000_000 : 110_000_000)
            if let completion {
                completion()
            } else {
                switch direction {
                case .complete:
                    onComplete()
                case .notNow:
                    onDefer()
                }
            }
        }
    }

    private var swipeFeedbackState: SwipeFeedbackState? {
        let horizontal = abs(dragOffset.width) > 1 ? dragOffset.width : idleHintOffset

        if horizontal >= 12 {
            return .complete
        } else if horizontal <= -12 {
            return .notNow
        } else {
            return nil
        }
    }

    private var idleHintTaskKey: String {
        guard isTopCard, !isBusy, !reduceMotion, !isDismissed, !isDragging else {
            return "inactive"
        }

        return "active"
    }

    private var programmaticSwipeTaskKey: String {
        guard isTopCard, !isBusy, !isDismissed, !isDragging, let programmaticSwipeRequest else {
            return "inactive"
        }

        return programmaticSwipeRequest.id.uuidString
    }

    @MainActor
    private func runIdleHintLoopIfNeeded() async {
        guard idleHintTaskKey == "active" else { return }

        do {
            try await Task.sleep(nanoseconds: 7_000_000_000)
        } catch {
            return
        }

        while !Task.isCancelled, idleHintTaskKey == "active" {
            let keyframes: [CGFloat] = [8, -6, 4, -3, 0]
            for (index, value) in keyframes.enumerated() {
                guard !Task.isCancelled, idleHintTaskKey == "active" else { return }

                withAnimation(.easeInOut(duration: index == keyframes.count - 1 ? 0.20 : 0.16)) {
                    idleHintOffset = value
                }

                if index < keyframes.count - 1 {
                    do {
                        try await Task.sleep(nanoseconds: 150_000_000)
                    } catch {
                        return
                    }
                }
            }

            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }
        }
    }

    @MainActor
    private func runProgrammaticSwipeIfNeeded() async {
        guard let programmaticSwipeRequest, programmaticSwipeTaskKey != "inactive" else { return }

        let request = programmaticSwipeRequest
        commit(direction: request.direction) {
            onProgrammaticSwipeFinished(request.direction)
        }
    }

    private func swipeFeedbackBadge(for state: SwipeFeedbackState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: state.icon)
            Text(state.title)
        }
        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
        .foregroundStyle(state.color(for: colorScheme))
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(state.color(for: colorScheme).opacity(0.06))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(state.color(for: colorScheme).opacity(0.16), lineWidth: 1)
                )
        )
        .opacity(state.opacity(for: dragOffset.width, idleOffset: idleHintOffset))
        .animation(reduceMotion ? .easeOut(duration: 0.08) : HabitQuestDesignSystem.Motion.snappy, value: dragOffset)
        .animation(reduceMotion ? .easeOut(duration: 0.08) : HabitQuestDesignSystem.Motion.snappy, value: idleHintOffset)
    }

    private enum SwipeFeedbackState {
        case complete
        case notNow

        var title: String {
            switch self {
            case .complete:
                return "Completed"
            case .notNow:
                return "Not Now"
            }
        }

        var icon: String {
            switch self {
            case .complete:
                return "checkmark"
            case .notNow:
                return "arrow.uturn.left"
            }
        }

        func color(for colorScheme: ColorScheme) -> Color {
            switch self {
            case .complete:
                return HabitQuestDesignSystem.Palette.success(for: colorScheme)
            case .notNow:
                return HabitQuestDesignSystem.Palette.note(for: colorScheme)
            }
        }

        func opacity(for dragWidth: CGFloat, idleOffset: CGFloat) -> Double {
            let effectiveWidth = abs(dragWidth) > 1 ? dragWidth : idleOffset
            guard effectiveWidth != 0 else { return 0 }

            let base = min(abs(effectiveWidth) / 84, 1)
            return max(0.08, Double(base) * 0.12 + 0.05)
        }
    }

    private var accentColor: Color {
        Color(hex: entry.habit.colorHex ?? HabitAccentChoice.amber.hex) ?? HabitAccentChoice.amber.color
    }

    private var daySection: HabitDaySection? {
        entry.daySection
    }

    private var displayIcon: String {
        let icon = entry.habit.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return icon.isEmpty ? "•" : icon
    }

    private var scheduleSubtitle: String {
        let base: String
        switch entry.habit.schedule {
        case .daily:
            base = "Daily"
        case .weekly(let days):
            base = "Weekly · \(weekdayList(days))"
        case .biWeekly(let days):
            base = "Bi-weekly · \(weekdayList(days))"
        case .monthly(let dayOfMonth):
            base = "Monthly · Day \(dayOfMonth)"
        case .customDays(let days):
            base = "Custom · \(weekdayList(days))"
        case .specificDateRange(let range):
            base = "Range · \(rangeSummary(range))"
        }

        guard let advancedSchedule = entry.habit.advancedSchedule else {
            return base
        }

        return "\(base) · \(advancedSchedule.displaySummary)"
    }

    private var todaySummary: String {
        switch entry.state.status {
        case .pending:
            return "Ready when you are."
        case .deferred:
            return "Deferred for now. It will come back behind the remaining cards."
        case .completed:
            return "Completed for today."
        case .expired:
            return "Expired for today."
        case .skipped:
            return "Skipped for today."
        }
    }

    private var statusTitle: String {
        switch entry.state.status {
        case .pending:
            return "Ready"
        case .deferred:
            return "Deferred"
        case .completed:
            return "Complete"
        case .expired:
            return "Expired"
        case .skipped:
            return "Skipped"
        }
    }

    private var statusAccent: Color {
        switch entry.state.status {
        case .pending:
            return HabitQuestDesignSystem.Palette.accent(for: colorScheme)
        case .deferred:
            return HabitQuestDesignSystem.Palette.note(for: colorScheme)
        case .completed:
            return HabitQuestDesignSystem.Palette.success(for: colorScheme)
        case .expired, .skipped:
            return HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme)
        }
    }

    private func weekdayList(_ weekdays: Set<Weekday>) -> String {
        weekdays.sorted(by: { $0.rawValue < $1.rawValue }).map(\.displayShortTitle).joined(separator: " ")
    }

    private func rangeSummary(_ range: HabitDateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
    }

}

private struct TodayDeckPill: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(accent.opacity(0.24), lineWidth: 1)
                    )
            )
    }
}

private struct TodayMetricStat: View {
    let icon: String
    let value: String
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                )

            Text(value)
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.05))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(0.10), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(labelText))
        .accessibilityValue(Text(value))
    }

    private var labelText: String {
        switch icon {
        case "flame.fill":
            return "Streak"
        case "gauge.with.dots.needle.67percent":
            return "Momentum"
        default:
            return "Daily journey"
        }
    }
}

private struct SummaryBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(accent.opacity(0.24), lineWidth: 1)
                    )
            )
    }
}

private struct TodayHabitInspectionView: View {
    let context: TodayHabitInspectionContext

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard
                        detailCard
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Inspect Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HabitRowCardView(
                habit: context.habit,
                currentStreak: 0,
                showsArchivedLabel: false
            )

            Text("Inspect this habit without changing today’s deck.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Today state")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            DetailRow(title: "Status", value: statusTitle)
            DetailRow(title: "Daily rhythm", value: context.habit.dailyRhythm.displayTitle)
            DetailRow(title: "Schedule", value: scheduleTitle)
            DetailRow(title: "Time mode", value: timeModeTitle)
            DetailRow(title: "Reminders", value: reminderTitle)
            DetailRow(title: "Deferrals", value: "\(context.state.deferCount)")
            DetailRow(title: "Current pass", value: "\(context.state.currentPass)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var statusTitle: String {
        switch context.state.status {
        case .pending:
            return "Pending"
        case .deferred:
            return "Deferred"
        case .completed:
            return "Completed"
        case .expired:
            return "Expired"
        case .skipped:
            return "Skipped"
        }
    }

    private var scheduleTitle: String {
        switch context.habit.schedule {
        case .daily:
            return "Daily"
        case .weekly(let days):
            return "Weekly · \(days.map(\.displayShortTitle).sorted().joined(separator: ", "))"
        case .biWeekly(let days):
            return "Bi-weekly · \(days.map(\.displayShortTitle).sorted().joined(separator: ", "))"
        case .monthly(let dayOfMonth):
            return "Monthly · Day \(dayOfMonth)"
        case .customDays(let days):
            return "Custom · \(days.map(\.displayShortTitle).sorted().joined(separator: ", "))"
        case .specificDateRange(let range):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
        }
    }

    private var timeModeTitle: String {
        switch context.habit.timeMode {
        case .allDay:
            return "All day"
        case .specificTime(let time):
            return formattedTime(hour: time.hour, minute: time.minute)
        case .timeWindow(let window):
            return "\(formattedTime(hour: window.start.hour, minute: window.start.minute)) - \(formattedTime(hour: window.end.hour, minute: window.end.minute))"
        }
    }

    private var reminderTitle: String {
        guard let reminderConfiguration = context.habit.reminderConfiguration, reminderConfiguration.isEnabled else {
            return "Off"
        }

        return "On"
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.calendar = .current
        components.hour = hour
        components.minute = minute

        let date = components.date ?? .now
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

private extension HabitRhythm {
    var displayTitle: String {
        switch self {
        case .morning:
            return "Morning"
        case .day:
            return "Day"
        case .evening:
            return "Evening"
        case .anytime:
            return "Anytime"
        }
    }
}

private extension Weekday {
    var displayShortTitle: String {
        switch self {
        case .sunday:
            return "Sun"
        case .monday:
            return "Mon"
        case .tuesday:
            return "Tue"
        case .wednesday:
            return "Wed"
        case .thursday:
            return "Thu"
        case .friday:
            return "Fri"
        case .saturday:
            return "Sat"
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

            Spacer(minLength: 16)

            Text(value)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CompletedHabitSummary: Identifiable {
    let id: UUID
    let title: String
    let icon: String?
    let category: String?
}

private struct CompletedHabitRow: View {
    let summary: CompletedHabitSummary

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(HabitQuestDesignSystem.Palette.success(for: colorScheme).opacity(0.14))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(iconText)
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.success(for: colorScheme))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                if let category = summary.category, !category.isEmpty {
                    Text(category)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HabitQuestDesignSystem.Palette.success(for: colorScheme))
        }
        .padding(.vertical, HabitQuestDesignSystem.Spacing.xs)
    }

    private var iconText: String {
        let trimmed = summary.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "✓" : trimmed
    }
}

private struct CurrentRhythmContext {
    let title: String
    let rangeText: String
    let description: String
}
