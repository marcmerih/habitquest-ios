import SwiftUI

struct HabitRowCardView: View {
    let habit: Habit
    let currentStreak: Int
    let showsArchivedLabel: Bool
    let daySectionTitle: String?
    let presentation: HabitRowPresentation
    let showsEditAffordance: Bool
    let showsReorderHandle: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        habit: Habit,
        currentStreak: Int,
        showsArchivedLabel: Bool,
        daySectionTitle: String? = nil,
        presentation: HabitRowPresentation = .standard,
        showsEditAffordance: Bool = false,
        showsReorderHandle: Bool = false
    ) {
        self.habit = habit
        self.currentStreak = currentStreak
        self.showsArchivedLabel = showsArchivedLabel
        self.daySectionTitle = daySectionTitle
        self.presentation = presentation
        self.showsEditAffordance = showsEditAffordance
        self.showsReorderHandle = showsReorderHandle
    }

    var body: some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(accentColor.opacity(0.18))
                .frame(width: presentation == .compact ? 42 : 46, height: presentation == .compact ? 42 : 46)
                .overlay(
                    Text(displayIcon)
                        .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                        .foregroundStyle(accentColor)
                )

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    Text(habit.title)
                        .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let category = habit.category, !category.isEmpty {
                        Text(category)
                            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }
                }

                HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                    HabitStatusPill(
                        title: statusTitle,
                        color: statusColor
                    )

                    if let daySectionTitle {
                        HabitStatusPill(
                            title: daySectionTitle,
                            color: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                        )
                    }

                    HabitStatusPill(
                        title: habit.dailyRhythm.title,
                        color: HabitQuestDesignSystem.Palette.note(for: colorScheme)
                    )
                }

                Text(scheduleSummary)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                if presentation == .standard {
                    Text(reminderSummary)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    if let notes = habit.notes, !notes.isEmpty {
                        Text(notes)
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if presentation == .compact, showsEditAffordance || showsReorderHandle {
                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    if showsEditAffordance {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    if showsReorderHandle {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .padding(.leading, HabitQuestDesignSystem.Spacing.xs)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        if showsArchivedLabel || habit.isArchived {
            return "Archived"
        }

        if habit.isPaused {
            return "Paused"
        }

        return currentStreak > 0 ? "\(currentStreak) day streak" : "No streak yet"
    }

    private var statusColor: Color {
        if showsArchivedLabel || habit.isArchived {
            return HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme)
        }

        if habit.isPaused {
            return HabitQuestDesignSystem.Palette.note(for: colorScheme)
        }

        return HabitQuestDesignSystem.Palette.success(for: colorScheme)
    }

    private var accentColor: Color {
        Color(hex: habit.colorHex ?? HabitAccentChoice.amber.hex) ?? HabitAccentChoice.amber.color
    }

    private var displayIcon: String {
        let icon = habit.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return icon.isEmpty ? "•" : icon
    }

    private var scheduleSummary: String {
        let base: String
        switch habit.schedule {
        case .daily:
            base = "Daily"
        case .weekly(let days):
            base = "Weekly · \(weekdayList(days))"
        case .biWeekly(let days):
            base = "Bi-weekly · \(weekdayList(days))"
        case .monthly(let dayOfMonth):
            base = "Monthly · Day \(dayOfMonth)"
        case .customDays(let days):
            base = "Custom days · \(weekdayList(days))"
        case .specificDateRange(let range):
            base = "Date range · \(dateRangeSummary(range))"
        }

        guard let advancedSchedule = habit.advancedSchedule else {
            return base
        }

        return "\(base) · \(advancedSchedule.displaySummary)"
    }

    private var reminderSummary: String {
        guard let reminderConfiguration = habit.reminderConfiguration, reminderConfiguration.isEnabled, !reminderConfiguration.rules.isEmpty else {
            return "Reminders off"
        }

        let summaries = reminderConfiguration.rules.map { rule -> String in
            switch rule {
            case .atTime(let time):
                return timeDescription(time)
            case .beforeScheduledTime(let minutes):
                return "\(minutes) minutes before"
            }
        }

        return "Reminder · \(summaries.joined(separator: ", "))"
    }

    private func weekdayList(_ weekdays: Set<Weekday>) -> String {
        weekdays
            .sorted(by: { $0.rawValue < $1.rawValue })
            .map(\.shortTitle)
            .joined(separator: " ")
    }

    private func dateRangeSummary(_ range: HabitDateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
    }

    private func timeDescription(_ time: HabitClockTime) -> String {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.hour = time.hour
        components.minute = time.minute

        let date = components.date ?? .now
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum HabitRowPresentation {
    case standard
    case compact
}

struct HabitStatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(color.opacity(0.22), lineWidth: 1)
                    )
            )
    }
}

struct HabitDetailView: View {
    let habit: Habit
    let onEdit: () -> Void
    let onPauseToggle: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isCompletingManually = false
    @State private var premiumFeatureGateDescriptor: PremiumFeatureGateDescriptor?
    @State private var premiumPaywallSourceMetadata: PremiumPaywallSourceMetadata?
    @State private var isPresentingPremiumPaywall = false
    @State private var reflectionEditorEvent: CompletionEvent?
    @State private var progressSummary: HabitProgressSummary?
    @State private var recentCompletionEvents: [CompletionEvent] = []
    @State private var actionMessage: String?
    @State private var loadedTodayState: DailyHabitState?
    @State private var daySectionTitle: String?

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard
                        progressCard
                        recentHistoryCard
                        notesCard
                        actionsCard
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Habit")
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
            .alert("Could not complete habit", isPresented: Binding(
                get: { actionMessage != nil },
                set: { if !$0 { actionMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    actionMessage = nil
                }
            } message: {
                Text(actionMessage ?? "Something went wrong.")
            }
            .confirmationDialog(
                "Delete this habit?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete habit", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the habit from your local HabitQuest library.")
            }
            .fullScreenCover(item: $premiumFeatureGateDescriptor) { descriptor in
                PremiumFeatureGateView(
                    entitlementService: environment.premiumEntitlementService,
                    descriptor: descriptor,
                    onDismiss: {
                        premiumFeatureGateDescriptor = nil
                    },
                    onOpenPaywall: { metadata in
                        premiumPaywallSourceMetadata = metadata
                        premiumFeatureGateDescriptor = nil
                        isPresentingPremiumPaywall = true
                    }
                ) {
                    PremiumFeatureGatePreviewView(feature: descriptor.feature)
                }
            }
            .fullScreenCover(isPresented: $isPresentingPremiumPaywall, onDismiss: {
                premiumPaywallSourceMetadata = nil
            }) {
                PremiumPaywallView(
                    subscriptionManager: environment.subscriptionManager,
                    entitlementService: environment.premiumEntitlementService,
                    sourceMetadata: premiumPaywallSourceMetadata
                )
            }
            .sheet(item: $reflectionEditorEvent) { event in
                HabitReflectionEditorView(
                    event: event,
                    onSave: { reflection in
                        Task { await saveReflection(reflection, for: event) }
                    },
                    onRemove: {
                        Task { await removeReflection(for: event) }
                    },
                    onCancel: {
                        reflectionEditorEvent = nil
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .task {
                await loadHabitDetail()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(displayIcon)
                            .font(HabitQuestDesignSystem.Typography.headline.weight(.semibold))
                            .foregroundStyle(accentColor)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(HabitQuestDesignSystem.Typography.title2)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                        HabitStatusPill(title: statusTitle, color: statusColor)
                        if let daySectionTitle {
                            HabitStatusPill(title: daySectionTitle, color: HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                        }
                        if let category = habit.category, !category.isEmpty {
                            HabitStatusPill(title: category, color: HabitQuestDesignSystem.Palette.note(for: colorScheme))
                        }
                    }
                }
            }

            Text(habit.isArchived
                 ? "Archived habits stay local and out of the way."
                 : "This habit can be adjusted gently as your routine changes.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Progress")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                detailRow(title: "Schedule", value: scheduleSummary)
                detailRow(title: "Daily rhythm", value: habit.dailyRhythm.title)
                detailRow(title: "Day section", value: daySectionTitle ?? "None")
                detailRow(title: "Reminder", value: reminderSummary)
                detailRow(title: "Current streak", value: "\(progressSummary?.currentStreak ?? 0) day\(progressSummary?.currentStreak == 1 ? "" : "s")")
                detailRow(title: "Longest streak", value: "\(progressSummary?.longestStreak ?? 0) day\(progressSummary?.longestStreak == 1 ? "" : "s")")
                detailRow(title: "Consistency", value: consistencySummary)
                detailRow(title: "Total completions", value: "\(progressSummary?.totalCompletions ?? 0)")
                detailRow(title: "Created", value: dateFormatter.string(from: habit.createdAt))
                detailRow(title: "Updated", value: dateFormatter.string(from: habit.updatedAt))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var recentHistoryCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recent completion history")
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text("Reflections stay attached to the completion that created them.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if canCompleteToday {
                    Button {
                        Task { await completeTodayManually() }
                    } label: {
                        Label(isCompletingManually ? "Saving" : "Complete today", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(isCompletingManually)
                    .habitQuestGlassButtonStyle(prominent: true)
                }
            }

            if let todayState = loadedTodayState, todayState.status == .pending {
                Text("Today is still available for a manual completion.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            } else if let todayState = loadedTodayState, todayState.status == .deferred {
                Text("This habit is deferred for now, but it can still be completed manually while it remains relevant.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            } else if loadedTodayState == nil {
                Text("This habit is not currently due.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            if recentCompletionEvents.isEmpty {
                Text("No completion history yet.")
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(recentCompletionEvents.suffix(5).reversed()) { event in
                        recentCompletionRow(for: event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var notesCard: some View {
        Group {
            if let notes = habit.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    Text("Notes")
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text(notes)
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .habitQuestSurface(.raised)
            }
        }
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Actions")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                Button {
                    onEdit()
                    dismiss()
                } label: {
                    Label("Edit habit", systemImage: "pencil")
                }
                .habitQuestGlassButtonStyle()

                Button {
                    onPauseToggle()
                    dismiss()
                } label: {
                    Label(habit.isPaused ? "Resume habit" : "Pause habit", systemImage: habit.isPaused ? "play.fill" : "pause.fill")
                }
                .habitQuestGlassButtonStyle()

                if !habit.isArchived {
                    Button {
                        onArchive()
                        dismiss()
                    } label: {
                        Label("Archive habit", systemImage: "archivebox")
                    }
                    .habitQuestGlassButtonStyle()
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete habit", systemImage: "trash")
                }
                .habitQuestGlassButtonStyle()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var accentColor: Color {
        Color(hex: habit.colorHex ?? HabitAccentChoice.amber.hex) ?? HabitAccentChoice.amber.color
    }

    private var consistencySummary: String {
        guard let summary = progressSummary else {
            return "No data yet"
        }

        let recent = summary.recentConsistencyPercentage.map { "\(Int($0.rounded()))%" } ?? "No recent data"
        let lifetime = summary.lifetimeConsistencyPercentage.map { "\(Int($0.rounded()))%" } ?? "No lifetime data"
        return "\(recent) recent · \(lifetime) lifetime"
    }

    private var displayIcon: String {
        let icon = habit.icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return icon.isEmpty ? "•" : icon
    }

    private var statusTitle: String {
        if habit.isArchived {
            return "Archived"
        }

        if habit.isPaused {
            return "Paused"
        }

        let streak = progressSummary?.currentStreak ?? 0
        return streak > 0 ? "\(streak) day streak" : "No streak yet"
    }

    private var statusColor: Color {
        if habit.isArchived {
            return HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme)
        }

        if habit.isPaused {
            return HabitQuestDesignSystem.Palette.note(for: colorScheme)
        }

        return HabitQuestDesignSystem.Palette.success(for: colorScheme)
    }

    private var scheduleSummary: String {
        let base: String
        switch habit.schedule {
        case .daily:
            base = "Every day"
        case .weekly(let weekdays):
            base = "Weekly · \(weekdayList(weekdays))"
        case .biWeekly(let weekdays):
            base = "Bi-weekly · \(weekdayList(weekdays))"
        case .monthly(let dayOfMonth):
            base = "Monthly · Day \(dayOfMonth)"
        case .customDays(let weekdays):
            base = "Custom days · \(weekdayList(weekdays))"
        case .specificDateRange(let range):
            base = "Date range · \(dateRangeSummary(range))"
        }

        guard let advancedSchedule = habit.advancedSchedule else {
            return base
        }

        return "\(base) · \(advancedSchedule.displaySummary)"
    }

    private var reminderSummary: String {
        guard let reminderConfiguration = habit.reminderConfiguration, reminderConfiguration.isEnabled, !reminderConfiguration.rules.isEmpty else {
            return "Reminders off"
        }

        let summaries = reminderConfiguration.rules.map { rule -> String in
            switch rule {
            case .atTime(let time):
                return timeDescription(time)
            case .beforeScheduledTime(let minutes):
                return "\(minutes) minutes before"
            }
        }

        return summaries.joined(separator: ", ")
    }

    private var canCompleteToday: Bool {
        loadedTodayState.map { $0.status == .pending || $0.status == .deferred } ?? false
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var completionDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private var sourceFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .frame(width: 104, alignment: .leading)

            Text(value)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func weekdayList(_ weekdays: Set<Weekday>) -> String {
        weekdays
            .sorted(by: { $0.rawValue < $1.rawValue })
            .map(\.shortTitle)
            .joined(separator: " ")
    }

    private func dateRangeSummary(_ range: HabitDateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
    }

    private func timeDescription(_ time: HabitClockTime) -> String {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.hour = time.hour
        components.minute = time.minute

        let date = components.date ?? .now
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func recentCompletionRow(for event: CompletionEvent) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
                Circle()
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.55))
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(completionDateFormatter.string(from: event.timestamp))
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text(event.source.displayTitle)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                Spacer(minLength: 0)

                if environment.premiumEntitlementService.canAccess(.habitReflections) {
                    Button(event.reflection == nil ? "Add" : "Edit") {
                        openReflectionEditor(for: event)
                    }
                    .buttonStyle(.plain)
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                } else if event.reflection != nil {
                    Text("Premium reflection")
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                }
            }

            if let reflection = event.reflection, !reflection.isEmpty {
                Text(reflection)
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(HabitQuestDesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                            .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    )
            } else if environment.premiumEntitlementService.canAccess(.habitReflections) {
                Button {
                    openReflectionEditor(for: event)
                } label: {
                    Label("Add a short reflection", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }

    private func openReflectionEditor(for event: CompletionEvent) {
        guard environment.premiumEntitlementService.canAccess(.habitReflections) else {
            premiumFeatureGateDescriptor = PremiumFeature.habitReflections.gateDescriptor(
                origin: .habits,
                entryPoint: "Habit detail reflections"
            )
            return
        }

        reflectionEditorEvent = event
    }

    @MainActor
    private func saveReflection(_ reflection: String?, for event: CompletionEvent) async {
        do {
            _ = try environment.completionEventStore.updateReflection(for: event.id, reflection: reflection)
            recentCompletionEvents = try environment.completionEventStore.completions(for: habit.id)
            reflectionEditorEvent = nil
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    @MainActor
    private func removeReflection(for event: CompletionEvent) async {
        do {
            _ = try environment.completionEventStore.updateReflection(for: event.id, reflection: nil)
            recentCompletionEvents = try environment.completionEventStore.completions(for: habit.id)
            reflectionEditorEvent = nil
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadHabitDetail() async {
        do {
            let customSections = try environment.habitDaySectionStore.loadSections()
            let sectionsByID = Dictionary(uniqueKeysWithValues: HabitDaySectionCatalog.allSections(customSections: customSections).map { ($0.id, $0) })
            daySectionTitle = habit.daySectionID.flatMap { sectionsByID[$0]?.displayTitle }
            let summary = environment.habitProgressCalculator.summary(
                for: habit,
                completionEvents: try environment.completionEventStore.loadEvents(),
                upTo: environment.dateService.now,
                calendar: environment.dateService.calendar
            )
            progressSummary = summary
            recentCompletionEvents = try environment.completionEventStore.completions(for: habit.id)

            let snapshot = environment.dailyHabitInstanceEngine.generateSnapshot(
                for: [habit],
                persistedStates: try environment.dailyHabitStateStore.loadStates(),
                daySectionsByID: sectionsByID,
                on: environment.dateService.now,
                now: environment.dateService.now,
                calendar: environment.dateService.calendar
            )
            loadedTodayState = snapshot.states.first
        } catch {
            progressSummary = nil
            recentCompletionEvents = []
            loadedTodayState = nil
            daySectionTitle = nil
            actionMessage = error.localizedDescription
        }
    }

    @MainActor
    private func completeTodayManually() async {
        guard !isCompletingManually, let todayState = loadedTodayState, todayState.status == .pending || todayState.status == .deferred else {
            return
        }

        isCompletingManually = true
        defer { isCompletingManually = false }

        do {
            let result = try environment.completionProcessor.processCompletion(
                for: habit,
                state: todayState,
                source: .manualHabitAction,
                at: environment.dateService.now,
                calendar: environment.dateService.calendar
            )

            loadedTodayState = result.updatedState
            progressSummary = environment.habitProgressCalculator.summary(
                for: habit,
                completionEvents: try environment.completionEventStore.loadEvents(),
                upTo: environment.dateService.now,
                calendar: environment.dateService.calendar
            )
            recentCompletionEvents = try environment.completionEventStore.completions(for: habit.id)

            if result.didCreateEvent {
                environment.hapticService.play(.habitCompleted)
            }

            environment.widgetRefreshService.refreshSnapshots()
        } catch {
            actionMessage = error.localizedDescription
        }
    }
}

private struct HabitReflectionEditorView: View {
    let event: CompletionEvent
    let onSave: (String?) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(
        event: CompletionEvent,
        onSave: @escaping (String?) -> Void,
        onRemove: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.event = event
        self.onSave = onSave
        self.onRemove = onRemove
        self.onCancel = onCancel
        _draft = State(initialValue: event.reflection ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                        Text("Reflection")
                            .font(HabitQuestDesignSystem.Typography.display)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text(event.timestamp, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                        Text("Add a short note about how this completion felt.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    }

                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                        TextEditor(text: $draft)
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .scrollContentBackground(.hidden)
                            .padding(HabitQuestDesignSystem.Spacing.sm)
                            .frame(minHeight: 180)
                            .background(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                            )

                        Text("Keep it short and personal. This stays local to HabitQuest.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    }

                    HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Button("Remove") {
                            onRemove()
                            dismiss()
                        }
                        .disabled((event.reflection ?? "").isEmpty)
                        .buttonStyle(HabitQuestButtonStyle(role: .secondary))

                        Button("Save") {
                            let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                            onSave(trimmed.isEmpty ? nil : trimmed)
                            dismiss()
                        }
                        .buttonStyle(HabitQuestButtonStyle(role: .primary))
                    }

                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
            }
            .navigationBarHidden(true)
        }
    }
}

private extension CompletionSource {
    var displayTitle: String {
        switch self {
        case .todayDeckSwipe:
            return "Completed from Today swipe"
        case .todayDeckButton:
            return "Completed from Today button"
        case .manualHabitAction:
            return "Completed manually"
        }
    }
}

struct ArchivedHabitsView: View {
    let habits: [Habit]
    let onSelectHabit: (Habit) -> Void
    let onRestoreHabit: (Habit) -> Void
    let onDeleteHabit: (Habit) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard

                        if habits.isEmpty {
                            emptyStateCard
                        } else {
                            archivedHabitsCard
                        }
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Label("Archived habits", systemImage: "archivebox")
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

            Text("Archived habits stay local, quiet, and out of the active habit flow.")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("You can inspect archived items here without bringing them back into Today.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("No archived habits yet")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Once you archive a habit, it will appear here instead of the active list.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var archivedHabitsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("\(habits.count) archived")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                ForEach(habits) { habit in
                    Button {
                        onSelectHabit(habit)
                    } label: {
                        HabitRowCardView(
                            habit: habit,
                            currentStreak: 0,
                            showsArchivedLabel: true,
                            presentation: .compact,
                            showsEditAffordance: true
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            onRestoreHabit(habit)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(HabitQuestDesignSystem.Palette.success(for: colorScheme))

                        Button {
                            onSelectHabit(habit)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(HabitQuestDesignSystem.Palette.note(for: colorScheme))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteHabit(habit)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if habit.id != habits.last?.id {
                        Divider()
                            .overlay(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }
}

private extension HabitRhythm {
    var title: String {
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
    var shortTitle: String {
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
