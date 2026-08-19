import Foundation

struct HabitAnalyticsReport: Equatable, Sendable {
    let rangeStart: Date
    let rangeEnd: Date
    let completionRate: Double?
    let totalCompletions: Int
    let dailyCompletionHistory: [HabitAnalyticsDaySummary]
    let weeklyConsistency: [HabitAnalyticsWeekSummary]
    let monthlyConsistency: [HabitAnalyticsMonthSummary]
    let momentumSummary: MomentumSummary
    let momentumHistory: [MomentumHistoryPoint]
    let individualHabitStreaks: [UUID: HabitProgressSummary]
    let completionRateByHabit: [UUID: Double]
    let strongestDaysOfWeek: [HabitAnalyticsWeekdaySummary]
    let completionBehaviorByDailyRhythm: [HabitAnalyticsRhythmSummary]
    let deferralFrequencyByHabit: [UUID: Double]
    let personalBests: HabitAnalyticsPersonalBests
}

struct HabitAnalyticsDaySummary: Equatable, Sendable {
    let date: Date
    let dueCount: Int
    let completedCount: Int
    let completionRate: Double?
}

struct HabitAnalyticsWeekSummary: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let dueCount: Int
    let completedCount: Int
    let completionRate: Double?
}

struct HabitAnalyticsMonthSummary: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let dueCount: Int
    let completedCount: Int
    let completionRate: Double?
}

struct HabitAnalyticsWeekdaySummary: Equatable, Sendable {
    let weekday: Weekday
    let dueCount: Int
    let completedCount: Int
    let completionRate: Double?
}

struct HabitAnalyticsRhythmSummary: Equatable, Sendable {
    let rhythm: HabitRhythm
    let dueCount: Int
    let completedCount: Int
    let completionRate: Double?
}

struct HabitAnalyticsPersonalBests: Equatable, Sendable {
    let bestDay: HabitAnalyticsDaySummary?
    let bestWeek: HabitAnalyticsWeekSummary?
    let bestMonth: HabitAnalyticsMonthSummary?
    let highestMomentum: Double
    let longestDailyStreak: Int
    let longestHabitStreak: Int
    let mostCompletionsInDay: Int
}

struct HabitAnalyticsCalculator {
    private let habitProgressCalculator = HabitProgressCalculator()
    private let momentumCalculator = HabitMomentumCalculator()

    func report(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyStates: [DailyHabitState] = [],
        in range: ClosedRange<Date>,
        calendar: Calendar = .current
    ) -> HabitAnalyticsReport {
        let normalizedRange = normalizedRange(range, calendar: calendar)
        let days = daySequence(in: normalizedRange, calendar: calendar)
        let completionLookup = completionLookupByDay(completionEvents, calendar: calendar)
        let deferralLookup = deferralLookupByHabit(dailyStates)

        let dailyHistory = days.map { day -> HabitAnalyticsDaySummary in
            dailySummary(
                for: day,
                habits: habits,
                completionLookup: completionLookup,
                calendar: calendar
            )
        }

        let weeklyConsistency = groupedSummary(
            from: dailyHistory,
            component: .weekOfYear,
            range: normalizedRange,
            calendar: calendar
        ).map {
            HabitAnalyticsWeekSummary(
                startDate: $0.startDate,
                endDate: $0.endDate,
                dueCount: $0.dueCount,
                completedCount: $0.completedCount,
                completionRate: $0.completionRate
            )
        }

        let monthlyConsistency = groupedSummary(
            from: dailyHistory,
            component: .month,
            range: normalizedRange,
            calendar: calendar
        ).map {
            HabitAnalyticsMonthSummary(
                startDate: $0.startDate,
                endDate: $0.endDate,
                dueCount: $0.dueCount,
                completedCount: $0.completedCount,
                completionRate: $0.completionRate
            )
        }

        let habitProgressSummaries = habitProgressCalculator.summaries(
            for: habits,
            completionEvents: completionEvents,
            upTo: normalizedRange.upperBound,
            calendar: calendar
        )

        var habitCompletionRates: [UUID: Double] = [:]
        for habit in habits {
            let summary = habitSummary(
                for: habit,
                days: days,
                completionLookup: completionLookup,
                calendar: calendar
            )

            if let rate = summary.completionRate {
                habitCompletionRates[habit.id] = rate
            }
        }

        let strongestDaysOfWeek = strongestDays(from: dailyHistory, calendar: calendar)
        let rhythmBehavior = rhythmBehavior(
            habits: habits,
            days: days,
            completionLookup: completionLookup,
            calendar: calendar
        )

        let momentumWindowDays = max(min(days.count, 30), 1)
        let momentumSummary = momentumCalculator.summary(
            for: habits,
            completionEvents: completionEvents,
            upTo: normalizedRange.upperBound,
            calendar: calendar,
            windowDays: momentumWindowDays
        )
        let momentumHistory = momentumSummary.recentHistory.filter {
            normalizedRange.contains($0.date) || calendar.isDate($0.date, inSameDayAs: normalizedRange.upperBound)
        }

        let totalCompletions = completionEvents.filter { normalizedRange.contains(calendar.startOfDay(for: $0.logicalCompletionDate)) }.count
        let completionRate = overallCompletionRate(from: dailyHistory)
        let bestDay = bestDay(from: dailyHistory)
        let bestWeek = bestWeek(from: weeklyConsistency)
        let bestMonth = bestMonth(from: monthlyConsistency)
        let highestMomentum = momentumHistory.map(\.value).compactMap { $0 }.max() ?? 0
        let longestHabitStreak = habitProgressSummaries.values.map(\.longestStreak).max() ?? 0
        let mostCompletionsInDay = dailyHistory.map(\.completedCount).max() ?? 0

        let deferralFrequencyByHabit = deferralLookup.reduce(into: [UUID: Double]()) { partialResult, entry in
            guard entry.value.stateCount > 0 else {
                return
            }

            partialResult[entry.key] = (Double(entry.value.totalDeferrals) / Double(entry.value.stateCount)) * 100
        }

        return HabitAnalyticsReport(
            rangeStart: normalizedRange.lowerBound,
            rangeEnd: normalizedRange.upperBound,
            completionRate: completionRate,
            totalCompletions: totalCompletions,
            dailyCompletionHistory: dailyHistory,
            weeklyConsistency: weeklyConsistency,
            monthlyConsistency: monthlyConsistency,
            momentumSummary: momentumSummary,
            momentumHistory: momentumHistory,
            individualHabitStreaks: habitProgressSummaries,
            completionRateByHabit: habitCompletionRates,
            strongestDaysOfWeek: strongestDaysOfWeek,
            completionBehaviorByDailyRhythm: rhythmBehavior,
            deferralFrequencyByHabit: deferralFrequencyByHabit,
            personalBests: HabitAnalyticsPersonalBests(
                bestDay: bestDay,
                bestWeek: bestWeek,
                bestMonth: bestMonth,
                highestMomentum: highestMomentum,
                longestDailyStreak: longestCompletedRun(in: dailyHistory),
                longestHabitStreak: longestHabitStreak,
                mostCompletionsInDay: mostCompletionsInDay
            )
        )
    }

    private func normalizedRange(_ range: ClosedRange<Date>, calendar: Calendar) -> ClosedRange<Date> {
        let lower = calendar.startOfDay(for: min(range.lowerBound, range.upperBound))
        let upper = calendar.startOfDay(for: max(range.lowerBound, range.upperBound))
        return lower...upper
    }

    private func daySequence(in range: ClosedRange<Date>, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var cursor = range.lowerBound

        while cursor <= range.upperBound {
            days.append(cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = calendar.startOfDay(for: nextDay)
        }

        return days
    }

    private func completionLookupByDay(_ completionEvents: [CompletionEvent], calendar: Calendar) -> [Date: Set<UUID>] {
        Dictionary(grouping: completionEvents) { calendar.startOfDay(for: $0.logicalCompletionDate) }
            .mapValues { Set($0.map(\.habitID)) }
    }

    private func deferralLookupByHabit(_ states: [DailyHabitState]) -> [UUID: (totalDeferrals: Int, stateCount: Int)] {
        var lookup: [UUID: (totalDeferrals: Int, stateCount: Int)] = [:]

        for state in states {
            var entry = lookup[state.habitID] ?? (0, 0)
            entry.stateCount += 1
            entry.totalDeferrals += state.deferCount
            lookup[state.habitID] = entry
        }

        return lookup
    }

    private func dailySummary(
        for day: Date,
        habits: [Habit],
        completionLookup: [Date: Set<UUID>],
        calendar: Calendar
    ) -> HabitAnalyticsDaySummary {
        let dueHabits = habits.filter { $0.isActive(on: day, calendar: calendar) }
        let completedIDs = completionLookup[day] ?? []
        let completedCount = dueHabits.filter { completedIDs.contains($0.id) }.count
        let dueCount = dueHabits.count

        return HabitAnalyticsDaySummary(
            date: day,
            dueCount: dueCount,
            completedCount: completedCount,
            completionRate: completionRate(completedCount: completedCount, dueCount: dueCount)
        )
    }

    private func habitSummary(
        for habit: Habit,
        days: [Date],
        completionLookup: [Date: Set<UUID>],
        calendar: Calendar
    ) -> HabitAnalyticsDaySummary {
        let filteredDays = days.filter { habit.isActive(on: $0, calendar: calendar) }
        let completedCount = filteredDays.filter { completionLookup[$0]?.contains(habit.id) == true }.count

        return HabitAnalyticsDaySummary(
            date: calendar.startOfDay(for: habit.createdAt),
            dueCount: filteredDays.count,
            completedCount: completedCount,
            completionRate: completionRate(completedCount: completedCount, dueCount: filteredDays.count)
        )
    }

    private func groupedSummary(
        from dailyHistory: [HabitAnalyticsDaySummary],
        component: Calendar.Component,
        range: ClosedRange<Date>,
        calendar: Calendar
    ) -> [HabitAnalyticsBucketSummary] {
        let grouped = Dictionary(grouping: dailyHistory) { day -> Date in
            calendar.dateInterval(of: component, for: day.date)?.start ?? calendar.startOfDay(for: day.date)
        }

        return grouped.keys.sorted().compactMap { bucketStart in
            guard let days = grouped[bucketStart], !days.isEmpty else {
                return nil
            }

            let dueCount = days.reduce(0) { $0 + $1.dueCount }
            let completedCount = days.reduce(0) { $0 + $1.completedCount }
            let endDate = min((calendar.dateInterval(of: component, for: bucketStart)?.end ?? bucketStart).addingTimeInterval(-1), range.upperBound)

            return HabitAnalyticsBucketSummary(
                startDate: bucketStart,
                endDate: endDate,
                dueCount: dueCount,
                completedCount: completedCount,
                completionRate: completionRate(completedCount: completedCount, dueCount: dueCount)
            )
        }
    }

    private func strongestDays(from dailyHistory: [HabitAnalyticsDaySummary], calendar: Calendar) -> [HabitAnalyticsWeekdaySummary] {
        let grouped = Dictionary(grouping: dailyHistory) { calendar.component(.weekday, from: $0.date) }

        return Weekday.allCases.compactMap { weekday in
            guard let days = grouped[weekday.rawValue], !days.isEmpty else {
                return HabitAnalyticsWeekdaySummary(weekday: weekday, dueCount: 0, completedCount: 0, completionRate: nil)
            }

            let dueCount = days.reduce(0) { $0 + $1.dueCount }
            let completedCount = days.reduce(0) { $0 + $1.completedCount }

            return HabitAnalyticsWeekdaySummary(
                weekday: weekday,
                dueCount: dueCount,
                completedCount: completedCount,
                completionRate: completionRate(completedCount: completedCount, dueCount: dueCount)
            )
        }
        .sorted {
            let lhsRate = $0.completionRate ?? -1
            let rhsRate = $1.completionRate ?? -1
            if lhsRate == rhsRate {
                if $0.completedCount == $1.completedCount {
                    return $0.weekday.rawValue < $1.weekday.rawValue
                }

                return $0.completedCount > $1.completedCount
            }

            return lhsRate > rhsRate
        }
    }

    private func rhythmBehavior(
        habits: [Habit],
        days: [Date],
        completionLookup: [Date: Set<UUID>],
        calendar: Calendar
    ) -> [HabitAnalyticsRhythmSummary] {
        let groupedHabits = Dictionary(grouping: habits) { $0.dailyRhythm }

        return HabitRhythm.allCases.map { rhythm in
            let rhythmHabits = groupedHabits[rhythm] ?? []
            let dueCount = days.reduce(0) { partialResult, day in
                partialResult + rhythmHabits.filter { $0.isActive(on: day, calendar: calendar) }.count
            }

            let completedCount = days.reduce(0) { partialResult, day in
                let completedIDs = completionLookup[day] ?? []
                return partialResult + rhythmHabits.filter { $0.isActive(on: day, calendar: calendar) && completedIDs.contains($0.id) }.count
            }

            return HabitAnalyticsRhythmSummary(
                rhythm: rhythm,
                dueCount: dueCount,
                completedCount: completedCount,
                completionRate: completionRate(completedCount: completedCount, dueCount: dueCount)
            )
        }
    }

    private func bestDay(from dailyHistory: [HabitAnalyticsDaySummary]) -> HabitAnalyticsDaySummary? {
        dailyHistory.max {
            if $0.completionRate == $1.completionRate {
                if $0.completedCount == $1.completedCount {
                    return $0.date > $1.date
                }

                return $0.completedCount < $1.completedCount
            }

            return ($0.completionRate ?? -1) < ($1.completionRate ?? -1)
        }
    }

    private func bestWeek(from weeklyConsistency: [HabitAnalyticsWeekSummary]) -> HabitAnalyticsWeekSummary? {
        weeklyConsistency.max {
            if $0.completionRate == $1.completionRate {
                if $0.completedCount == $1.completedCount {
                    return $0.startDate > $1.startDate
                }

                return $0.completedCount < $1.completedCount
            }

            return ($0.completionRate ?? -1) < ($1.completionRate ?? -1)
        }
    }

    private func bestMonth(from monthlyConsistency: [HabitAnalyticsMonthSummary]) -> HabitAnalyticsMonthSummary? {
        monthlyConsistency.max {
            if $0.completionRate == $1.completionRate {
                if $0.completedCount == $1.completedCount {
                    return $0.startDate > $1.startDate
                }

                return $0.completedCount < $1.completedCount
            }

            return ($0.completionRate ?? -1) < ($1.completionRate ?? -1)
        }
    }

    private func overallCompletionRate(from dailyHistory: [HabitAnalyticsDaySummary]) -> Double? {
        let dueCount = dailyHistory.reduce(0) { $0 + $1.dueCount }
        let completedCount = dailyHistory.reduce(0) { $0 + $1.completedCount }
        return completionRate(completedCount: completedCount, dueCount: dueCount)
    }

    private func longestCompletedRun(in dailyHistory: [HabitAnalyticsDaySummary]) -> Int {
        var longest = 0
        var current = 0

        for day in dailyHistory {
            guard day.dueCount > 0 else {
                continue
            }

            if day.completedCount == day.dueCount {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    private func completionRate(completedCount: Int, dueCount: Int) -> Double? {
        guard dueCount > 0 else {
            return nil
        }

        return (Double(completedCount) / Double(dueCount)) * 100
    }
}

enum HabitAnalyticsWindowPreset: String, Codable, CaseIterable, Hashable, Sendable {
    case thirtyDays
    case ninetyDays
    case year
    case allTime

    var label: String {
        switch self {
        case .thirtyDays:
            return "30 days"
        case .ninetyDays:
            return "90 days"
        case .year:
            return "1 year"
        case .allTime:
            return "All time"
        }
    }

    var dayCount: Int? {
        switch self {
        case .thirtyDays:
            return 30
        case .ninetyDays:
            return 90
        case .year:
            return 365
        case .allTime:
            return nil
        }
    }
}

struct HabitPremiumAnalyticsTrendPoint: Equatable, Sendable {
    let date: Date
    let label: String
    let value: Double
}

struct HabitPremiumAnalyticsWindowSummary: Equatable, Sendable {
    let preset: HabitAnalyticsWindowPreset
    let label: String
    let rangeStart: Date
    let rangeEnd: Date
    let dueCount: Int
    let completedCount: Int
    let completionRate: Double?
    let currentDailyStreak: Int
    let longestDailyStreak: Int
    let currentMomentum: Double
    let previousMomentum: Double
    let strongestWeekday: Weekday?
    let weakestWeekday: Weekday?
    let consistencyScore: Double
}

struct HabitPremiumAnalyticsComparison: Equatable, Sendable {
    let currentLabel: String
    let previousLabel: String
    let completionRateDelta: Double?
    let momentumDelta: Double?
    let consistencyScoreDelta: Double?
    let dueCountDelta: Int
    let completedCountDelta: Int
}

struct HabitPremiumAnalyticsHabitTrend: Equatable, Sendable {
    let habitID: UUID
    let title: String
    let currentCompletionRate: Double?
    let previousCompletionRate: Double?
    let completionRateDelta: Double?
    let currentStreak: Int
    let longestStreak: Int
    let deferralFrequency: Double
}

struct HabitPremiumAnalyticsDeferralPattern: Equatable, Sendable {
    let habitID: UUID
    let title: String
    let totalDeferrals: Int
    let deferralFrequency: Double
}

struct HabitPremiumAnalyticsInsight: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let metric: String
}

struct HabitPremiumAnalyticsReport: Equatable, Sendable {
    let windowSummaries: [HabitPremiumAnalyticsWindowSummary]
    let comparison: HabitPremiumAnalyticsComparison?
    let completionRateTrend: [HabitPremiumAnalyticsTrendPoint]
    let momentumTrend: [HabitPremiumAnalyticsTrendPoint]
    let strongestDaysOfWeek: [HabitAnalyticsWeekdaySummary]
    let weakestDaysOfWeek: [HabitAnalyticsWeekdaySummary]
    let routinePerformance: [HabitAnalyticsRhythmSummary]
    let habitTrends: [HabitPremiumAnalyticsHabitTrend]
    let deferralPatterns: [HabitPremiumAnalyticsDeferralPattern]
    let insights: [HabitPremiumAnalyticsInsight]
}

struct HabitPremiumAnalyticsCalculator {
    private let baseCalculator = HabitAnalyticsCalculator()
    private let habitProgressCalculator = HabitProgressCalculator()
    private let momentumCalculator = HabitMomentumCalculator()
    private let dailyStreakCalculator = DailyStreakCalculator()

    func report(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyStates: [DailyHabitState] = [],
        in range: ClosedRange<Date>,
        calendar: Calendar = .current
    ) -> HabitPremiumAnalyticsReport {
        let anchor = calendar.startOfDay(for: range.upperBound)
        let selectedReport = baseCalculator.report(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            in: range,
            calendar: calendar
        )

        let allTimeStart = earliestRelevantDay(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            fallback: anchor,
            calendar: calendar
        )

        let allTimeRange = allTimeStart...anchor
        let allTimeReport = baseCalculator.report(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            in: allTimeRange,
            calendar: calendar
        )

        let previousThirtyRange = previousRange(
            days: 30,
            endingAt: range.lowerBound,
            calendar: calendar
        )
        let previousThirtyReport = baseCalculator.report(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            in: previousThirtyRange,
            calendar: calendar
        )

        let windowReports: [(preset: HabitAnalyticsWindowPreset, report: HabitAnalyticsReport)] = [
            (.thirtyDays, baseCalculator.report(
                for: habits,
                completionEvents: completionEvents,
                dailyStates: dailyStates,
                in: analyticsRange(days: 30, endingAt: anchor, calendar: calendar),
                calendar: calendar
            )),
            (.ninetyDays, baseCalculator.report(
                for: habits,
                completionEvents: completionEvents,
                dailyStates: dailyStates,
                in: analyticsRange(days: 90, endingAt: anchor, calendar: calendar),
                calendar: calendar
            )),
            (.year, baseCalculator.report(
                for: habits,
                completionEvents: completionEvents,
                dailyStates: dailyStates,
                in: analyticsRange(days: 365, endingAt: anchor, calendar: calendar),
                calendar: calendar
            )),
            (.allTime, allTimeReport)
        ]

        let windowSummaries = windowReports.map { preset, report in
            windowSummary(
                preset: preset,
                report: report,
                anchor: anchor,
                calendar: calendar,
                habits: habits,
                completionEvents: completionEvents,
                dailyStates: dailyStates
            )
        }

        let comparison = comparisonSummary(
            currentReport: windowReports.first(where: { $0.preset == .thirtyDays })?.report ?? selectedReport,
            previousReport: previousThirtyReport
        )

        let strongestDaysOfWeek = windowReports.first(where: { $0.preset == .ninetyDays })?.report.strongestDaysOfWeek ?? selectedReport.strongestDaysOfWeek
        let weakestDaysOfWeek = weakestDays(from: strongestDaysOfWeek)
        let routinePerformance = windowReports.first(where: { $0.preset == .ninetyDays })?.report.completionBehaviorByDailyRhythm ?? selectedReport.completionBehaviorByDailyRhythm
        let habitTrends = habitTrends(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            anchor: anchor,
            calendar: calendar
        )
        let deferralPatterns = deferralPatterns(
            for: habits,
            dailyStates: dailyStates
        )
        let completionRateTrend = windowSummaries.map {
            HabitPremiumAnalyticsTrendPoint(
                date: $0.rangeEnd,
                label: $0.label,
                value: $0.completionRate ?? 0
            )
        }
        let momentumTrend = windowSummaries.map {
            HabitPremiumAnalyticsTrendPoint(
                date: $0.rangeEnd,
                label: $0.label,
                value: $0.currentMomentum
            )
        }
        let insights = insights(
            windowSummaries: windowSummaries,
            comparison: comparison,
            routinePerformance: routinePerformance,
            habitTrends: habitTrends,
            deferralPatterns: deferralPatterns
        )

        return HabitPremiumAnalyticsReport(
            windowSummaries: windowSummaries,
            comparison: comparison,
            completionRateTrend: completionRateTrend,
            momentumTrend: momentumTrend,
            strongestDaysOfWeek: strongestDaysOfWeek,
            weakestDaysOfWeek: weakestDaysOfWeek,
            routinePerformance: routinePerformance,
            habitTrends: habitTrends,
            deferralPatterns: deferralPatterns,
            insights: insights
        )
    }

    private func analyticsRange(days: Int, endingAt anchor: Date, calendar: Calendar) -> ClosedRange<Date> {
        let end = calendar.startOfDay(for: anchor)
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: end) ?? end
        return calendar.startOfDay(for: start)...end
    }

    private func previousRange(days: Int, endingAt start: Date, calendar: Calendar) -> ClosedRange<Date> {
        let end = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: start)) ?? calendar.startOfDay(for: start)
        let beginning = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: end) ?? end
        return calendar.startOfDay(for: beginning)...calendar.startOfDay(for: end)
    }

    private func earliestRelevantDay(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyStates: [DailyHabitState],
        fallback: Date,
        calendar: Calendar
    ) -> Date {
        let candidates = habits.map(\.createdAt)
            + completionEvents.map(\.logicalCompletionDate)
            + dailyStates.map(\.date)

        guard let earliest = candidates.min() else {
            return fallback
        }

        return min(calendar.startOfDay(for: earliest), fallback)
    }

    private func windowSummary(
        preset: HabitAnalyticsWindowPreset,
        report: HabitAnalyticsReport,
        anchor: Date,
        calendar: Calendar,
        habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyStates: [DailyHabitState]
    ) -> HabitPremiumAnalyticsWindowSummary {
        let streak = dailyStreakCalculator.summary(
            for: habits,
            states: dailyStates,
            completionEvents: completionEvents,
            upTo: report.rangeEnd,
            calendar: calendar
        )

        let consistencyScore = consistencyScore(
            completionRate: report.completionRate,
            currentMomentum: report.momentumSummary.currentMomentum,
            currentStreak: streak.currentDailyStreak,
            longestStreak: streak.longestDailyStreak
        )

        return HabitPremiumAnalyticsWindowSummary(
            preset: preset,
            label: preset.label,
            rangeStart: report.rangeStart,
            rangeEnd: report.rangeEnd,
            dueCount: report.dailyCompletionHistory.reduce(0) { $0 + $1.dueCount },
            completedCount: report.totalCompletions,
            completionRate: report.completionRate,
            currentDailyStreak: streak.currentDailyStreak,
            longestDailyStreak: streak.longestDailyStreak,
            currentMomentum: report.momentumSummary.currentMomentum,
            previousMomentum: report.momentumSummary.previousMomentum,
            strongestWeekday: report.strongestDaysOfWeek.first?.weekday,
            weakestWeekday: report.strongestDaysOfWeek.last?.weekday,
            consistencyScore: consistencyScore
        )
    }

    /// Consistency score is intentionally simple:
    /// completion rate matters most, then recent momentum, then the shape of the current streak.
    /// The result stays in 0...100 so it is easy to compare across windows.
    private func consistencyScore(
        completionRate: Double?,
        currentMomentum: Double,
        currentStreak: Int,
        longestStreak: Int
    ) -> Double {
        let completionComponent = completionRate ?? 0
        let momentumComponent = currentMomentum
        let streakBaseline = max(longestStreak, 1)
        let streakComponent = min(Double(currentStreak) / Double(streakBaseline), 1) * 100
        let weighted = (completionComponent * 0.55) + (momentumComponent * 0.3) + (streakComponent * 0.15)
        return min(max(weighted, 0), 100)
    }

    private func comparisonSummary(
        currentReport: HabitAnalyticsReport,
        previousReport: HabitAnalyticsReport
    ) -> HabitPremiumAnalyticsComparison? {
        guard currentReport.dailyCompletionHistory.count > 0 || previousReport.dailyCompletionHistory.count > 0 else {
            return nil
        }

        return HabitPremiumAnalyticsComparison(
            currentLabel: "Current 30 days",
            previousLabel: "Previous 30 days",
            completionRateDelta: delta(currentReport.completionRate, previousReport.completionRate),
            momentumDelta: delta(currentReport.momentumSummary.currentMomentum, previousReport.momentumSummary.currentMomentum),
            consistencyScoreDelta: delta(
                consistencyScore(for: currentReport),
                consistencyScore(for: previousReport)
            ),
            dueCountDelta: currentReport.dailyCompletionHistory.reduce(0) { $0 + $1.dueCount } - previousReport.dailyCompletionHistory.reduce(0) { $0 + $1.dueCount },
            completedCountDelta: currentReport.totalCompletions - previousReport.totalCompletions
        )
    }

    private func consistencyScore(for report: HabitAnalyticsReport) -> Double {
        let streak = report.personalBests.longestDailyStreak
        let streakComponent = min(Double(streak) / 30.0, 1) * 100
        let completionComponent = report.completionRate ?? 0
        let momentumComponent = report.momentumSummary.currentMomentum
        return min(max((completionComponent * 0.55) + (momentumComponent * 0.3) + (streakComponent * 0.15), 0), 100)
    }

    private func delta(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs else {
            return nil
        }
        return lhs - rhs
    }

    private func delta(_ lhs: Double, _ rhs: Double) -> Double {
        lhs - rhs
    }

    private func weakestDays(from strongestDays: [HabitAnalyticsWeekdaySummary]) -> [HabitAnalyticsWeekdaySummary] {
        strongestDays.sorted { lhs, rhs in
            let lhsRate = lhs.completionRate ?? -1
            let rhsRate = rhs.completionRate ?? -1
            if lhsRate == rhsRate {
                if lhs.completedCount == rhs.completedCount {
                    return lhs.weekday.rawValue < rhs.weekday.rawValue
                }
                return lhs.completedCount < rhs.completedCount
            }
            return lhsRate < rhsRate
        }
    }

    private func habitTrends(
        for habits: [Habit],
        completionEvents: [CompletionEvent],
        dailyStates: [DailyHabitState],
        anchor: Date,
        calendar: Calendar
    ) -> [HabitPremiumAnalyticsHabitTrend] {
        let currentRange = analyticsRange(days: 30, endingAt: anchor, calendar: calendar)
        let previousRange = previousRange(days: 30, endingAt: currentRange.lowerBound, calendar: calendar)

        let currentReport = baseCalculator.report(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            in: currentRange,
            calendar: calendar
        )
        let previousReport = baseCalculator.report(
            for: habits,
            completionEvents: completionEvents,
            dailyStates: dailyStates,
            in: previousRange,
            calendar: calendar
        )

        let progress = habitProgressCalculator.summaries(
            for: habits,
            completionEvents: completionEvents,
            upTo: anchor,
            calendar: calendar
        )
        let deferralLookup = deferralLookupByHabit(dailyStates)

        return habits.map { habit in
            let currentCompletionRate = currentReport.completionRateByHabit[habit.id]
            let previousCompletionRate = previousReport.completionRateByHabit[habit.id]
            let deferralFrequency = deferralFrequency(for: habit.id, from: deferralLookup)
            let summary = progress[habit.id]

            return HabitPremiumAnalyticsHabitTrend(
                habitID: habit.id,
                title: habit.title,
                currentCompletionRate: currentCompletionRate,
                previousCompletionRate: previousCompletionRate,
                completionRateDelta: delta(currentCompletionRate, previousCompletionRate),
                currentStreak: summary?.currentStreak ?? 0,
                longestStreak: summary?.longestStreak ?? 0,
                deferralFrequency: deferralFrequency
            )
        }
        .sorted {
            let lhsDelta = $0.completionRateDelta ?? -Double.greatestFiniteMagnitude
            let rhsDelta = $1.completionRateDelta ?? -Double.greatestFiniteMagnitude
            if lhsDelta == rhsDelta {
                if $0.longestStreak == $1.longestStreak {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.longestStreak > $1.longestStreak
            }
            return lhsDelta > rhsDelta
        }
    }

    private func deferralPatterns(
        for habits: [Habit],
        dailyStates: [DailyHabitState]
    ) -> [HabitPremiumAnalyticsDeferralPattern] {
        let lookup = deferralLookupByHabit(dailyStates)

        return habits.compactMap { habit in
            guard let entry = lookup[habit.id], entry.stateCount > 0 else {
                return nil
            }

            return HabitPremiumAnalyticsDeferralPattern(
                habitID: habit.id,
                title: habit.title,
                totalDeferrals: entry.totalDeferrals,
                deferralFrequency: (Double(entry.totalDeferrals) / Double(entry.stateCount)) * 100
            )
        }
        .sorted {
            if $0.totalDeferrals == $1.totalDeferrals {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.totalDeferrals > $1.totalDeferrals
        }
    }

    private func deferralFrequency(
        for habitID: UUID,
        from lookup: [UUID: (totalDeferrals: Int, stateCount: Int)]
    ) -> Double {
        guard let entry = lookup[habitID], entry.stateCount > 0 else {
            return 0
        }

        return (Double(entry.totalDeferrals) / Double(entry.stateCount)) * 100
    }

    private func insights(
        windowSummaries: [HabitPremiumAnalyticsWindowSummary],
        comparison: HabitPremiumAnalyticsComparison?,
        routinePerformance: [HabitAnalyticsRhythmSummary],
        habitTrends: [HabitPremiumAnalyticsHabitTrend],
        deferralPatterns: [HabitPremiumAnalyticsDeferralPattern]
    ) -> [HabitPremiumAnalyticsInsight] {
        var insights: [HabitPremiumAnalyticsInsight] = []

        if let bestRoutine = routinePerformance.max(by: compareByCompletionRateThenCount) {
            let bestLabel = rhythmDisplayTitle(for: bestRoutine.rhythm)
            let title = "\(bestLabel) routine leads"
            let body = "Your \(bestLabel) routine has been your most consistent section over the last 90 days."
            let metric = "\(Int(bestRoutine.completionRate?.rounded() ?? 0))% completion"
            insights.append(HabitPremiumAnalyticsInsight(id: "bestRoutine", title: title, detail: body, metric: metric))
        }

        if let weakestRoutine = routinePerformance.min(by: compareByCompletionRateThenCount) {
            let weakestLabel = rhythmDisplayTitle(for: weakestRoutine.rhythm)
            let title = "\(weakestLabel) needs more support"
            let body = "Your \(weakestLabel) habits have been harder to complete recently."
            let metric = "\(Int(weakestRoutine.completionRate?.rounded() ?? 0))% completion"
            insights.append(HabitPremiumAnalyticsInsight(id: "weakestRoutine", title: title, detail: body, metric: metric))
        }

        if let comparison,
            let delta = comparison.completionRateDelta {
            let direction = delta >= 0 ? "up" : "down"
            let title = "30-day completion trend"
            let body = "Your current 30-day completion rate is \(direction) by \(formatPercentage(abs(delta))) compared with the previous 30 days."
            let metric = delta >= 0 ? "+\(formatPercentage(abs(delta)))" : "-\(formatPercentage(abs(delta)))"
            insights.append(HabitPremiumAnalyticsInsight(id: "completionTrend", title: title, detail: body, metric: metric))
        }

        if let topHabit = habitTrends.first {
            let title = "\(topHabit.title) is your clearest habit trend"
            let body = topHabit.completionRateDelta ?? 0 >= 0
                ? "This habit is holding steadier than it was in the previous 30 days."
                : "This habit is trailing its previous 30-day pattern a little."
            let metric = "\(formatPercentage(topHabit.currentCompletionRate ?? 0)) current"
            insights.append(HabitPremiumAnalyticsInsight(id: "topHabitTrend", title: title, detail: body, metric: metric))
        }

        if let deferredHabit = deferralPatterns.first {
            let title = "\(deferredHabit.title) is deferred most often"
            let body = "This habit may benefit from a softer setup or a different reminder window."
            let metric = "\(Int(deferredHabit.deferralFrequency.rounded()))% deferral rate"
            insights.append(HabitPremiumAnalyticsInsight(id: "topDeferral", title: title, detail: body, metric: metric))
        }

        if let allTime = windowSummaries.last {
            let title = "All-time consistency"
            let body = "Across your full local history, HabitQuest is reading a \(allTime.label.lowercased()) pattern of behavior."
            let metric = "\(Int(allTime.consistencyScore.rounded())) / 100"
            insights.append(HabitPremiumAnalyticsInsight(id: "allTimeConsistency", title: title, detail: body, metric: metric))
        }

        return Array(insights.prefix(4))
    }

    private func compareByCompletionRateThenCount(
        _ lhs: HabitAnalyticsRhythmSummary,
        _ rhs: HabitAnalyticsRhythmSummary
    ) -> Bool {
        let lhsRate = lhs.completionRate ?? -1
        let rhsRate = rhs.completionRate ?? -1
        if lhsRate == rhsRate {
            return lhs.completedCount > rhs.completedCount
        }
        return lhsRate > rhsRate
    }

    private func formatPercentage(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func deferralLookupByHabit(_ states: [DailyHabitState]) -> [UUID: (totalDeferrals: Int, stateCount: Int)] {
        var lookup: [UUID: (totalDeferrals: Int, stateCount: Int)] = [:]

        for state in states {
            var entry = lookup[state.habitID] ?? (0, 0)
            entry.stateCount += 1
            entry.totalDeferrals += state.deferCount
            lookup[state.habitID] = entry
        }

        return lookup
    }

    private func rhythmDisplayTitle(for rhythm: HabitRhythm) -> String {
        switch rhythm {
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

private struct HabitAnalyticsBucketSummary: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let dueCount: Int
    let completedCount: Int
    let completionRate: Double?
}
