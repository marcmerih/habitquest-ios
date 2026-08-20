import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct HabitsFeatureView: View {
    @Binding var pendingTemplate: HabitTemplate?
    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @State private var activeHabits: [Habit] = []
    @State private var archivedHabits: [Habit] = []
    @State private var daySectionsByID: [UUID: HabitDaySection] = [:]
    @State private var completionEvents: [CompletionEvent] = []
    @State private var loadErrorMessage: String?
    @State private var presentedSheet: HabitManagementSheet?
    @State private var queuedSheet: HabitManagementSheet?
    @State private var premiumFeatureGateDescriptor: PremiumFeatureGateDescriptor?
    @State private var premiumPaywallSourceMetadata: PremiumPaywallSourceMetadata?
    @State private var isPresentingPremiumPaywall = false
    @State private var activeHabitsDisplayMode: ActiveHabitsDisplayMode = .list
    @State private var draggedActiveHabitID: UUID?

    init(pendingTemplate: Binding<HabitTemplate?> = .constant(nil)) {
        _pendingTemplate = pendingTemplate
    }

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            ScrollView {
                VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                    if activeHabits.isEmpty {
                        templatePromptCard
                    }
                    if allHabitsPaused {
                        pausedHabitsCard
                    }

                    if let loadErrorMessage {
                        errorCard(message: loadErrorMessage)
                    }

                    if !activeHabits.isEmpty {
                        archivedHabitsShortcut
                    }

                    if activeHabits.isEmpty {
                        emptyStateCard
                    } else {
                        activeHabitsCard
                    }
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, 104)
            }
            floatingCreateButton
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .create(let template):
                CreateHabitView(template: template) { _ in
                    reloadHabits()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)

            case .edit(let habit):
                CreateHabitView(habit: habit) { _ in
                    reloadHabits()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)

            case .detail(let habit):
                CreateHabitView(habit: habit) { _ in
                    reloadHabits()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)

            case .archivedList:
                ArchivedHabitsView(
                    habits: archivedHabits,
                    onSelectHabit: { habit in
                        queueSheet(.edit(habit))
                    },
                    onRestoreHabit: { habit in
                        restoreHabit(habit)
                    },
                    onDeleteHabit: { habit in
                        deleteHabit(habit)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)

            case .daySections:
                HabitDaySectionsManagementView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.clear)
            }
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
        .task {
            reloadHabits()
            presentPendingTemplateIfNeeded()
        }
        .onChange(of: pendingTemplate) { _, _ in
            presentPendingTemplateIfNeeded()
        }
        .onChange(of: presentedSheet) { _, newValue in
            guard newValue == nil, let nextSheet = queuedSheet else {
                return
            }

            queuedSheet = nil
            Task { @MainActor in
                await Task.yield()
                presentedSheet = nextSheet
            }
        }
    }

    private var templatePromptCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Need a head start?")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text("Pick a template to pre-fill a calm starting point, then change anything before saving.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(HabitTemplateCatalog.onboardingHighlights) { template in
                        templateButton(for: template)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func templateButton(for template: HabitTemplate) -> some View {
        Button {
            presentedSheet = .create(template)
        } label: {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(template.icon)
                        .font(HabitQuestDesignSystem.Typography.headline)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                Text(template.title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(template.subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            .frame(width: 182, alignment: .leading)
            .padding(HabitQuestDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                            .stroke(
                                (Color(hex: template.accentHex) ?? HabitQuestDesignSystem.Palette.border(for: colorScheme))
                                    .opacity(pendingTemplate?.id == template.id ? 0.85 : 0.35),
                                lineWidth: pendingTemplate?.id == template.id ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(template.title))
        .accessibilityHint(Text("Pre-fills a new habit with this template."))
    }

    private func presentPendingTemplateIfNeeded() {
        guard presentedSheet == nil, let template = pendingTemplate else {
            return
        }

        pendingTemplate = nil
        presentedSheet = .create(template)
    }

    private var floatingCreateButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    presentedSheet = .create(nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.background(for: colorScheme))
                        .frame(width: 58, height: 58)
                        .background(
                            Circle()
                                .fill(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.10), radius: 16, x: 0, y: 8)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.bottom, 18)
                .accessibilityLabel(Text("Create habit"))
                .accessibilityHint(Text("Create a new habit from scratch or use a template."))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var emptyStateCard: some View {
        Group {
            if archivedHabits.isEmpty {
                CalmEmptyStateCard(
                    icon: "sparkles",
                    title: "Nothing here yet",
                    message: "Your first active habit will appear here as soon as you save it.",
                    accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme),
                    supportingText: "Start with a small intention or choose a template and save it from the habit editor.",
                    primaryActionTitle: "Create habit",
                    primaryAction: { presentedSheet = .create(nil) },
                )
            } else {
                CalmEmptyStateCard(
                    icon: "archivebox",
                    title: "All habits are archived",
                    message: "Nothing is active right now, so the library is resting quietly.",
                    accent: HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme),
                    supportingText: "Open archived habits to restore one, or create a new habit when you want to begin again.",
                    primaryActionTitle: "Open archived habits",
                    primaryAction: { presentedSheet = .archivedList },
                    secondaryActionTitle: "Create habit",
                    secondaryAction: { presentedSheet = .create(nil) },
                )
            }
        }
    }

    private var pausedHabitsCard: some View {
        CalmEmptyStateCard(
            icon: "pause.circle",
            title: "All active habits are paused",
            message: "These habits are still part of your local library, but none of them are asking for attention right now.",
            accent: HabitQuestDesignSystem.Palette.note(for: colorScheme),
            supportingText: "Tap any habit below to inspect it or resume it when the timing feels better.",
        )
    }

    private var activeHabitsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack(alignment: .center, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text("Active habits")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Spacer(minLength: 0)

                activeHabitsDisplayModeSwitcher
            }

            activeHabitsDisplay
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var archivedHabitsShortcut: some View {
        HStack {
            Spacer(minLength: 0)

            Button {
                presentedSheet = .archivedList
            } label: {
                Image(systemName: "archivebox")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(HabitQuestDesignSystem.Palette.backgroundSoft(for: colorScheme))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Archived habits"))
            .accessibilityHint(Text("Open archived habits."))
        }
    }

    private var activeHabitsDisplayModeSwitcher: some View {
        HStack(spacing: 4) {
            displayModeButton(title: "List", mode: .list)
            displayModeButton(title: "Sections", mode: .sections)
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.backgroundSoft(for: colorScheme))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme).opacity(0.75), lineWidth: 1)
        )
    }

    private func displayModeButton(title: String, mode: ActiveHabitsDisplayMode) -> some View {
        Button {
            activeHabitsDisplayMode = mode
        } label: {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(activeHabitsDisplayMode == mode ? HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme) : HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(activeHabitsDisplayMode == mode ? HabitQuestDesignSystem.Palette.surface(for: colorScheme) : .clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(activeHabitsDisplayMode == mode ? .isSelected : [])
    }

    private var activeHabitsDisplay: some View {
        Group {
            if activeHabitsDisplayMode == .list {
                activeHabitsList
            } else if canUseDaySections {
                activeHabitsSectionsContent
            } else {
                activeHabitsSectionsPreview
            }
        }
    }

    private var activeHabitsList: some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
            ForEach(activeHabits) { habit in
                HabitSwipeActionRow(
                    onTap: {
                        presentedSheet = .edit(habit)
                    },
                    leadingActions: [
                        HabitSwipeAction(
                            title: "Edit",
                            systemImage: "pencil",
                            tint: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                            accessibilityLabel: "Edit habit"
                        ) {
                            presentedSheet = .edit(habit)
                        }
                    ],
                    trailingActions: [
                        HabitSwipeAction(
                            title: "Archive",
                            systemImage: "archivebox",
                            tint: HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme),
                            accessibilityLabel: "Archive habit"
                        ) {
                            archiveHabit(habit)
                        }
                    ]
                ) {
                    HabitRowCardView(
                        habit: habit,
                        currentStreak: currentStreak(for: habit),
                        showsArchivedLabel: false,
                        daySectionTitle: habit.daySectionID.flatMap { daySectionsByID[$0]?.displayTitle },
                        presentation: .compact,
                        showsEditAffordance: true,
                        showsReorderHandle: true
                    )
                }
                .accessibilityLabel(Text("\(habit.title), active habit"))
                .onDrag {
                    draggedActiveHabitID = habit.id
                    return NSItemProvider(object: habit.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text.identifier],
                    delegate: HabitReorderDropDelegate(
                        targetHabit: habit,
                        habits: $activeHabits,
                        draggedHabitID: $draggedActiveHabitID,
                        onCommit: { reorderedHabits in
                            persistActiveHabitOrder(reorderedHabits)
                        }
                    )
                )

                if habit.id != activeHabits.last?.id {
                    Divider()
                        .overlay(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                }
            }
        }
    }

    private var activeHabitsSectionsPreview: some View {
        ZStack {
            activeHabitsSectionsContent
                .blur(radius: 6)
                .opacity(0.82)
                .allowsHitTesting(false)

            PremiumDaySectionsOverlay(
                title: "Organize by day section",
                message: "Morning, afternoon, and evening views help HabitQuest feel more like your day. Unlock Premium to use this layout for real.",
                actionTitle: "Unlock day sections",
                accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme),
                onOpenPremium: {
                    premiumFeatureGateDescriptor = PremiumFeature.customDaySections.gateDescriptor(
                        origin: .habits,
                        entryPoint: "Organize active habits by day section"
                    )
                }
            )
        }
    }

    private var activeHabitsSectionsContent: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            ForEach(activeHabitSectionGroups) { group in
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(group.title)
                            .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Spacer(minLength: 0)

                        Text("\(group.habits.count)")
                            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }

                    VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                        ForEach(group.habits) { habit in
                            HabitSwipeActionRow(
                                onTap: {
                                    presentedSheet = .edit(habit)
                                },
                                leadingActions: [
                                    HabitSwipeAction(
                                        title: "Edit",
                                        systemImage: "pencil",
                                        tint: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                                        accessibilityLabel: "Edit habit"
                                    ) {
                                        presentedSheet = .edit(habit)
                                    }
                                ],
                                trailingActions: [
                                    HabitSwipeAction(
                                        title: "Archive",
                                        systemImage: "archivebox",
                                        tint: HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme),
                                        accessibilityLabel: "Archive habit"
                                    ) {
                                        archiveHabit(habit)
                                    }
                                ]
                            ) {
                            HabitRowCardView(
                                habit: habit,
                                currentStreak: currentStreak(for: habit),
                                showsArchivedLabel: false,
                                daySectionTitle: habit.daySectionID.flatMap { daySectionsByID[$0]?.displayTitle },
                                presentation: .compact,
                                showsEditAffordance: true
                            )
                        }
                            .accessibilityLabel(Text("\(habit.title), active habit"))
                        }
                    }
                    .padding(.leading, HabitQuestDesignSystem.Spacing.xs)
                }
            }
        }
    }

    private var canUseDaySections: Bool {
        environment.premiumEntitlementService.canAccess(.customDaySections) || environment.premiumEntitlementService.canAccess(.advancedRoutines)
    }

    private var activeHabitSectionGroups: [HabitSectionGroup] {
        let builtInSectionIDs = Set(HabitDaySectionCatalog.builtInSections.map(\.id))
        let customSections = daySectionsByID.values.filter { !builtInSectionIDs.contains($0.id) }
        let allSections = HabitDaySectionCatalog.allSections(customSections: customSections)

        let activeBySectionID = Dictionary(grouping: activeHabits) { habit -> UUID? in
            habit.daySectionID
        }

        var groups: [HabitSectionGroup] = []

        for section in allSections.sorted(by: { $0.order < $1.order }) {
            let habits = activeBySectionID[section.id] ?? []
            if !habits.isEmpty {
                groups.append(
                    HabitSectionGroup(
                        id: section.id,
                        title: section.displayTitle,
                        habits: habits.sorted(by: habitSortOrder)
                    )
                )
            }
        }

        let unassignedHabits = activeBySectionID[nil] ?? []
        if !unassignedHabits.isEmpty {
            groups.append(
                HabitSectionGroup(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                    title: "Unassigned",
                    habits: unassignedHabits.sorted(by: habitSortOrder)
                )
            )
        }

        return groups
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Label("Could not load habits", systemImage: "exclamationmark.triangle")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            Text(message)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func reloadHabits() {
        do {
            let allHabits = try environment.habitRepository.fetchHabits()
            let customSections = (try? environment.habitDaySectionStore.loadSections()) ?? []
            daySectionsByID = Dictionary(uniqueKeysWithValues: HabitDaySectionCatalog.allSections(customSections: customSections).map { ($0.id, $0) })
            activeHabits = allHabits
                .filter { !$0.isArchived }
                .sorted(by: habitSortOrder)
            archivedHabits = allHabits
                .filter { $0.isArchived }
                .sorted(by: habitSortOrder)
            loadErrorMessage = nil
        } catch {
            activeHabits = []
            archivedHabits = []
            loadErrorMessage = error.localizedDescription
        }

        do {
            completionEvents = try environment.completionEventStore.loadEvents()
        } catch {
            completionEvents = []
            loadErrorMessage = error.localizedDescription
        }
    }

    private func queueSheet(_ sheet: HabitManagementSheet) {
        queuedSheet = sheet
        presentedSheet = nil
    }

    private func currentStreak(for habit: Habit) -> Int {
        progressSummary(for: habit).currentStreak
    }

    private func progressSummary(for habit: Habit) -> HabitProgressSummary {
        environment.habitProgressCalculator.summary(
            for: habit,
            completionEvents: completionEvents,
            upTo: environment.dateService.now,
            calendar: environment.dateService.calendar
        )
    }

    private func togglePauseState(for habit: Habit) {
        do {
            let now = environment.dateService.now
            let newIsPaused = !habit.isPaused
            try environment.habitRepository.setHabitPaused(id: habit.id, isPaused: newIsPaused)
            environment.hapticService.play(.habitDeferred)
            reloadHabits()
            presentedSheet = nil

            if newIsPaused {
                Task {
                    await environment.notificationScheduler.cancelReminders(for: habit.id)
                }
            } else {
                var refreshedHabit = habit
                refreshedHabit.isPaused = false
                refreshedHabit.updatedAt = now

                Task {
                    await environment.notificationScheduler.syncReminders(
                        for: refreshedHabit,
                        state: nil,
                        now: now,
                        calendar: environment.dateService.calendar
                    )
                }
            }
        } catch {
            loadErrorMessage = error.localizedDescription
            environment.hapticService.play(.habitDeferred)
        }
    }

    private var allHabitsPaused: Bool {
        return !activeHabits.isEmpty && activeHabits.allSatisfy(\.isPaused)
    }

    private func archiveHabit(_ habit: Habit) {
        do {
            try environment.habitRepository.archiveHabit(id: habit.id)
            environment.hapticService.play(.habitDeferred)
            reloadHabits()
            presentedSheet = nil

            Task {
                await environment.notificationScheduler.cancelReminders(for: habit.id)
            }
        } catch {
            loadErrorMessage = error.localizedDescription
            environment.hapticService.play(.habitDeferred)
        }
    }

    private func restoreHabit(_ habit: Habit) {
        do {
            var restoredHabit = habit
            restoredHabit.isArchived = false
            restoredHabit.updatedAt = environment.dateService.now
            _ = try environment.habitRepository.updateHabit(restoredHabit)
            environment.hapticService.play(.habitCreated)
            reloadHabits()
            presentedSheet = nil
        } catch {
            loadErrorMessage = error.localizedDescription
            environment.hapticService.play(.habitDeferred)
        }
    }

    private func deleteHabit(_ habit: Habit) {
        do {
            try environment.habitRepository.deleteHabit(id: habit.id)
            reloadHabits()
            presentedSheet = nil

            Task {
                await environment.notificationScheduler.cancelReminders(for: habit.id)
            }
        } catch {
            loadErrorMessage = error.localizedDescription
            environment.hapticService.play(.habitDeferred)
        }
    }

    private func persistActiveHabitOrder(_ reorderedHabits: [Habit]) {
        let now = environment.dateService.now

        do {
            for (index, habit) in reorderedHabits.enumerated() {
                var reorderedHabit = habit
                reorderedHabit.displayOrder = Int64(reorderedHabits.count - index)
                reorderedHabit.updatedAt = now
                _ = try environment.habitRepository.updateHabit(reorderedHabit)
            }

            reloadHabits()
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    private func habitSortOrder(_ lhs: Habit, _ rhs: Habit) -> Bool {
        if lhs.displayOrder != rhs.displayOrder {
            return lhs.displayOrder > rhs.displayOrder
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

private enum ActiveHabitsDisplayMode: String, CaseIterable, Identifiable {
    case list
    case sections

    var id: String { rawValue }
}

private struct HabitSectionGroup: Identifiable {
    let id: UUID
    let title: String
    let habits: [Habit]
}

private struct HabitReorderDropDelegate: DropDelegate {
    let targetHabit: Habit
    @Binding var habits: [Habit]
    @Binding var draggedHabitID: UUID?
    let onCommit: ([Habit]) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedHabitID,
              draggedHabitID != targetHabit.id,
              let fromIndex = habits.firstIndex(where: { $0.id == draggedHabitID }),
              let toIndex = habits.firstIndex(where: { $0.id == targetHabit.id }) else {
            return
        }

        withAnimation(.snappy) {
            habits.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedHabitID = nil
        onCommit(habits)
        return true
    }
}

private struct PremiumDaySectionsOverlay: View {
    let title: String
    let message: String
    let actionTitle: String
    let accent: Color
    let onOpenPremium: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                )

            VStack(spacing: 4) {
                Text(title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onOpenPremium) {
                Text(actionTitle)
            }
            .buttonStyle(HabitQuestButtonStyle(role: .primary))
        }
        .frame(maxWidth: .infinity)
        .padding(HabitQuestDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surfaceRaised(for: colorScheme).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme).opacity(0.40), lineWidth: 1)
                )
        )
        .padding(HabitQuestDesignSystem.Spacing.lg)
    }
}

private struct HabitRowView: View {
    let habit: Habit
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(accentColor.opacity(0.20))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(displayIcon)
                        .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                        .foregroundStyle(accentColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(habit.title)
                        .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Spacer(minLength: 0)

                    if let category = habit.category, !category.isEmpty {
                        Text(category)
                            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }
                }

                Text(scheduleSummary)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                if let notes = habit.notes, !notes.isEmpty {
                    Text(notes)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var accentColor: Color {
        Color(hex: habit.colorHex ?? HabitAccentChoice.amber.hex) ?? HabitAccentChoice.amber.color
    }

    private var displayIcon: String {
        if let icon = habit.icon, !icon.isEmpty {
            return icon
        }
        return "•"
    }

    private var scheduleSummary: String {
        switch habit.schedule {
        case .daily:
            return "\(habit.dailyRhythm.title) · Daily"
        case .weekly(let days):
            return "\(habit.dailyRhythm.title) · Weekly \(weekdayList(days))"
        case .biWeekly(let days):
            return "\(habit.dailyRhythm.title) · Bi-weekly \(weekdayList(days))"
        case .monthly(let dayOfMonth):
            return "\(habit.dailyRhythm.title) · Day \(dayOfMonth)"
        case .customDays(let days):
            return "\(habit.dailyRhythm.title) · Custom \(weekdayList(days))"
        case .specificDateRange(let range):
            return "\(habit.dailyRhythm.title) · \(rangeSummary(range))"
        }
    }

    private func weekdayList(_ days: Set<Weekday>) -> String {
        days.sorted(by: { $0.rawValue < $1.rawValue }).map(\.shortTitle).joined(separator: " ")
    }

    private func rangeSummary(_ range: HabitDateRange) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
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
    var title: String {
        switch self {
        case .sunday:
            return "Sunday"
        case .monday:
            return "Monday"
        case .tuesday:
            return "Tuesday"
        case .wednesday:
            return "Wednesday"
        case .thursday:
            return "Thursday"
        case .friday:
            return "Friday"
        case .saturday:
            return "Saturday"
        }
    }

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

enum HabitManagementSheet: Identifiable, Equatable {
    case create(HabitTemplate?)
    case edit(Habit)
    case detail(Habit)
    case archivedList
    case daySections

    var id: String {
        switch self {
        case .create(let template):
            return "create-\(template?.id ?? "default")"
        case .edit(let habit):
            return "edit-\(habit.id.uuidString)"
        case .detail(let habit):
            return "detail-\(habit.id.uuidString)"
        case .archivedList:
            return "archived"
        case .daySections:
            return "day-sections"
        }
    }
}

struct CreateHabitView: View {
    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var draft: HabitCreationDraft
    @State private var isExpanded = false
    @State private var saveErrorMessage: String?
    @State private var showingSaveError = false
    @State private var customDaySections: [HabitDaySection] = []
    @State private var premiumFeatureGateDescriptor: PremiumFeatureGateDescriptor?
    @State private var premiumPaywallSourceMetadata: PremiumPaywallSourceMetadata?
    @State private var isPresentingPremiumPaywall = false
    @State private var isPresentingAdvancedSchedulingEditor = false
    @State private var isPresentingEmojiPicker = false
    @State private var isPresentingEmojiLibrary = false
    @State private var isPresentingCategoryPicker = false
    @State private var categoryOptions: [String] = []
    @FocusState private var focusedField: Field?

    let mode: Mode
    let onHabitSaved: (Habit) -> Void

    enum Mode: Equatable {
        case create(template: HabitTemplate? = nil)
        case edit(Habit)

        var navigationTitle: String {
            switch self {
            case .create:
                return "Create Habit"
            case .edit:
                return "Edit Habit"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .create:
                return "Save"
            case .edit:
                return "Save Changes"
            }
        }

        var headerLabel: String {
            switch self {
            case .create:
                return "Set an intention"
            case .edit:
                return "Refine an intention"
            }
        }

        var headerTitle: String {
            switch self {
            case .create:
                return "Create a habit that feels easy to return to."
            case .edit:
                return "Adjust the habit without changing its calm rhythm."
            }
        }

        var headerBody: String {
            switch self {
            case .create:
                return "Start with one clear habit and keep the default settings simple. You can refine the rest without pressure."
            case .edit:
                return "The fundamentals stay intact while you tune the details that help the habit feel more sustainable."
            }
        }

        var existingHabit: Habit? {
            switch self {
            case .create:
                return nil
            case .edit(let habit):
                return habit
            }
        }
    }

    private enum Field {
        case title
        case notes
        case icon
        case category
    }

    init(onHabitCreated: @escaping (Habit) -> Void) {
        self.init(mode: .create(), onHabitSaved: onHabitCreated)
    }

    init(template: HabitTemplate? = nil, onHabitCreated: @escaping (Habit) -> Void) {
        self.init(mode: .create(template: template), onHabitSaved: onHabitCreated)
    }

    init(habit: Habit, onHabitSaved: @escaping (Habit) -> Void) {
        self.init(mode: .edit(habit), onHabitSaved: onHabitSaved)
    }

    private init(mode: Mode, onHabitSaved: @escaping (Habit) -> Void) {
        _draft = State(initialValue: HabitCreationDraft(mode: mode))
        self.mode = mode
        self.onHabitSaved = onHabitSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                    if case .create = mode {
                        templateGalleryCard
                    }
                    headerCard
                    titleCard
                    intentionCard
                    notesCard
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.saveButtonTitle) {
                        saveHabit()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .alert("Could not save habit", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Something went wrong.")
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
            .sheet(isPresented: $isPresentingAdvancedSchedulingEditor) {
                HabitAdvancedSchedulingEditorView(
                    initialSchedule: draft.advancedSchedule,
                    now: environment.dateService.now,
                    calendar: environment.dateService.calendar
                ) { advancedSchedule in
                    draft.advancedSchedule = advancedSchedule
                }
            }
            .sheet(isPresented: $isPresentingEmojiPicker) {
                HabitEmojiPickerView(
                    selectedIcon: draft.icon,
                    onSelect: { icon in
                        draft.icon = icon
                        focusedField = nil
                        isPresentingEmojiPicker = false
                    },
                    onMore: {
                        isPresentingEmojiPicker = false
                        isPresentingEmojiLibrary = true
                    },
                    onClear: {
                        draft.icon = ""
                        focusedField = nil
                        isPresentingEmojiPicker = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
            .sheet(isPresented: $isPresentingEmojiLibrary) {
                HabitEmojiLibraryView(
                    selectedIcon: draft.icon,
                    onSelect: { icon in
                        draft.icon = icon
                        focusedField = nil
                        isPresentingEmojiLibrary = false
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
            .sheet(isPresented: $isPresentingCategoryPicker) {
                HabitCategoryPickerView(
                    selectedCategory: draft.category.trimmingCharacters(in: .whitespacesAndNewlines),
                    existingCategories: categoryOptions,
                    onSelect: { category in
                        draft.category = category
                        isPresentingCategoryPicker = false
                    },
                    onCreateNewCategory: { category in
                        draft.category = category
                        isPresentingCategoryPicker = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
            .task {
                loadCustomDaySections()
                loadCategoryOptions()
            }
        }
    }

    private var templateGalleryCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start from a template")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text("Templates only pre-fill your habit. You stay in control of every setting before saving.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(HabitTemplateCatalog.curated) { template in
                        templateCard(for: template)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func templateCard(for template: HabitTemplate) -> some View {
        Button {
            draft.apply(template: template, now: environment.dateService.now, calendar: environment.dateService.calendar)
        } label: {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                HStack {
                    Text(template.icon)
                        .font(HabitQuestDesignSystem.Typography.headline)
                    Spacer(minLength: 0)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }

                Text(template.title)
                    .font(HabitQuestDesignSystem.Typography.bodyEmphasis)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(template.subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            .frame(width: 184, alignment: .leading)
            .padding(HabitQuestDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.xl, style: .continuous)
                            .stroke(
                                (Color(hex: template.accentHex) ?? HabitQuestDesignSystem.Palette.border(for: colorScheme)).opacity(draft.selectedTemplateID == template.id ? 0.9 : 0.35),
                                lineWidth: draft.selectedTemplateID == template.id ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(template.title))
        .accessibilityHint(Text("Pre-fills a new habit with this template."))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Label(mode.headerLabel, systemImage: "sparkles")
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            Text(mode.headerTitle)
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text(mode.headerBody)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Habit name")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            TextField("Read 10 pages", text: $draft.title)
                .focused($focusedField, equals: .title)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.done)
                .habitQuestInputField()
                .accessibilityLabel(Text("Habit name"))
                .accessibilityHint(Text("Give the habit a short, clear title."))

            if draft.trimmedTitle.isEmpty {
                Text("A short title is required to save.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var intentionCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current intention")
                            .font(HabitQuestDesignSystem.Typography.headline)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text("Everything below shapes the same habit, just at different levels of detail.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(HabitQuestDesignSystem.Motion.card) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(isExpanded ? "Hide details" : "Adjust details")
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 0) {
                    infoRow(label: "Recurrence", value: draft.schedule.displayTitle)
                    infoRow(label: "Time", value: draft.timeMode.title)
                    infoRow(label: "Rhythm", value: draft.dailyRhythm.title)

                    if let advancedSummary = draft.advancedSchedule?.displaySummary {
                        infoRow(label: "Advanced", value: advancedSummary)
                    }

                    if let daySectionTitle = draft.daySectionTitle(sections: customDaySections) {
                        infoRow(label: "Day section", value: daySectionTitle)
                    }

                    infoRow(label: "Reminders", value: draft.remindersEnabled ? "On" : "Off")
                    infoRow(label: "Difficulty", value: draft.difficultyEnabled ? "On · adds a small XP boost" : "Off")
                }
            }

            if isExpanded {
                VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                    detailsCard
                    scheduleCard
                    if environment.premiumEntitlementService.canAccess(.advancedScheduling) {
                        advancedSchedulingCard
                    }
                    timeCard
                    daySectionCard
                    remindersCard
                    difficultyCard
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var premiumDiscoverySection: some View {
        Group {
            if environment.premiumEntitlementService.accessState.isPremiumOrTrial {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Premium options")
                            .font(HabitQuestDesignSystem.Typography.headline)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        Text("You can see a few richer habit controls before deciding whether to unlock them.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                        PremiumFeaturePreviewCard(
                            entitlementService: environment.premiumEntitlementService,
                            descriptor: PremiumFeature.advancedRoutines.gateDescriptor(
                                origin: .habits,
                                entryPoint: "Habit routine preview"
                            ),
                            actionTitle: "See routine controls",
                            onOpenGate: { descriptor in
                                premiumFeatureGateDescriptor = descriptor
                            }
                        ) {
                            HabitRoutinesPreviewView()
                        }

                        PremiumFeaturePreviewCard(
                            entitlementService: environment.premiumEntitlementService,
                            descriptor: PremiumFeature.customDaySections.gateDescriptor(
                                origin: .habits,
                                entryPoint: "Custom day section preview"
                            ),
                            actionTitle: "See day sections",
                            onOpenGate: { descriptor in
                                premiumFeatureGateDescriptor = descriptor
                            }
                        ) {
                            HabitDaySectionsPreviewView()
                        }

                        PremiumFeaturePreviewCard(
                            entitlementService: environment.premiumEntitlementService,
                            descriptor: PremiumFeature.multipleReminders.gateDescriptor(
                                origin: .habits,
                                entryPoint: "Habit reminder preview"
                            ),
                            actionTitle: "See reminder options",
                            onOpenGate: { descriptor in
                                premiumFeatureGateDescriptor = descriptor
                            }
                        ) {
                            HabitReminderPreviewView()
                        }
                    }
                }
                .habitQuestSurface(.raised)
            }
        }
    }

    private var daySectionCard: some View {
        Group {
            if environment.premiumEntitlementService.canAccess(.advancedRoutines) || environment.premiumEntitlementService.canAccess(.customDaySections) {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                    Text("Day section")
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Picker("Day section", selection: daySectionBinding) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(HabitDaySectionCatalog.builtInSections) { section in
                            Text(section.displayTitle).tag(Optional(section.id))
                        }
                        ForEach(customDaySections.sorted(by: { $0.order < $1.order })) { section in
                            Text(section.displayTitle).tag(Optional(section.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Use this to organize the habit into a richer day flow without changing its recurrence.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .habitQuestSurface(.raised)
            }
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Optional notes")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            TextEditor(text: $draft.notes)
                .focused($focusedField, equals: .notes)
                .frame(minHeight: 88)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                )

            Text("Notes are optional. Use them only if they help the habit feel more specific.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Appearance")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Button {
                    isPresentingEmojiPicker = true
                } label: {
                    HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                        Circle()
                            .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.65))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(iconPreview)
                                    .font(HabitQuestDesignSystem.Typography.title2)
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Choose an emoji" : "Selected emoji")
                                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            Text("Pick from a quick emoji grid or open the full emoji library.")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    }
                    .padding(HabitQuestDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                            .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Choose emoji or icon"))
                .accessibilityHint(Text("Opens a quick emoji picker."))
            }

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text("Accent color")
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: HabitQuestDesignSystem.Spacing.sm)], alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(HabitAccentChoice.allCases) { choice in
                        Button {
                            draft.selectedColor = choice
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(choice.color)
                                    .frame(width: 24, height: 24)
                                Text(choice.title)
                                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .fill(draft.selectedColor == choice ? HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.40) : HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                            .stroke(draft.selectedColor == choice ? choice.color.opacity(0.55) : HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(choice.title))
                        .accessibilityAddTraits(draft.selectedColor == choice ? .isSelected : [])
                    }
                }
            }

            Button {
                isPresentingCategoryPicker = true
            } label: {
                HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    Circle()
                        .fill(HabitQuestDesignSystem.Palette.note(for: colorScheme).opacity(0.18))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "tag")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.note(for: colorScheme))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Category")
                            .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        Text(categorySelectionTitle)
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                }
                .padding(HabitQuestDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                        .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Category"))
            .accessibilityHint(Text("Choose from existing categories or create a new one."))
        }
    }

    private var iconPreview: String {
        let trimmed = draft.icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "🙂" : trimmed
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.md) {
                Text("Recurrence")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Spacer(minLength: 0)

                Picker("Schedule", selection: scheduleBinding) {
                    ForEach(HabitScheduleChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel(Text("Schedule"))
            }

            if draft.schedule.requiresWeekdaySelection {
                weekdaysPicker
            }

            if draft.schedule == .monthly {
                Menu {
                    ForEach(1...31, id: \.self) { day in
                        Button {
                            draft.monthDay = day
                        } label: {
                            Text(monthDayLabel(for: day))
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Monthly day")
                                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            Text(monthDayDescription(for: draft.monthDay))
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Text(monthDayLabel(for: draft.monthDay))
                            .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    }
                    .padding(HabitQuestDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                            .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Monthly day"))
                .accessibilityHint(Text("Choose the day this habit repeats each month."))

                Text("If you choose the 31st, HabitQuest treats shorter months as the last available day.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if draft.schedule == .specificDateRange {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    DatePicker("Start date", selection: $draft.rangeStartDate, displayedComponents: [.date])
                    DatePicker("End date", selection: $draft.rangeEndDate, in: draft.rangeStartDate..., displayedComponents: [.date])
                }
                .datePickerStyle(.compact)
            }
        }
    }

    private var advancedSchedulingCard: some View {
        Group {
            if environment.premiumEntitlementService.canAccess(.advancedScheduling) {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Advanced scheduling")
                                .font(HabitQuestDesignSystem.Typography.headline)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                            Text(draft.advancedSchedule?.displaySummary ?? "Add richer recurrence rules, time targets, and gentle exceptions.")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    Button {
                        isPresentingAdvancedSchedulingEditor = true
                    } label: {
                        Label(
                            draft.advancedSchedule == nil ? "Configure advanced scheduling" : "Edit advanced scheduling",
                            systemImage: "slider.horizontal.3"
                        )
                    }
                    .habitQuestGlassButtonStyle(prominent: true)

                    if draft.advancedSchedule != nil {
                        Button {
                            draft.advancedSchedule = nil
                        } label: {
                            Text("Remove advanced scheduling")
                        }
                        .habitQuestGlassButtonStyle()
                    }
                }
            } else {
                PremiumFeaturePreviewCard(
                    entitlementService: environment.premiumEntitlementService,
                    descriptor: PremiumFeature.advancedScheduling.gateDescriptor(
                        origin: .habits,
                        entryPoint: "Advanced scheduling preview"
                    ),
                    actionTitle: "Unlock advanced scheduling",
                    onOpenGate: { descriptor in
                        premiumFeatureGateDescriptor = descriptor
                    }
                ) {
                    HabitAdvancedSchedulingPreviewView()
                }
            }
        }
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Time")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text("Time of day")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach(HabitTimeModeChoice.allCases) { choice in
                        Button {
                            selectTimeMode(choice)
                        } label: {
                            HabitQuestGlassChip(
                                title: choice.title,
                                isSelected: draft.timeMode == choice
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if draft.timeMode == .specificTime {
                DatePicker("Exact time", selection: $draft.exactTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
            }

            if draft.timeMode == .timeWindow {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    DatePicker("Window start", selection: $draft.windowStartTime, displayedComponents: [.hourAndMinute])
                    DatePicker("Window end", selection: $draft.windowEndTime, displayedComponents: [.hourAndMinute])
                }
                .datePickerStyle(.compact)
            }

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                Text("Daily rhythm")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                    ForEach([HabitRhythm.anytime, .morning, .day, .evening], id: \.self) { rhythm in
                        Button {
                            selectDailyRhythm(rhythm)
                        } label: {
                            HabitQuestGlassChip(
                                title: rhythm.title,
                                isSelected: draft.dailyRhythm == rhythm
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if draft.dailyRhythm != .anytime {
                    Text("Morning, Day, and Evening are part of Premium. Anytime stays available for everyone.")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Reminders")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Toggle("Add a reminder", isOn: $draft.remindersEnabled)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            if draft.remindersEnabled {
                DatePicker("Reminder time", selection: $draft.reminderTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
            }
        }
    }

    private var difficultyCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Toggle("Add difficulty", isOn: $draft.difficultyEnabled)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            if draft.difficultyEnabled {
                Stepper(value: $draft.difficulty, in: 1...5) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Difficulty \(draft.difficulty)/5")
                            .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        Text("Higher values give a little more XP, but the habit itself stays the same.")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    }
                }
            }
        }
    }

    private var weekdaysPicker: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Select weekdays")
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                ForEach(Array(Weekday.allCases.enumerated()), id: \.offset) { _, weekday in
                    Button {
                        if draft.selectedWeekdays.contains(weekday) {
                            draft.selectedWeekdays.remove(weekday)
                        } else {
                            draft.selectedWeekdays.insert(weekday)
                        }
                    } label: {
                        Text(weekday.shortTitle)
                            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(draft.selectedWeekdays.contains(weekday) ? .white : HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            .background(
                                Circle()
                                    .fill(draft.selectedWeekdays.contains(weekday) ? HabitQuestDesignSystem.Palette.accent(for: colorScheme) : HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                    .overlay(
                                        Circle()
                                            .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(weekday.title))
                    .accessibilityAddTraits(draft.selectedWeekdays.contains(weekday) ? .isSelected : [])
                }
            }
        }
    }

    private var canSave: Bool {
        draft.canSave && (!draft.schedule.requiresWeekdaySelection || !draft.selectedWeekdays.isEmpty)
    }

    private func selectTimeMode(_ choice: HabitTimeModeChoice) {
        switch choice {
        case .allDay:
            draft.timeMode = .allDay
        case .specificTime, .timeWindow:
            guard environment.premiumEntitlementService.canAccess(.advancedScheduling) else {
                draft.timeMode = .allDay
                presentPremiumGate(
                    feature: .advancedScheduling,
                    entryPoint: choice == .specificTime ? "Exact time" : "Time window"
                )
                return
            }
            draft.timeMode = choice
        }
    }

    private func selectDailyRhythm(_ rhythm: HabitRhythm) {
        switch rhythm {
        case .anytime:
            draft.dailyRhythm = .anytime
        case .morning, .day, .evening:
            guard environment.premiumEntitlementService.canAccess(.customDaySections) else {
                draft.dailyRhythm = .anytime
                presentPremiumGate(
                    feature: .customDaySections,
                    entryPoint: rhythm.title
                )
                return
            }
            draft.dailyRhythm = rhythm
        }
    }

    private func presentPremiumGate(feature: PremiumFeature, entryPoint: String) {
        premiumFeatureGateDescriptor = feature.gateDescriptor(
            origin: .habits,
            entryPoint: entryPoint
        )
    }

    private var categorySelectionTitle: String {
        let trimmed = draft.category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Choose from existing categories" : trimmed
    }

    private var scheduleBinding: Binding<HabitScheduleChoice> {
        Binding(
            get: { draft.schedule },
            set: { newValue in
                draft.prepareForScheduleChange(to: newValue, now: environment.dateService.now, calendar: environment.dateService.calendar)
            }
        )
    }

    private func saveHabit() {
        guard canSave else { return }

        let now = environment.dateService.now
        let habit = draft.makeHabit(
            existingHabit: mode.existingHabit,
            now: now,
            calendar: environment.dateService.calendar
        )

        do {
            let savedHabit: Habit
            switch mode {
            case .create:
                savedHabit = try environment.habitRepository.createHabit(habit)
                environment.hapticService.play(.habitCreated)
            case .edit:
                savedHabit = try environment.habitRepository.updateHabit(habit)
            }
            onHabitSaved(savedHabit)
            Task {
                await environment.notificationScheduler.syncReminders(
                    for: savedHabit,
                    state: nil,
                    now: now,
                    calendar: environment.dateService.calendar
                )
            }
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
            environment.hapticService.play(.habitDeferred)
        }
    }

    private func loadCustomDaySections() {
        customDaySections = (try? environment.habitDaySectionStore.loadSections()) ?? []
    }

    private func loadCategoryOptions() {
        var categories = Set<String>()

        if let habits = try? environment.habitRepository.fetchHabits() {
            for habit in habits {
                if let category = habit.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
                    categories.insert(category)
                }
            }
        }

        for template in HabitTemplateCatalog.curated {
            if let category = template.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
                categories.insert(category)
            }
        }

        categoryOptions = categories.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text(label)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .fill(HabitQuestDesignSystem.Palette.border(for: colorScheme).opacity(0.45))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func monthDayLabel(for day: Int) -> String {
        if day == 31 {
            return "Last day"
        }

        return "\(day)\(ordinalSuffix(for: day))"
    }

    private func monthDayDescription(for day: Int) -> String {
        if day == 31 {
            return "Runs on the last available day each month."
        }

        return "Runs on the \(monthDayLabel(for: day)) of each month."
    }

    private func ordinalSuffix(for value: Int) -> String {
        let remainder10 = value % 10
        let remainder100 = value % 100
        if remainder10 == 1 && remainder100 != 11 { return "st" }
        if remainder10 == 2 && remainder100 != 12 { return "nd" }
        if remainder10 == 3 && remainder100 != 13 { return "rd" }
        return "th"
    }

    private var daySectionBinding: Binding<UUID?> {
        Binding(
            get: { draft.daySectionID },
            set: { draft.daySectionID = $0 }
        )
    }
}

private struct HabitEmojiPickerView: View {
    let selectedIcon: String
    let onSelect: (String) -> Void
    let onMore: () -> Void
    let onClear: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let emojiChoices: [String] = [
        "💧", "🧘", "🏃", "🚶", "📚", "✍️", "🧠", "💤",
        "🪴", "🥗", "💪", "🧴", "🎧", "🫖", "🍎", "🥛",
        "🦷", "🧺", "🧹", "🪞", "🕯️", "🎯", "🧭", "🧃"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard
                        pickerCard
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear", role: .destructive) {
                        onClear()
                        dismiss()
                    }
                    .disabled(selectedIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Pick a visual cue")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Choose something that is easy to recognize at a glance.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            HStack {
                Text("Quick picks")
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Spacer(minLength: 0)

                Button("More") {
                    onMore()
                    dismiss()
                }
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 68), spacing: HabitQuestDesignSystem.Spacing.sm)],
                spacing: HabitQuestDesignSystem.Spacing.sm
            ) {
                ForEach(emojiChoices, id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .fill(selectedIcon == emoji ? HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.42) : HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                            .stroke(selectedIcon == emoji ? HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.75) : HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(emoji))
                        .accessibilityAddTraits(selectedIcon == emoji ? .isSelected : [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }
}

private struct HabitEmojiLibraryView: View {
    let selectedIcon: String
    let onSelect: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let emojiSections: [(title: String, emojis: [String])] = [
        ("People", ["🙂", "😊", "🤍", "🤝", "🧘", "🏃", "🚶", "💪", "🫶", "🤸", "🙏", "👣"]),
        ("Nature", ["🌿", "☀️", "🌙", "✨", "🔥", "💧", "🪴", "🌸", "🌱", "🍃", "🌊", "⛰️"]),
        ("Everyday", ["📚", "✍️", "🧠", "💤", "🧴", "🎧", "🫖", "🍎", "🥛", "🦷", "🧺", "🧹"]),
        ("Health", ["💊", "🫗", "🥗", "🧘", "🩺", "🛌", "🫧", "🦴", "🪥", "🚿", "🧼", "🫀"]),
        ("Work", ["🎯", "🧭", "🗓️", "📝", "📈", "📌", "📎", "📋", "💼", "⌛", "🖊️", "🗂️"]),
        ("Creative", ["🎨", "🎵", "🎬", "📸", "🪄", "🧵", "🪡", "🎭", "🧶", "🎼", "🖍️", "🪞"]),
        ("Routine", ["🌞", "🌤️", "🌧️", "🌅", "🌇", "🌃", "🕯️", "🛁", "🪞", "🛏️", "🏡", "🚿"])
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard

                        ForEach(emojiSections, id: \.title) { section in
                            sectionCard(title: section.title, emojis: section.emojis)
                        }
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("More Emojis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Choose a more specific symbol")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Pick from a broader emoji library and keep the habit easy to spot later.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private func sectionCard(title: String, emojis: [String]) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 54), spacing: HabitQuestDesignSystem.Spacing.sm)],
                spacing: HabitQuestDesignSystem.Spacing.sm
            ) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .fill(selectedIcon == emoji ? HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.42) : HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                            .stroke(selectedIcon == emoji ? HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.75) : HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(emoji))
                    .accessibilityAddTraits(selectedIcon == emoji ? .isSelected : [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }
}

private struct HabitCategoryPickerView: View {
    let selectedCategory: String
    let existingCategories: [String]
    let onSelect: (String) -> Void
    let onCreateNewCategory: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var newCategoryName: String = ""

    private var suggestedCategories: [String] {
        let defaults = [
            "Wellness", "Mindfulness", "Fitness", "Learning",
            "Reflection", "Care", "Mobility", "Health", "Rest", "Work"
        ]

        return Array(Set(defaults + existingCategories))
            .sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    private var filteredCategories: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return suggestedCategories
        }

        return suggestedCategories.filter { category in
            category.localizedCaseInsensitiveContains(query)
        }
    }

    private var trimmedNewCategoryName: String {
        newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreateNewCategory: Bool {
        !trimmedNewCategoryName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                        headerCard
                        categoryListCard
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitQuestDesignSystem.Palette.background(for: colorScheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text("Choose a category")
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Search existing categories or create a new one without leaving the editor.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised, padding: HabitQuestDesignSystem.Spacing.md)
    }

    private var categoryListCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Existing categories")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            TextField("Search categories or create a new one", text: $searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .submitLabel(.search)
                .habitQuestInputField()

            VStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                Button {
                    onSelect("")
                    dismiss()
                } label: {
                    HStack {
                        Text("No category")
                            .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        Spacer(minLength: 0)
                        if selectedCategory.isEmpty && trimmedSearchText.isEmpty && trimmedNewCategoryName.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                        }
                    }
                    .padding(HabitQuestDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                            .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                    .stroke(selectedCategory.isEmpty && trimmedSearchText.isEmpty && trimmedNewCategoryName.isEmpty ? HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.75) : HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                ForEach(filteredCategories, id: \.self) { category in
                    Button {
                        onSelect(category)
                        dismiss()
                    } label: {
                        HStack {
                            Text(category)
                                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            Spacer(minLength: 0)
                            if selectedCategory.caseInsensitiveCompare(category) == .orderedSame {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                            }
                        }
                        .padding(HabitQuestDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                .overlay(
                                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                        .stroke(
                                            selectedCategory.caseInsensitiveCompare(category) == .orderedSame ? HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.75) : HabitQuestDesignSystem.Palette.border(for: colorScheme),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                if filteredCategories.isEmpty, !trimmedSearchText.isEmpty {
                    Button {
                        onCreateNewCategory(trimmedSearchText)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create \"\(trimmedSearchText)\"")
                                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                                Text("Add this as a new category.")
                                    .font(HabitQuestDesignSystem.Typography.caption)
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                        }
                        .padding(HabitQuestDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                                .overlay(
                                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                                        .stroke(HabitQuestDesignSystem.Palette.accent(for: colorScheme).opacity(0.35), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                if trimmedSearchText.isEmpty {
                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                        Divider()
                            .overlay(HabitQuestDesignSystem.Palette.border(for: colorScheme))

                        Text("Create a new category")
                            .font(HabitQuestDesignSystem.Typography.headline)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                        TextField("New category", text: $newCategoryName)
                            .habitQuestInputField()

                        if canCreateNewCategory {
                            Text("Tap Done to create the category and apply it to the habit.")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Use this only if none of the existing categories fit.")
                                .font(HabitQuestDesignSystem.Typography.caption)
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            guard canCreateNewCategory else { return }
                            onCreateNewCategory(trimmedNewCategoryName)
                            dismiss()
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                        }
                        .habitQuestGlassButtonStyle(prominent: true)
                        .disabled(!canCreateNewCategory)
                    }
                    .padding(.top, HabitQuestDesignSystem.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }
}

private struct SummaryBadge: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
            .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                    )
            )
    }
}

struct HabitCreationDraft {
    var title: String = ""
    var notes: String = ""
    var icon: String = ""
    var category: String = ""
    var selectedTemplateID: String?
    var selectedColor: HabitAccentChoice = .amber
    var schedule: HabitScheduleChoice = .daily
    var selectedWeekdays: Set<Weekday> = [.monday]
    var monthDay: Int = 1
    var rangeStartDate: Date
    var rangeEndDate: Date
    var timeMode: HabitTimeModeChoice = .allDay
    var exactTime: Date
    var windowStartTime: Date
    var windowEndTime: Date
    var dailyRhythm: HabitRhythm = .anytime
    var daySectionID: UUID?
    var advancedSchedule: HabitAdvancedSchedule?
    var remindersEnabled: Bool = false
    var reminderTime: Date
    var difficultyEnabled: Bool = false
    var difficulty: Int = 2

    init(now: Date = .now, calendar: Calendar = .current) {
        exactTime = HabitCreationDraft.defaultTime(hour: 9, minute: 0, now: now, calendar: calendar)
        windowStartTime = HabitCreationDraft.defaultTime(hour: 9, minute: 0, now: now, calendar: calendar)
        windowEndTime = HabitCreationDraft.defaultTime(hour: 11, minute: 0, now: now, calendar: calendar)
        reminderTime = HabitCreationDraft.defaultTime(hour: 8, minute: 30, now: now, calendar: calendar)
        rangeStartDate = calendar.startOfDay(for: now)
        rangeEndDate = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) ?? now
        monthDay = calendar.component(.day, from: now)
        selectedWeekdays = [Weekday(calendarWeekday: calendar.component(.weekday, from: now))]
        daySectionID = nil
        advancedSchedule = nil
    }

    init(mode: CreateHabitView.Mode, now: Date = .now, calendar: Calendar = .current) {
        self.init(now: now, calendar: calendar)

        switch mode {
        case .create(let template):
            if let template {
                apply(template: template, now: now, calendar: calendar)
            }
        case .edit(let habit):
            title = habit.title
            notes = habit.notes ?? ""
            icon = habit.icon ?? ""
            category = habit.category ?? ""
            selectedColor = HabitCreationDraft.colorChoice(from: habit.colorHex) ?? .amber
            schedule = HabitCreationDraft.scheduleChoice(from: habit.schedule)
            selectedWeekdays = HabitCreationDraft.weekdays(from: habit.schedule, calendar: calendar, fallbackDate: habit.createdAt)
            monthDay = HabitCreationDraft.monthDay(from: habit.schedule, calendar: calendar, fallbackDate: habit.createdAt)
            rangeStartDate = HabitCreationDraft.rangeStartDate(from: habit.schedule) ?? calendar.startOfDay(for: now)
            rangeEndDate = HabitCreationDraft.rangeEndDate(from: habit.schedule) ?? (calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) ?? now)
            timeMode = HabitCreationDraft.timeModeChoice(from: habit.timeMode)
            dailyRhythm = habit.dailyRhythm
            daySectionID = habit.daySectionID
            advancedSchedule = habit.advancedSchedule

            if let reminderConfiguration = habit.reminderConfiguration,
                reminderConfiguration.isEnabled,
                let reminderTime = reminderConfiguration.rules.compactMap(HabitCreationDraft.reminderTime(from:)).first
            {
                self.reminderTime = HabitCreationDraft.defaultTime(hour: reminderTime.hour, minute: reminderTime.minute, now: now, calendar: calendar)
                remindersEnabled = true
            } else {
                remindersEnabled = false
            }

            if let difficulty = habit.difficulty {
                difficultyEnabled = true
                self.difficulty = difficulty
            } else {
                difficultyEnabled = false
                self.difficulty = 2
            }
        }
    }

    mutating func apply(template: HabitTemplate, now: Date, calendar: Calendar) {
        selectedTemplateID = template.id
        title = template.title
        notes = template.notes ?? ""
        icon = template.icon
        category = template.category ?? ""
        selectedColor = HabitCreationDraft.colorChoice(from: template.accentHex) ?? .amber
        schedule = HabitCreationDraft.scheduleChoice(from: template.schedule)
        selectedWeekdays = HabitCreationDraft.weekdays(from: template.schedule, calendar: calendar, fallbackDate: now)
        monthDay = HabitCreationDraft.monthDay(from: template.schedule, calendar: calendar, fallbackDate: now)
        rangeStartDate = HabitCreationDraft.rangeStartDate(from: template.schedule) ?? calendar.startOfDay(for: now)
        rangeEndDate = HabitCreationDraft.rangeEndDate(from: template.schedule) ?? (calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) ?? now)
        timeMode = HabitCreationDraft.timeModeChoice(from: template.timeMode)
            dailyRhythm = template.dailyRhythm
            daySectionID = nil
            advancedSchedule = nil

        if let reminderConfiguration = template.reminderConfiguration,
            reminderConfiguration.isEnabled,
            let reminderTime = reminderConfiguration.rules.compactMap(HabitCreationDraft.reminderTime(from:)).first
        {
            self.reminderTime = HabitCreationDraft.defaultTime(hour: reminderTime.hour, minute: reminderTime.minute, now: now, calendar: calendar)
            remindersEnabled = true
        } else {
            remindersEnabled = false
        }

        if let difficulty = template.difficulty {
            difficultyEnabled = true
            self.difficulty = difficulty
        } else {
            difficultyEnabled = false
            self.difficulty = 2
        }
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    mutating func prepareForScheduleChange(to newSchedule: HabitScheduleChoice, now: Date, calendar: Calendar) {
        schedule = newSchedule

        if newSchedule.requiresWeekdaySelection, selectedWeekdays.isEmpty {
            selectedWeekdays = [Weekday(calendarWeekday: calendar.component(.weekday, from: now))]
        }

        if newSchedule == .monthly {
            monthDay = calendar.component(.day, from: now)
        }

        if newSchedule == .specificDateRange {
            rangeStartDate = calendar.startOfDay(for: now)
            rangeEndDate = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) ?? now
        }
    }

    mutating func prepareForTimeModeChange(to newMode: HabitTimeModeChoice, now: Date, calendar: Calendar) {
        timeMode = newMode

        if newMode == .specificTime {
            exactTime = HabitCreationDraft.defaultTime(hour: calendar.component(.hour, from: now), minute: calendar.component(.minute, from: now), now: now, calendar: calendar)
        }

        if newMode == .timeWindow {
            let hour = calendar.component(.hour, from: now)
            windowStartTime = HabitCreationDraft.defaultTime(hour: hour, minute: 0, now: now, calendar: calendar)
            windowEndTime = HabitCreationDraft.defaultTime(hour: min(hour + 2, 23), minute: 0, now: now, calendar: calendar)
        }
    }

    func makeHabit(existingHabit: Habit? = nil, now: Date, calendar: Calendar = .current) -> Habit {
        let reminderConfiguration: HabitReminderConfiguration?
        if remindersEnabled {
            reminderConfiguration = HabitReminderConfiguration(
                isEnabled: true,
                rules: [
                    .atTime(HabitClockTime(
                        hour: calendar.component(.hour, from: reminderTime),
                        minute: calendar.component(.minute, from: reminderTime)
                    ))
                ]
            )
        } else {
            reminderConfiguration = nil
        }

        let schedule = self.schedule.domainValue(
            selectedWeekdays: selectedWeekdays,
            monthDay: monthDay,
            rangeStartDate: rangeStartDate,
            rangeEndDate: rangeEndDate
        )

        let timeMode = self.timeMode.domainValue(
            exactTime: exactTime,
            windowStartTime: windowStartTime,
            windowEndTime: windowEndTime,
            calendar: calendar
        )

        return Habit(
            id: existingHabit?.id ?? UUID(),
            title: trimmedTitle,
            notes: normalizedText(notes),
            icon: normalizedText(icon),
            colorHex: selectedColor.hex,
            category: normalizedText(category),
            isArchived: existingHabit?.isArchived ?? false,
            isPaused: existingHabit?.isPaused ?? false,
            schedule: schedule,
            timeMode: timeMode,
            dailyRhythm: dailyRhythm,
            daySectionID: daySectionID,
            advancedSchedule: advancedSchedule,
            reminderConfiguration: reminderConfiguration,
            difficulty: difficultyEnabled ? difficulty : nil,
            createdAt: existingHabit?.createdAt ?? now,
            updatedAt: now
        )
    }

    private func normalizedText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func defaultTime(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? now
    }

    private static func scheduleChoice(from schedule: HabitSchedule) -> HabitScheduleChoice {
        switch schedule {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .biWeekly:
            return .biWeekly
        case .monthly:
            return .monthly
        case .customDays:
            return .customDays
        case .specificDateRange:
            return .specificDateRange
        }
    }

    private static func weekdays(from schedule: HabitSchedule, calendar: Calendar, fallbackDate: Date) -> Set<Weekday> {
        switch schedule {
        case .weekly(let days), .biWeekly(let days), .customDays(let days):
            return days
        default:
            return [Weekday(calendarWeekday: calendar.component(.weekday, from: fallbackDate))]
        }
    }

    private static func monthDay(from schedule: HabitSchedule, calendar: Calendar, fallbackDate: Date) -> Int {
        switch schedule {
        case .monthly(let dayOfMonth):
            return dayOfMonth
        default:
            return calendar.component(.day, from: fallbackDate)
        }
    }

    private static func rangeStartDate(from schedule: HabitSchedule) -> Date? {
        if case .specificDateRange(let range) = schedule {
            return range.startDate
        }
        return nil
    }

    private static func rangeEndDate(from schedule: HabitSchedule) -> Date? {
        if case .specificDateRange(let range) = schedule {
            return range.endDate
        }
        return nil
    }

    private static func colorChoice(from hex: String?) -> HabitAccentChoice? {
        guard let hex else { return nil }
        return HabitAccentChoice.allCases.first { choice in
            choice.hex.caseInsensitiveCompare(hex.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    private static func timeModeChoice(from timeMode: HabitTimeMode) -> HabitTimeModeChoice {
        switch timeMode {
        case .allDay:
            return .allDay
        case .specificTime:
            return .specificTime
        case .timeWindow:
            return .timeWindow
        }
    }

    private static func hour(from timeMode: HabitTimeMode) -> Int? {
        if case .specificTime(let time) = timeMode {
            return time.hour
        }
        return nil
    }

    private static func minute(from timeMode: HabitTimeMode) -> Int? {
        if case .specificTime(let time) = timeMode {
            return time.minute
        }
        return nil
    }

    private static func windowStartHour(from timeMode: HabitTimeMode) -> Int? {
        if case .timeWindow(let window) = timeMode {
            return window.start.hour
        }
        return nil
    }

    private static func windowStartMinute(from timeMode: HabitTimeMode) -> Int? {
        if case .timeWindow(let window) = timeMode {
            return window.start.minute
        }
        return nil
    }

    private static func windowEndHour(from timeMode: HabitTimeMode) -> Int? {
        if case .timeWindow(let window) = timeMode {
            return window.end.hour
        }
        return nil
    }

    private static func windowEndMinute(from timeMode: HabitTimeMode) -> Int? {
        if case .timeWindow(let window) = timeMode {
            return window.end.minute
        }
        return nil
    }

    private static func reminderTime(from rule: HabitReminderRule) -> HabitClockTime? {
        if case .atTime(let time) = rule {
            return time
        }
        return nil
    }

    func daySectionTitle(sections: [HabitDaySection]) -> String? {
        guard let daySectionID else { return nil }
        return HabitDaySectionCatalog.section(with: daySectionID, customSections: sections)?.displayTitle
    }
}

private struct HabitRoutinesPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                HabitQuestGlassChip(title: "Morning", isSelected: true)
                HabitQuestGlassChip(title: "Afternoon", isSelected: false)
                HabitQuestGlassChip(title: "Evening", isSelected: false)
            }

            Text("Shape HabitQuest around intentional routines.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
    }
}

private struct HabitDaySectionsPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 6) {
                sectionRow(title: "Morning", note: "Gentle start")
                sectionRow(title: "Midday", note: "Steady progress")
                sectionRow(title: "Evening", note: "Wind-down")
            }

            Text("Custom day sections help the editor match your rhythm.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
    }

    private func sectionRow(title: String, note: String) -> some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Spacer(minLength: 0)

            Text(note)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
        }
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        )
    }
}

private struct HabitReminderPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            reminderRow(time: "8:00 AM", label: "First reminder")
            reminderRow(time: "6:30 PM", label: "Follow-up reminder")

            HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add another reminder")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
        }
    }

    private func reminderRow(time: String, label: String) -> some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
            Image(systemName: "bell")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(time)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                        .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        )
    }
}

enum HabitScheduleChoice: String, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case biWeekly
    case monthly
    case customDays
    case specificDateRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .biWeekly:
            return "Bi-weekly"
        case .monthly:
            return "Monthly"
        case .customDays:
            return "Custom Days"
        case .specificDateRange:
            return "Date Range"
        }
    }

    var requiresWeekdaySelection: Bool {
        switch self {
        case .weekly, .biWeekly, .customDays:
            return true
        case .daily, .monthly, .specificDateRange:
            return false
        }
    }

    func domainValue(
        selectedWeekdays: Set<Weekday>,
        monthDay: Int,
        rangeStartDate: Date,
        rangeEndDate: Date
    ) -> HabitSchedule {
        switch self {
        case .daily:
            return .daily
        case .weekly:
            return .weekly(days: selectedWeekdays)
        case .biWeekly:
            return .biWeekly(days: selectedWeekdays)
        case .monthly:
            return .monthly(dayOfMonth: monthDay)
        case .customDays:
            return .customDays(days: selectedWeekdays)
        case .specificDateRange:
            return .specificDateRange(HabitDateRange(startDate: rangeStartDate, endDate: rangeEndDate))
        }
    }
}

private extension HabitScheduleChoice {
    var displayTitle: String {
        title
    }
}

enum HabitTimeModeChoice: String, CaseIterable, Identifiable, Sendable {
    case allDay
    case specificTime
    case timeWindow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allDay:
            return "All Day"
        case .specificTime:
            return "Exact Time"
        case .timeWindow:
            return "Time Window"
        }
    }

    func domainValue(
        exactTime: Date,
        windowStartTime: Date,
        windowEndTime: Date,
        calendar: Calendar
    ) -> HabitTimeMode {
        switch self {
        case .allDay:
            return .allDay
        case .specificTime:
            return .specificTime(HabitClockTime(
                hour: calendar.component(.hour, from: exactTime),
                minute: calendar.component(.minute, from: exactTime)
            ))
        case .timeWindow:
            return .timeWindow(HabitTimeWindow(
                start: HabitClockTime(
                    hour: calendar.component(.hour, from: windowStartTime),
                    minute: calendar.component(.minute, from: windowStartTime)
                ),
                end: HabitClockTime(
                    hour: calendar.component(.hour, from: windowEndTime),
                    minute: calendar.component(.minute, from: windowEndTime)
                )
            ))
        }
    }
}

enum HabitAccentChoice: String, CaseIterable, Identifiable, Sendable {
    case amber
    case sage
    case clay
    case slate
    case sand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amber:
            return "Amber"
        case .sage:
            return "Sage"
        case .clay:
            return "Clay"
        case .slate:
            return "Slate"
        case .sand:
            return "Sand"
        }
    }

    var hex: String {
        switch self {
        case .amber:
            return "C66A1E"
        case .sage:
            return "6B8A71"
        case .clay:
            return "B9775A"
        case .slate:
            return "6D7E93"
        case .sand:
            return "B99363"
        }
    }

    var color: Color {
        Color(hex: hex) ?? Color.orange
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let rgb = UInt64(value, radix: 16) else {
            return nil
        }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }
}
