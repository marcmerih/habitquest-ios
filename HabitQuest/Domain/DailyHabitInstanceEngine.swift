import Foundation

struct DailyHabitInstanceSnapshot: Equatable, Sendable {
    let date: Date
    let states: [DailyHabitState]

    var actionableStates: [DailyHabitState] {
        states.filter(\.isActionable)
    }

    var waitingDeferredStates: [DailyHabitState] {
        states.filter { $0.status == .deferred }
    }
}

struct DailyHabitInstanceEngine {
    private let deferInterval: TimeInterval = 5 * 60
    private let orderingEngine: TodayDeckOrderingEngine
    private let rhythmConfiguration: DailyRhythmConfiguration

    init(rhythmConfiguration: DailyRhythmConfiguration = .default) {
        self.orderingEngine = TodayDeckOrderingEngine(rhythmConfiguration: rhythmConfiguration)
        self.rhythmConfiguration = rhythmConfiguration
    }

    func generateSnapshot(
        for habits: [Habit],
        persistedStates: [DailyHabitState],
        daySectionsByID: [UUID: HabitDaySection] = [:],
        on date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DailyHabitInstanceSnapshot {
        let day = calendar.startOfDay(for: date)
        let reconciledStates = reconcileHistoricalStates(persistedStates, currentDate: day, calendar: calendar)
        let todaysStatesByHabitID = Dictionary(
            uniqueKeysWithValues: reconciledStates
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .map { ($0.habitID, $0) }
        )

        let todaysStates = habits
            .filter { $0.isActive(on: day, calendar: calendar) }
            .compactMap { habit in
                materializeState(
                    for: habit,
                    existingState: todaysStatesByHabitID[habit.id],
                    on: day,
                    now: now,
                    calendar: calendar
                )
            }

        let passAwareStates = advanceEligibleDeferredStates(
            todaysStates,
            habits: habits,
            on: now,
            calendar: calendar
        )

        let orderedStates = orderingEngine.orderedStates(
            passAwareStates,
            habits: habits,
            daySectionsByID: daySectionsByID,
            on: now,
            calendar: calendar
        )

        return DailyHabitInstanceSnapshot(date: day, states: orderedStates)
    }

    func reconcileHistoricalStates(
        _ states: [DailyHabitState],
        currentDate: Date,
        calendar: Calendar = .current
    ) -> [DailyHabitState] {
        let today = calendar.startOfDay(for: currentDate)

        return states.map { state in
            let stateDay = calendar.startOfDay(for: state.date)
            guard stateDay < today else {
                return state
            }

            guard state.status == .pending || state.status == .deferred else {
                return state
            }

            var updated = state
            updated.status = .expired
            updated.nextEligibleAt = nil
            return updated
        }
    }

    func deferState(
        _ state: DailyHabitState,
        habit: Habit,
        remainingActionableHabits: Int,
        at date: Date,
        calendar: Calendar = .current
    ) -> DailyHabitState {
        var updated = state
        updated.status = .deferred
        updated.deferCount += 1
        updated.lastDeferredAt = date
        updated.nextEligibleAt = nextEligibilityDate(
            for: habit,
            deferCount: updated.deferCount,
            remainingActionableHabits: remainingActionableHabits,
            after: date,
            calendar: calendar
        )
        updated.currentPass = max(updated.currentPass + 1, 1)
        return updated
    }

    func complete(_ state: DailyHabitState, at date: Date) -> DailyHabitState {
        var updated = state
        updated.status = .completed
        updated.completedAt = date
        updated.nextEligibleAt = nil
        return updated
    }

    func skip(_ state: DailyHabitState, at date: Date) -> DailyHabitState {
        var updated = state
        updated.status = .skipped
        updated.completedAt = nil
        updated.lastDeferredAt = nil
        updated.nextEligibleAt = nil
        return updated
    }

    func expire(_ state: DailyHabitState, at date: Date) -> DailyHabitState {
        var updated = state
        updated.status = .expired
        updated.completedAt = nil
        updated.lastDeferredAt = nil
        updated.nextEligibleAt = nil
        return updated
    }

    private func materializeState(
        for habit: Habit,
        existingState: DailyHabitState?,
        on date: Date,
        now: Date,
        calendar: Calendar
    ) -> DailyHabitState {
        let stateDate = calendar.startOfDay(for: date)
        let isTimeWindowExpired = expiredTimeWindow(for: habit, on: now, calendar: calendar)

        var state = existingState ?? DailyHabitState(habitID: habit.id, date: stateDate)
        state.date = stateDate
        state.deckPriority = deckPriority(for: habit)

        guard let existingState else {
            state.status = isTimeWindowExpired ? .expired : .pending
            state.deferCount = 0
            state.lastDeferredAt = nil
            state.completedAt = nil
            state.currentPass = 1
            state.nextEligibleAt = isTimeWindowExpired ? nil : nextEligibilityDate(
                for: habit,
                deferCount: 0,
                remainingActionableHabits: 0,
                after: now,
                calendar: calendar
            )
            return state
        }

        state.deferCount = existingState.deferCount
        state.lastDeferredAt = existingState.lastDeferredAt
        state.completedAt = existingState.completedAt
        state.currentPass = max(existingState.currentPass, 1)

        switch existingState.status {
        case .completed, .expired, .skipped:
            state.status = existingState.status
            state.nextEligibleAt = existingState.nextEligibleAt
        case .deferred:
            if isTimeWindowExpired {
                state.status = .expired
                state.completedAt = nil
                state.lastDeferredAt = nil
                state.nextEligibleAt = nil
            } else {
                state.status = .deferred
                state.nextEligibleAt = existingState.nextEligibleAt ?? nextEligibilityDate(
                    for: habit,
                    deferCount: existingState.deferCount,
                    remainingActionableHabits: 0,
                    after: now,
                    calendar: calendar
                )
            }
        case .pending:
            state.status = isTimeWindowExpired ? .expired : .pending
            state.nextEligibleAt = isTimeWindowExpired ? nil : nextEligibilityDate(
                for: habit,
                deferCount: existingState.deferCount,
                remainingActionableHabits: 0,
                after: now,
                calendar: calendar
            )
        }

        if state.status == .completed || state.status == .expired || state.status == .skipped {
            state.nextEligibleAt = nil
        }

        return state
    }

    private func advanceEligibleDeferredStates(
        _ states: [DailyHabitState],
        habits: [Habit],
        on now: Date,
        calendar: Calendar
    ) -> [DailyHabitState] {
        guard !states.contains(where: { $0.status == .pending }) else {
            return states
        }

        let habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        let activeHabitCount = states.filter { $0.status == .pending || $0.status == .deferred }.count

        return states.map { state in
            guard state.status == .deferred, let habit = habitsByID[state.habitID] else {
                return state
            }

            guard canAdvanceDeferredState(
                state,
                for: habit,
                activeHabitCount: activeHabitCount,
                on: now,
                calendar: calendar
            ) else {
                return state
            }

            var promoted = state
            promoted.status = .pending
            return promoted
        }
    }

    private func canAdvanceDeferredState(
        _ state: DailyHabitState,
        for habit: Habit,
        activeHabitCount: Int,
        on now: Date,
        calendar: Calendar
    ) -> Bool {
        guard !expiredTimeWindow(for: habit, on: now, calendar: calendar) else {
            return false
        }

        guard let nextEligibleAt = state.nextEligibleAt else {
            return true
        }

        guard nextEligibleAt <= now else {
            return false
        }

        return orderingEngine.shouldResurfaceDeferredState(
            state,
            habit: habit,
            activeHabitCount: activeHabitCount,
            on: now,
            calendar: calendar
        )
    }

    private func nextEligibilityDate(
        for habit: Habit,
        deferCount: Int,
        remainingActionableHabits: Int,
        after now: Date,
        calendar: Calendar
    ) -> Date? {
        let today = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: today
        ) ?? now

        var candidate = now.addingTimeInterval(deferInterval)
        let backoffMinutes = min(max(deferCount - 1, 0), 4) * 5
        // Defer backoff stays readable:
        // - the base delay prevents immediate reappearance
        // - repeated deferrals add a little more delay
        // - a larger remaining queue adds a small extra delay so the pass can keep moving forward
        let queueBackoffMinutes = min(max(remainingActionableHabits, 0), 6) * 2
        candidate = candidate.addingTimeInterval(TimeInterval((backoffMinutes + queueBackoffMinutes) * 60))

        switch habit.timeMode {
        case .allDay:
            break
        case .specificTime(let time):
            let scheduled = calendar.date(
                bySettingHour: time.hour,
                minute: time.minute,
                second: 0,
                of: today
            ) ?? today
            if now < scheduled {
                candidate = max(candidate, scheduled)
            }
        case .timeWindow(let window):
            let start = calendar.date(
                bySettingHour: window.start.hour,
                minute: window.start.minute,
                second: 0,
                of: today
            ) ?? today
            let end = calendar.date(
                bySettingHour: window.end.hour,
                minute: window.end.minute,
                second: 0,
                of: today
            ) ?? today

            if now > end {
                return nil
            }

            if now < start {
                candidate = max(candidate, start)
            }
        }

        if let advancedWindow = habit.advancedSchedule?.timingWindow(on: now, calendar: calendar, rhythmConfiguration: rhythmConfiguration) {
            let start = calendar.date(
                bySettingHour: advancedWindow.start.hour,
                minute: advancedWindow.start.minute,
                second: 0,
                of: today
            ) ?? today
            let end = calendar.date(
                bySettingHour: advancedWindow.end.hour,
                minute: advancedWindow.end.minute,
                second: 0,
                of: today
            ) ?? today

            if now > end {
                return nil
            }

            if now < start {
                candidate = max(candidate, start)
            }
        }

        if let rhythmWindow = rhythmConfiguration.window(for: habit.dailyRhythm),
           let rhythmStart = calendar.date(
            bySettingHour: rhythmWindow.start.hour,
            minute: rhythmWindow.start.minute,
            second: 0,
            of: today
           ),
           now < rhythmStart {
            candidate = max(candidate, rhythmStart)
        }

        if candidate > endOfDay {
            return nil
        }

        return candidate
    }

    private func expiredTimeWindow(for habit: Habit, on now: Date, calendar: Calendar) -> Bool {
        let today = calendar.startOfDay(for: now)
        if case .timeWindow(let window) = habit.timeMode {
            let end = calendar.date(
                bySettingHour: window.end.hour,
                minute: window.end.minute,
                second: 0,
                of: today
            ) ?? today

            if now > end {
                return true
            }
        }

        guard let advancedWindow = habit.advancedSchedule?.timingWindow(on: now, calendar: calendar, rhythmConfiguration: rhythmConfiguration) else {
            return false
        }

        let advancedEnd = calendar.date(
            bySettingHour: advancedWindow.end.hour,
            minute: advancedWindow.end.minute,
            second: 0,
            of: today
        ) ?? today

        return now > advancedEnd
    }

    private func deckPriority(for habit: Habit) -> Int {
        var score = 0

        switch habit.timeMode {
        case .allDay:
            score += 8
        case .specificTime(let time):
            score += 18 + min(time.hour, 3)
        case .timeWindow(let window):
            score += 20 + (window.start < window.end ? 4 : 2)
        }

        switch habit.schedule {
        case .daily:
            score += 8
        case .weekly:
            score += 12
        case .biWeekly:
            score += 15
        case .monthly:
            score += 10
        case .customDays:
            score += 12
        case .specificDateRange:
            score += 18
        }

        return score
    }
}

extension DailyHabitState {
    var isActionable: Bool {
        status == .pending
    }
}
