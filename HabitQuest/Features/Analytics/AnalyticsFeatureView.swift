import Charts
import SwiftUI

struct AnalyticsFeatureView: View {
    let onOpenHabits: () -> Void

    @Environment(\.habitQuestEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedRange: AnalyticsRange = .month
    @State private var report: HabitAnalyticsReport?
    @State private var premiumAnalyticsReport: HabitPremiumAnalyticsReport?
    @State private var habitsByID: [UUID: Habit] = [:]
    @State private var dailyStreakSummary: DailyStreakSummary?
    @State private var hasHabits = false
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var premiumFeatureGateDescriptor: PremiumFeatureGateDescriptor?
    @State private var premiumPaywallSourceMetadata: PremiumPaywallSourceMetadata?
    @State private var isPresentingPremiumPaywall = false

    init(onOpenHabits: @escaping () -> Void = {}) {
        self.onOpenHabits = onOpenHabits
    }

    var body: some View {
        ZStack {
            HabitQuestScreenBackground()

            ScrollView {
                LazyVStack(spacing: HabitQuestDesignSystem.Spacing.xl) {
                    header
                    rangePicker

                    if isLoading {
                        loadingState
                    } else if let loadError {
                        errorState(message: loadError)
                    } else if let report {
                        content(for: report)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                .padding(.bottom, HabitQuestDesignSystem.Spacing.xxl)
            }
        }
        .task(id: selectedRange) {
            await loadAnalytics()
        }
        .refreshable {
            await loadAnalytics()
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Analytics")
                .font(HabitQuestDesignSystem.Typography.display)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("Reflection-first insight from your local habit history.")
                .font(HabitQuestDesignSystem.Typography.body)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

            Text("Insight comes first. Charts follow. Metrics stay quiet.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
        }
    }

    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                ForEach(AnalyticsRange.allCases, id: \.self) { range in
                    Button {
                        selectRange(range)
                    } label: {
                        AnalyticsRangeChip(
                            title: range.title,
                            isSelected: selectedRange == range,
                            isLocked: range.requiresPremium && !environment.premiumEntitlementService.canAccess(range.feature)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func content(for report: HabitAnalyticsReport) -> some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.xl) {
            insightStack(for: report)
            premiumAnalyticsSection()
            premiumDiscoverySection(for: report)
            momentumSection(for: report)
            completionSection(for: report)
            streakSection(for: report)
            habitPerformanceSection(for: report)
            rhythmSection(for: report)
            deferralsSection(for: report)
            personalBestSection(for: report)
        }
    }

    private func insightStack(for report: HabitAnalyticsReport) -> some View {
        let insights = analyticsInsights(for: report)

        return VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Observations",
                title: "What stands out",
                subtitle: "Rule-based, local, and calm."
            )

            if insights.isEmpty {
                CalmEmptyStateCard(
                    icon: "chart.bar",
                    title: "Not enough history yet",
                    message: "As your completion history fills in, HabitQuest will surface gentle patterns here.",
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                    supportingText: "A few calm completions are enough for the first observations to appear.",
                    primaryActionTitle: hasHabits ? nil : "Open Habits",
                    primaryAction: hasHabits ? nil : onOpenHabits,
                )
            } else {
                ForEach(insights) { insight in
                    AnalyticsInsightCard(insight: insight)
                }
            }
        }
    }

    @ViewBuilder
    private func premiumAnalyticsSection() -> some View {
        if environment.premiumEntitlementService.canAccess(.advancedAnalytics) ||
            environment.premiumEntitlementService.canAccess(.longTermAnalytics),
           let premiumAnalyticsReport {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                sectionHeader(
                    eyebrow: "Premium analytics",
                    title: "Long-range patterns",
                    subtitle: "A quieter, deeper read on how your habits behave over time."
                )

                VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    AnalyticsChartCard(
                        title: "Completion-rate trend",
                        subtitle: "30, 90, 365, and all-time windows",
                        accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme),
                        accessibilityLabel: "Premium completion rate trend chart",
                        accessibilityValue: premiumCompletionTrendAccessibilityValue(for: premiumAnalyticsReport),
                        accessibilityHint: "A summarized view of completion rate across the selected premium windows."
                    ) {
                        Chart {
                            ForEach(premiumAnalyticsReport.completionRateTrend, id: \.date) { point in
                                LineMark(
                                    x: .value("Window", point.label),
                                    y: .value("Completion", point.value)
                                )
                                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                                PointMark(
                                    x: .value("Window", point.label),
                                    y: .value("Completion", point.value)
                                )
                                .foregroundStyle(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
                            }
                        }
                        .frame(height: 150)
                        .chartYScale(domain: 0...100)
                        .chartXAxis {
                            AxisMarks(values: premiumAnalyticsReport.completionRateTrend.map(\.label)) { value in
                                AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                                AxisTick().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                                AxisValueLabel {
                                    if let label = value.as(String.self) {
                                        Text(label)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                                AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                                AxisValueLabel {
                                    if let number = value.as(Double.self) {
                                        Text("\(Int(number))")
                                    }
                                }
                            }
                        }
                    }

                    if let comparison = premiumAnalyticsReport.comparison {
                        PremiumAnalyticsComparisonCard(comparison: comparison)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HabitQuestDesignSystem.Spacing.md) {
                        ForEach(premiumAnalyticsReport.windowSummaries, id: \.preset) { summary in
                            PremiumAnalyticsWindowSummaryCard(summary: summary)
                        }
                    }
                }

                if !premiumAnalyticsReport.insights.isEmpty {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                        ForEach(premiumAnalyticsReport.insights) { insight in
                            PremiumAnalyticsInsightCard(insight: insight)
                        }
                    }
                }
            }
            .habitQuestSurface(.raised)
        }
    }

    private func premiumCompletionTrendAccessibilityValue(for report: HabitPremiumAnalyticsReport) -> String {
        guard let first = report.completionRateTrend.first, let last = report.completionRateTrend.last else {
            return "No premium trend data yet."
        }

        return "From \(first.label) \(Int(first.value.rounded())) percent to \(last.label) \(Int(last.value.rounded())) percent."
    }

    @ViewBuilder
    private func premiumDiscoverySection(for report: HabitAnalyticsReport) -> some View {
        if !environment.premiumEntitlementService.accessState.isPremiumOrTrial {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                sectionHeader(
                    eyebrow: "Premium options",
                    title: "Longer views when you want them",
                    subtitle: "Free users can preview the deeper analytics before opening them."
                )

                VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    PremiumFeaturePreviewCard(
                        entitlementService: environment.premiumEntitlementService,
                        descriptor: PremiumFeature.advancedAnalytics.gateDescriptor(
                            origin: .analytics,
                            entryPoint: "90-day analytics preview"
                        ),
                        actionTitle: "See 90-day preview",
                        onOpenGate: { descriptor in
                            premiumFeatureGateDescriptor = descriptor
                        }
                    ) {
                        AnalyticsPreviewTrendView(
                            title: "90-day completion trend",
                            subtitle: "A representative longer-range view of consistency.",
                            accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme),
                            values: report.dailyCompletionHistory.suffix(12).compactMap { $0.completionRate }
                        )
                    }

                    PremiumFeaturePreviewCard(
                        entitlementService: environment.premiumEntitlementService,
                        descriptor: PremiumFeature.longTermAnalytics.gateDescriptor(
                            origin: .analytics,
                            entryPoint: "Yearly analytics preview"
                        ),
                        actionTitle: "See yearly preview",
                        onOpenGate: { descriptor in
                            premiumFeatureGateDescriptor = descriptor
                        }
                    ) {
                        AnalyticsPreviewTrendView(
                            title: "Yearly consistency",
                            subtitle: "A preview of how longer patterns read over time.",
                            accent: HabitQuestDesignSystem.Palette.success(for: colorScheme),
                            values: report.weeklyConsistency.compactMap { $0.completionRate }
                        )
                    }
                }
            }
        }
    }

    private func momentumSection(for report: HabitAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Momentum",
                title: "Recent consistency",
                subtitle: "A rolling score that rewards returning, not perfection."
            )

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                        Text("\(Int(report.momentumSummary.currentMomentum.rounded()))")
                            .font(HabitQuestDesignSystem.Typography.display)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            .monospacedDigit()

                        Text(report.momentumSummary.trend.direction.title)
                            .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                            .foregroundStyle(report.momentumSummary.trend.direction.color(for: colorScheme))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                        Text("Previous")
                            .font(HabitQuestDesignSystem.Typography.caption)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                        Text("\(Int(report.momentumSummary.previousMomentum.rounded()))")
                            .font(HabitQuestDesignSystem.Typography.title2.weight(.semibold))
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            .monospacedDigit()
                    }
                }

                if !report.momentumHistory.isEmpty {
                    Chart {
                        ForEach(report.momentumHistory.filter { $0.value != nil }, id: \.date) { point in
                            LineMark(
                                x: .value("Day", point.date),
                                y: .value("Momentum", point.value ?? 0)
                            )
                            .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Day", point.date),
                                y: .value("Momentum", point.value ?? 0)
                            )
                            .foregroundStyle(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
                        }
                    }
                    .frame(height: 170)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Momentum chart")
                    .accessibilityValue(momentumAccessibilityValue(for: report))
                    .accessibilityHint("A summary of your recent 30 day momentum trend.")
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisTick().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                            AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisValueLabel {
                                if let number = value.as(Double.self) {
                                    Text("\(Int(number))")
                                }
                            }
                        }
                    }
                }

                AnalyticsMetricRow(
                    items: [
                        AnalyticsMetricItem(
                            title: "Current streak",
                            value: "\(report.personalBests.longestDailyStreak == 0 ? report.personalBests.longestDailyStreak : report.personalBests.longestDailyStreak)",
                            subtitle: "days",
                            accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                        ),
                        AnalyticsMetricItem(
                            title: "Latest day",
                            value: "\(Int((report.dailyCompletionHistory.last?.completionRate ?? 0).rounded()))%",
                            subtitle: "completion",
                            accent: HabitQuestDesignSystem.Palette.success(for: colorScheme)
                        )
                    ]
                )
            }
        }
        .habitQuestSurface(.raised)
    }

    private func selectRange(_ range: AnalyticsRange) {
        if range.requiresPremium, !environment.premiumEntitlementService.canAccess(range.feature) {
            premiumFeatureGateDescriptor = range.feature.gateDescriptor(origin: .analytics, entryPoint: range.entryPoint)
            return
        }

        selectedRange = range
    }

    private func completionSection(for report: HabitAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Completion",
                title: "Daily and weekly rhythm",
                subtitle: "Completion trends stay readable, not crowded."
            )

            VStack(spacing: HabitQuestDesignSystem.Spacing.xl) {
                AnalyticsChartCard(
                    title: "Daily completion",
                    subtitle: "The last \(selectedRange.dayCount) days",
                    accent: HabitQuestDesignSystem.Palette.note(for: colorScheme),
                    accessibilityLabel: "Daily completion chart",
                    accessibilityValue: dailyCompletionAccessibilityValue(for: report),
                    accessibilityHint: "A summary of how fully each day was completed in the selected range."
                ) {
                    Chart {
                        ForEach(report.dailyCompletionHistory.filter { $0.dueCount > 0 }, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Completion", day.completionRate ?? 0)
                            )
                            .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme).gradient)
                            .cornerRadius(6)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisTick().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.weekday(.abbreviated))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                            AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisValueLabel {
                                if let number = value.as(Double.self) {
                                    Text("\(Int(number))")
                                }
                            }
                        }
                    }
                }

                AnalyticsChartCard(
                    title: "Weekly consistency",
                    subtitle: "Aggregated from local completion history",
                    accent: HabitQuestDesignSystem.Palette.success(for: colorScheme),
                    accessibilityLabel: "Weekly consistency chart",
                    accessibilityValue: weeklyConsistencyAccessibilityValue(for: report),
                    accessibilityHint: "A summary of how your weekly completion rate has changed across the selected range."
                ) {
                    Chart {
                        ForEach(report.weeklyConsistency, id: \.startDate) { week in
                            BarMark(
                                x: .value("Week", week.startDate, unit: .weekOfYear),
                                y: .value("Completion", week.completionRate ?? 0)
                            )
                            .foregroundStyle(HabitQuestDesignSystem.Palette.success(for: colorScheme).gradient)
                            .cornerRadius(6)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisTick().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.month().day())
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                            AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                            AxisValueLabel {
                                if let number = value.as(Double.self) {
                                    Text("\(Int(number))")
                                }
                            }
                        }
                    }
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private func streakSection(for report: HabitAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Streaks",
                title: "Consistency over time",
                subtitle: "HabitQuest treats streaks as a rhythm, not a scorecard."
            )

            AnalyticsMetricRow(
                items: [
                    AnalyticsMetricItem(
                        title: "Current daily streak",
                        value: "\(dailyStreakSummary?.currentDailyStreak ?? 0)",
                        subtitle: "fully complete days",
                        accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
                    ),
                    AnalyticsMetricItem(
                        title: "Longest daily streak",
                        value: "\(report.personalBests.longestDailyStreak)",
                        subtitle: "best run",
                        accent: HabitQuestDesignSystem.Palette.success(for: colorScheme)
                    )
                ]
            )

            if let bestHabit = rankedHabits(for: report).first {
                AnalyticsReflectionRow(
                    title: "\(bestHabit.habit.title) has been your strongest habit",
                    details: "It currently leads your habit streaks with \(bestHabit.longestStreak) completed occurrences.",
                    metric: "\(bestHabit.totalCompletions) completions"
                )
            }
        }
        .habitQuestSurface(.raised)
    }

    private func habitPerformanceSection(for report: HabitAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Habits",
                title: "Habit performance",
                subtitle: "Useful patterns for individual habits, without turning this into a spreadsheet."
            )

            VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                ForEach(Array(rankedHabits(for: report).prefix(3)), id: \.habit.id) { item in
                    HabitPerformanceRow(item: item)
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private func rhythmSection(for report: HabitAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Rhythm",
                title: "Daily rhythm patterns",
                subtitle: "Morning, day, evening, and anytime are treated as contextual signals."
            )

            VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                Chart {
                    ForEach(report.completionBehaviorByDailyRhythm, id: \.rhythm) { item in
                        BarMark(
                            x: .value("Completion", item.completionRate ?? 0),
                            y: .value("Rhythm", item.rhythm.displayTitle)
                        )
                        .foregroundStyle(item.rhythm.tint(for: colorScheme).gradient)
                        .cornerRadius(6)
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Daily rhythm chart")
                .accessibilityValue(dailyRhythmAccessibilityValue(for: report))
                .accessibilityHint("A summary of how completion varies by morning, day, evening, and anytime habits.")
                .chartXScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text("\(Int(number))%")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(HabitQuestDesignSystem.Palette.border(for: colorScheme))
                        AxisValueLabel()
                    }
                }

                if let insight = rhythmInsight(for: report) {
                    AnalyticsReflectionRow(
                        title: insight.title,
                        details: insight.body,
                        metric: insight.metric
                    )
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private func deferralsSection(for report: HabitAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Deferrals",
                title: "Frequently deferred habits",
                subtitle: "These are the habits most often moved to a later pass."
            )

            let items = rankedDeferrals(for: report)

            if items.isEmpty {
                AnalyticsEmptyInsightCard(
                    title: "Nothing is being deferred yet",
                    message: "As you start using Not Now, the habits that need a softer setup will appear here."
                )
            } else {
                VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                    ForEach(Array(items.prefix(3)), id: \.habit.id) { item in
                        HabitDeferralRow(item: item)
                    }
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private func personalBestSection(for report: HabitAnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            sectionHeader(
                eyebrow: "Personal bests",
                title: "Notable peaks",
                subtitle: "A gentle record of your strongest moments so far."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HabitQuestDesignSystem.Spacing.md) {
                AnalyticsMiniCard(title: "Best day", value: bestDayLabel(report), subtitle: bestDaySubtitle(report), accent: HabitQuestDesignSystem.Palette.note(for: colorScheme))
                AnalyticsMiniCard(title: "Best week", value: bestWeekValue(report), subtitle: bestWeekSubtitle(report), accent: HabitQuestDesignSystem.Palette.success(for: colorScheme))
                AnalyticsMiniCard(title: "Best month", value: bestMonthValue(report), subtitle: bestMonthSubtitle(report), accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                AnalyticsMiniCard(title: "Highest Momentum", value: "\(Int(report.personalBests.highestMomentum.rounded()))", subtitle: "on your recent history", accent: HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
            }
        }
        .habitQuestSurface(.raised)
    }

    private var loadingState: some View {
        VStack(spacing: HabitQuestDesignSystem.Spacing.md) {
            ProgressView()
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            Text("Loading insights...")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .habitQuestSurface(.raised)
    }

    private var emptyState: some View {
        CalmEmptyStateCard(
            icon: "chart.bar",
            title: "Your analytics will appear here",
            message: hasHabits
                ? "Complete a few habits and HabitQuest will turn that history into useful insights."
                : "Create your first habit and complete it a few times. HabitQuest will turn that history into useful insights.",
            accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme),
            supportingText: hasHabits ? "The charts need a little history before they become useful." : "Start in Habits when you’re ready.",
            primaryActionTitle: hasHabits ? nil : "Open Habits",
            primaryAction: hasHabits ? nil : onOpenHabits,
        )
    }

    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Couldn’t load analytics")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text(message)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

            Button("Try again") {
                Task {
                    await loadAnalytics()
                }
            }
            .buttonStyle(HabitQuestButtonStyle(role: .primary))
        }
        .habitQuestSurface(.raised)
    }

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text(eyebrow.uppercased())
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                .tracking(1.2)

            Text(title)
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text(subtitle)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
    }

    private func loadAnalytics() async {
        isLoading = true
        loadError = nil

        do {
            let calendar = environment.dateService.calendar
            let now = environment.dateService.now
            let range = selectedRange.range(endingAt: now, calendar: calendar)

            let habits = try environment.habitRepository.fetchHabits()
            let states = try environment.dailyHabitStateStore.loadStates()
            let events = try environment.completionEventStore.loadEvents()
            hasHabits = !habits.isEmpty

            report = environment.habitAnalyticsCalculator.report(
                for: habits,
                completionEvents: events,
                dailyStates: states,
                in: range,
                calendar: calendar
            )
            premiumAnalyticsReport = environment.premiumAnalyticsCalculator.report(
                for: habits,
                completionEvents: events,
                dailyStates: states,
                in: range,
                calendar: calendar
            )
            habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
            dailyStreakSummary = DailyStreakCalculator().summary(
                for: habits,
                states: states,
                completionEvents: events,
                upTo: now,
                calendar: calendar
            )
        } catch {
            loadError = (error as NSError).localizedDescription
            report = nil
            premiumAnalyticsReport = nil
            habitsByID = [:]
            dailyStreakSummary = nil
            hasHabits = false
        }

        isLoading = false
    }

    private func analyticsInsights(for report: HabitAnalyticsReport) -> [AnalyticsInsight] {
        var insights: [AnalyticsInsight] = []

        if let insight = momentumInsight(for: report) {
            insights.append(insight)
        }

        if let insight = rhythmInsight(for: report) {
            insights.append(insight)
        }

        if let insight = deferralInsight(for: report) {
            insights.append(insight)
        }

        return Array(insights.prefix(3))
    }

    private func dailyCompletionAccessibilityValue(for report: HabitAnalyticsReport) -> String {
        let days = report.dailyCompletionHistory.filter { $0.dueCount > 0 }
        guard let latest = days.last else {
            return "No completed days yet."
        }

        let best = days.compactMap { $0.completionRate }.max() ?? 0
        let average = days.compactMap { $0.completionRate }.reduce(0, +) / Double(max(days.compactMap { $0.completionRate }.count, 1))

        return "Latest day \(Int((latest.completionRate ?? 0).rounded())) percent. Best day \(Int(best.rounded())) percent. Average \(Int(average.rounded())) percent."
    }

    private func weeklyConsistencyAccessibilityValue(for report: HabitAnalyticsReport) -> String {
        guard let latest = report.weeklyConsistency.last else {
            return "No weekly history yet."
        }

        let best = report.weeklyConsistency.compactMap { $0.completionRate }.max() ?? 0
        let average = report.weeklyConsistency.compactMap { $0.completionRate }.reduce(0, +) / Double(max(report.weeklyConsistency.compactMap { $0.completionRate }.count, 1))

        return "Latest week \(Int((latest.completionRate ?? 0).rounded())) percent. Best week \(Int(best.rounded())) percent. Average \(Int(average.rounded())) percent."
    }

    private func dailyRhythmAccessibilityValue(for report: HabitAnalyticsReport) -> String {
        let values = Dictionary(uniqueKeysWithValues: report.completionBehaviorByDailyRhythm.map { ($0.rhythm, $0.completionRate ?? 0) })
        let morning = Int((values[.morning] ?? 0).rounded())
        let day = Int((values[.day] ?? 0).rounded())
        let evening = Int((values[.evening] ?? 0).rounded())
        let anytime = Int((values[.anytime] ?? 0).rounded())

        return "Morning \(morning) percent. Day \(day) percent. Evening \(evening) percent. Anytime \(anytime) percent."
    }

    private func momentumAccessibilityValue(for report: HabitAnalyticsReport) -> String {
        let current = Int(report.momentumSummary.currentMomentum.rounded())
        let previous = Int(report.momentumSummary.previousMomentum.rounded())
        return "Current \(current) out of 100. Previous \(previous) out of 100. Trend \(report.momentumSummary.trend.direction.title.lowercased())."
    }

    private func momentumInsight(for report: HabitAnalyticsReport) -> AnalyticsInsight? {
        let current = report.momentumSummary.currentMomentum
        let previous = report.momentumSummary.previousMomentum
        let delta = current - previous

        if current >= 80 {
            return AnalyticsInsight(
                eyebrow: "Momentum",
                title: "Your Momentum is strong.",
                body: "You’re holding a steady rhythm, and the recent pattern looks calm and sustainable.",
                metric: "\(Int(current.rounded())) / 100",
                accent: HabitQuestDesignSystem.Palette.success(for: colorScheme)
            )
        }

        if delta >= 4 {
            return AnalyticsInsight(
                eyebrow: "Momentum",
                title: "Your Momentum is rising.",
                body: "Recent completions are lifting the score in a gradual, sustainable way.",
                metric: "+\(Int(delta.rounded())) vs previous",
                accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
            )
        }

        if delta <= -4 {
            return AnalyticsInsight(
                eyebrow: "Momentum",
                title: "Momentum has softened slightly.",
                body: "The change is gradual, which usually means your habits are simply asking for a quieter setup.",
                metric: "\(Int(current.rounded())) / 100",
                accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
            )
        }

        return AnalyticsInsight(
            eyebrow: "Momentum",
            title: "Momentum is holding steady.",
            body: "Your recent behavior looks balanced rather than all-or-nothing.",
            metric: "\(Int(current.rounded())) / 100",
            accent: HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme)
        )
    }

    private func rhythmInsight(for report: HabitAnalyticsReport) -> AnalyticsInsight? {
        let morning = report.completionBehaviorByDailyRhythm.first(where: { $0.rhythm == .morning })?.completionRate ?? 0
        let day = report.completionBehaviorByDailyRhythm.first(where: { $0.rhythm == .day })?.completionRate ?? 0
        let evening = report.completionBehaviorByDailyRhythm.first(where: { $0.rhythm == .evening })?.completionRate ?? 0
        let anytime = report.completionBehaviorByDailyRhythm.first(where: { $0.rhythm == .anytime })?.completionRate ?? 0

        let entries: [(HabitRhythm, Double)] = [
            (.morning, morning),
            (.day, day),
            (.evening, evening),
            (.anytime, anytime)
        ]

        guard let best = entries.max(by: { $0.1 < $1.1 }) else {
            return nil
        }

        switch best.0 {
        case .morning:
            return AnalyticsInsight(
                eyebrow: "Daily Rhythm",
                title: "Your morning habits have been the most consistent.",
                body: "Morning habits are leading the month, which suggests your early routine is carrying a lot of the load.",
                metric: "\(Int(best.1.rounded()))% completion",
                accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
            )
        case .day:
            return AnalyticsInsight(
                eyebrow: "Daily Rhythm",
                title: "Your daytime habits are leading.",
                body: "Midday routines are the easiest fit right now, especially when they stay simple and well-timed.",
                metric: "\(Int(best.1.rounded()))% completion",
                accent: HabitQuestDesignSystem.Palette.success(for: colorScheme)
            )
        case .evening:
            return AnalyticsInsight(
                eyebrow: "Daily Rhythm",
                title: "Evening habits are your strongest pattern.",
                body: "That usually means your wind-down routine has a steady shape and good timing.",
                metric: "\(Int(best.1.rounded()))% completion",
                accent: HabitQuestDesignSystem.Palette.accent(for: colorScheme)
            )
        case .anytime:
            return AnalyticsInsight(
                eyebrow: "Daily Rhythm",
                title: "Anytime habits are showing up consistently.",
                body: "Flexible habits are giving your routine room to breathe without losing momentum.",
                metric: "\(Int(best.1.rounded()))% completion",
                accent: HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme)
            )
        }
    }

    private func deferralInsight(for report: HabitAnalyticsReport) -> AnalyticsInsight? {
        guard let mostDeferred = rankedDeferrals(for: report).first else {
            return nil
        }

        let rate = mostDeferred.deferralRate

        if rate >= 40 {
            return AnalyticsInsight(
                eyebrow: "Deferrals",
                title: "\(mostDeferred.habit.title) is often moved to later.",
                body: "That usually means the habit wants a smaller intention, a different time, or a softer cue.",
                metric: "\(Int(rate.rounded()))% deferred",
                accent: HabitQuestDesignSystem.Palette.note(for: colorScheme)
            )
        }

        if rate >= 20 {
            return AnalyticsInsight(
                eyebrow: "Deferrals",
                title: "A few habits are regularly waiting for later.",
                body: "Nothing is broken. HabitQuest is just showing you which routines are asking for more room.",
                metric: "\(Int(rate.rounded()))% deferred",
                accent: HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme)
            )
        }

        return nil
    }

    private func rankedHabits(for report: HabitAnalyticsReport) -> [AnalyticsHabitPerformanceItem] {
        report.completionRateByHabit.compactMap { habitID, completionRate in
            guard let habit = habitsByID[habitID] else {
                return nil
            }

            let progress = report.individualHabitStreaks[habitID]
            return AnalyticsHabitPerformanceItem(
                habit: habit,
                completionRate: completionRate,
                currentStreak: progress?.currentStreak ?? 0,
                longestStreak: progress?.longestStreak ?? 0,
                totalCompletions: progress?.totalCompletions ?? 0
            )
        }
        .sorted {
            if $0.completionRate == $1.completionRate {
                if $0.totalCompletions == $1.totalCompletions {
                    return $0.habit.title < $1.habit.title
                }

                return $0.totalCompletions > $1.totalCompletions
            }

            return $0.completionRate > $1.completionRate
        }
    }

    private func rankedDeferrals(for report: HabitAnalyticsReport) -> [AnalyticsHabitDeferralItem] {
        report.deferralFrequencyByHabit.compactMap { habitID, deferralRate in
            guard let habit = habitsByID[habitID] else {
                return nil
            }

            return AnalyticsHabitDeferralItem(
                habit: habit,
                deferralRate: deferralRate
            )
        }
        .sorted {
            if $0.deferralRate == $1.deferralRate {
                return $0.habit.title < $1.habit.title
            }

            return $0.deferralRate > $1.deferralRate
        }
    }

    private func bestDayLabel(_ report: HabitAnalyticsReport) -> String {
        guard let day = report.personalBests.bestDay else {
            return "—"
        }

        return day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func bestDaySubtitle(_ report: HabitAnalyticsReport) -> String {
        guard let day = report.personalBests.bestDay else {
            return "No best day yet"
        }

        return "\(Int((day.completionRate ?? 0).rounded()))% completion"
    }

    private func bestWeekValue(_ report: HabitAnalyticsReport) -> String {
        guard let week = report.personalBests.bestWeek else {
            return "—"
        }

        return "\(Int((week.completionRate ?? 0).rounded()))%"
    }

    private func bestWeekSubtitle(_ report: HabitAnalyticsReport) -> String {
        guard let week = report.personalBests.bestWeek else {
            return "No best week yet"
        }

        return "\(week.startDate.formatted(.dateTime.month(.abbreviated).day())) to \(week.endDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func bestMonthValue(_ report: HabitAnalyticsReport) -> String {
        guard let month = report.personalBests.bestMonth else {
            return "—"
        }

        return "\(Int((month.completionRate ?? 0).rounded()))%"
    }

    private func bestMonthSubtitle(_ report: HabitAnalyticsReport) -> String {
        guard let month = report.personalBests.bestMonth else {
            return "No best month yet"
        }

        return month.startDate.formatted(.dateTime.month(.wide))
    }
}

private struct AnalyticsInsight: Identifiable {
    let id = UUID()
    let eyebrow: String
    let title: String
    let body: String
    let metric: String
    let accent: Color
}

private struct AnalyticsHabitPerformanceItem {
    let habit: Habit
    let completionRate: Double
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
}

private struct AnalyticsHabitDeferralItem {
    let habit: Habit
    let deferralRate: Double
}

private struct AnalyticsMetricItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let accent: Color
}

private struct AnalyticsMetricRow: View {
    let items: [AnalyticsMetricItem]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HabitQuestDesignSystem.Spacing.md) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                    Text(item.title)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

                    Text(item.value)
                        .font(HabitQuestDesignSystem.Typography.title2)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                        .monospacedDigit()

                    Text(item.subtitle)
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(item.accent)
                }
                .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
            }
        }
    }
}

private struct AnalyticsReflectionRow: View {
    let title: String
    let details: String
    let metric: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.65))
                .frame(width: 12, height: 12)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                Text(title)
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(details)
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                Text(metric)
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    .tracking(0.8)
            }
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct AnalyticsInsightCard: View {
    let insight: AnalyticsInsight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(insight.accent.opacity(0.24))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(insight.accent)
                )

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                Text(insight.eyebrow.uppercased())
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    .tracking(1.1)

                Text(insight.title)
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(insight.body)
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                Text(insight.metric)
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(insight.accent)
                    .tracking(0.8)
            }

            Spacer(minLength: 0)
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct AnalyticsEmptyInsightCard: View {
    let title: String
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text(message)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct AnalyticsEmptyStateCard: View {
    let title: String
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text(message)
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        }
        .habitQuestSurface(.raised)
    }
}

private struct AnalyticsChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: Color
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityHint: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                Text(title)
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            }

            content
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }
}

private struct HabitPerformanceRow: View {
    let item: AnalyticsHabitPerformanceItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: HabitQuestDesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                    Text(item.habit.title)
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text(item.habit.category ?? "Uncategorized")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                }

                Spacer()

                Text("\(Int(item.completionRate.rounded()))%")
                    .font(HabitQuestDesignSystem.Typography.title2)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    .monospacedDigit()
            }

            ProgressView(value: item.completionRate / 100)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                AnalyticsPill(label: "Current streak", value: "\(item.currentStreak)")
                AnalyticsPill(label: "Longest", value: "\(item.longestStreak)")
                AnalyticsPill(label: "Total", value: "\(item.totalCompletions)")
            }
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct HabitDeferralRow: View {
    let item: AnalyticsHabitDeferralItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: HabitQuestDesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                Text(item.habit.title)
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(item.habit.dailyRhythm.displayTitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                Text("\(Int(item.deferralRate.rounded()))%")
                    .font(HabitQuestDesignSystem.Typography.title2)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.note(for: colorScheme))
                    .monospacedDigit()

                Text("moved later")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
            }
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct AnalyticsMiniCard: View {
    let title: String
    let value: String
    let subtitle: String
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text(title)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

            Text(value)
                .font(HabitQuestDesignSystem.Typography.title2)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .monospacedDigit()

            Text(subtitle)
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct PremiumAnalyticsWindowSummaryCard: View {
    let summary: HabitPremiumAnalyticsWindowSummary
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xxs) {
                    Text(summary.label)
                        .font(HabitQuestDesignSystem.Typography.headline)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                    Text(summary.preset == .allTime ? "Full local history" : "\(summary.rangeStart.formatted(date: .abbreviated, time: .omitted)) to \(summary.rangeEnd.formatted(date: .abbreviated, time: .omitted))")
                        .font(HabitQuestDesignSystem.Typography.caption)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                }

                Spacer()

                Text("\(Int(summary.consistencyScore.rounded()))")
                    .font(HabitQuestDesignSystem.Typography.title2)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    .monospacedDigit()
            }

            ProgressView(value: summary.consistencyScore / 100)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                AnalyticsPill(label: "Completion", value: "\(Int((summary.completionRate ?? 0).rounded()))%")
                AnalyticsPill(label: "Streak", value: "\(summary.currentDailyStreak)")
                AnalyticsPill(label: "Momentum", value: "\(Int(summary.currentMomentum.rounded()))")
            }
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct PremiumAnalyticsComparisonCard: View {
    let comparison: HabitPremiumAnalyticsComparison
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("30-day comparison")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Text("\(comparison.currentLabel) vs \(comparison.previousLabel)")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

            HStack(spacing: HabitQuestDesignSystem.Spacing.md) {
                AnalyticsPill(
                    label: "Completion",
                    value: comparison.completionRateDelta.map { formatDelta($0) } ?? "—"
                )
                AnalyticsPill(
                    label: "Momentum",
                    value: comparison.momentumDelta.map { formatDelta($0) } ?? "—"
                )
                AnalyticsPill(
                    label: "Consistency",
                    value: comparison.consistencyScoreDelta.map { formatDelta($0) } ?? "—"
                )
            }
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }

    private func formatDelta(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(Int(value.rounded()))"
    }
}

private struct PremiumAnalyticsInsightCard: View {
    let insight: HabitPremiumAnalyticsInsight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: HabitQuestDesignSystem.Spacing.md) {
            Circle()
                .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.24))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                )

            VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.xs) {
                Text("Premium insight")
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))
                    .tracking(1.1)

                Text(insight.title)
                    .font(HabitQuestDesignSystem.Typography.headline)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(insight.detail)
                    .font(HabitQuestDesignSystem.Typography.callout)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

                Text(insight.metric)
                    .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))
                    .tracking(0.8)
            }

            Spacer(minLength: 0)
        }
        .habitQuestSurface(.base, cornerRadius: HabitQuestDesignSystem.Radius.lg, padding: HabitQuestDesignSystem.Spacing.md)
    }
}

private struct AnalyticsPill: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textTertiary(for: colorScheme))

            Text(value)
                .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnalyticsRangeChip: View {
    let title: String
    let isSelected: Bool
    let isLocked: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
            Text(title)
            if isLocked {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
        .padding(.horizontal, HabitQuestDesignSystem.Spacing.md)
        .padding(.vertical, 9)
        .foregroundStyle(isSelected ? HabitQuestDesignSystem.Palette.accent(for: colorScheme) : HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
        .background(background)
    }

    @ViewBuilder
    private var background: some View {
        let shape = Capsule(style: .continuous)

        if isSelected {
            if #available(iOS 26.0, *) {
                shape
                    .fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme).opacity(0.35))
                    .glassEffect(.regular, in: shape)
            } else {
                shape.fill(HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme))
            }
        } else {
            shape
                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                .overlay(
                    shape.stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                )
        }
    }
}

private struct AnalyticsPreviewTrendView: View {
    let title: String
    let subtitle: String
    let accent: Color
    let values: [Double]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HabitQuestDesignSystem.Typography.callout.weight(.semibold))
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

                Text(subtitle)
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Point", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Point", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(accent.opacity(0.75))
                }
            }
            .frame(height: 100)
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .accessibilityHidden(true)
            .overlay(
                RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.lg, style: .continuous)
                    .stroke(HabitQuestDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
            )
        }
    }
}

private enum AnalyticsRange: CaseIterable {
    case week
    case month
    case ninetyDays
    case year

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .ninetyDays:
            return "90 Days"
        case .year:
            return "Year"
        }
    }

    var dayCount: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .ninetyDays:
            return 90
        case .year:
            return 365
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .week, .month:
            return false
        case .ninetyDays, .year:
            return true
        }
    }

    var feature: PremiumFeature {
        switch self {
        case .week, .month, .ninetyDays:
            return .advancedAnalytics
        case .year:
            return .longTermAnalytics
        }
    }

    var entryPoint: String {
        switch self {
        case .week:
            return "Weekly analytics range"
        case .month:
            return "Monthly analytics range"
        case .ninetyDays:
            return "90-day analytics range"
        case .year:
            return "Yearly analytics range"
        }
    }

    func range(endingAt date: Date, calendar: Calendar) -> ClosedRange<Date> {
        let end = calendar.startOfDay(for: date)
        let startOffset = -(dayCount - 1)
        let start = calendar.date(byAdding: .day, value: startOffset, to: end) ?? end
        return calendar.startOfDay(for: start)...end
    }
}

private extension MomentumTrend.Direction {
    var title: String {
        switch self {
        case .rising:
            return "Rising"
        case .steady:
            return "Steady"
        case .falling:
            return "Softening"
        }
    }

    func color(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .rising:
            return HabitQuestDesignSystem.Palette.success(for: colorScheme)
        case .steady:
            return HabitQuestDesignSystem.Palette.accent(for: colorScheme)
        case .falling:
            return HabitQuestDesignSystem.Palette.note(for: colorScheme)
        }
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

    func tint(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .morning:
            return HabitQuestDesignSystem.Palette.note(for: colorScheme)
        case .day:
            return HabitQuestDesignSystem.Palette.success(for: colorScheme)
        case .evening:
            return HabitQuestDesignSystem.Palette.accent(for: colorScheme)
        case .anytime:
            return HabitQuestDesignSystem.Palette.accentSoft(for: colorScheme)
        }
    }
}
