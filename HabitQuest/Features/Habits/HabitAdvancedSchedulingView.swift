import SwiftUI

struct HabitAdvancedSchedulingEditorView: View {
    let initialSchedule: HabitAdvancedSchedule?
    let now: Date
    let calendar: Calendar
    let onSave: (HabitAdvancedSchedule?) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var draft: HabitAdvancedSchedulingDraft

    init(
        initialSchedule: HabitAdvancedSchedule?,
        now: Date,
        calendar: Calendar,
        onSave: @escaping (HabitAdvancedSchedule?) -> Void
    ) {
        self.initialSchedule = initialSchedule
        self.now = now
        self.calendar = calendar
        self.onSave = onSave
        _draft = State(initialValue: HabitAdvancedSchedulingDraft(initialSchedule: initialSchedule, now: now, calendar: calendar))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitQuestScreenBackground()

                ScrollView {
                    VStack(spacing: HabitQuestDesignSystem.Spacing.lg) {
                        headerCard
                        enableCard
                        if draft.isEnabled {
                            recurrenceCard
                            timingCard
                            exceptionsCard
                        }
                    }
                    .padding(.horizontal, HabitQuestDesignSystem.Spacing.pageHorizontal)
                    .padding(.top, HabitQuestDesignSystem.Spacing.lg)
                    .padding(.bottom, HabitQuestDesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Advanced Scheduling")
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
                    Button("Save") {
                        onSave(draft.isEnabled ? draft.makeSchedule(calendar: calendar) : nil)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Label("Premium capability", systemImage: "sparkles")
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            Text("Shape more specific recurrence and timing without losing the calm rhythm of HabitQuest.")
                .font(HabitQuestDesignSystem.Typography.callout)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitQuestSurface(.raised)
    }

    private var enableCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Toggle("Use advanced scheduling", isOn: $draft.isEnabled)
                .tint(HabitQuestDesignSystem.Palette.accent(for: colorScheme))

            Text(draft.isEnabled ? "This adds richer recurrence, timing targets, and gentle exceptions on top of the habit’s core schedule." : "You can keep the habit on a simpler schedule and return here later.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .habitQuestSurface(.raised)
    }

    private var recurrenceCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Recurrence")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Picker("Recurrence mode", selection: $draft.recurrenceMode) {
                ForEach(HabitAdvancedSchedulingDraft.RecurrenceMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch draft.recurrenceMode {
            case .weekdayPattern:
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
                    Stepper(value: $draft.weekInterval, in: 1...12) {
                        Text(draft.weekInterval == 1 ? "Every week" : "Every \(draft.weekInterval) weeks")
                            .font(HabitQuestDesignSystem.Typography.callout)
                            .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                    }

                    weekdayPicker
                }
            case .everyNthDay:
                Stepper(value: $draft.dayInterval, in: 1...31) {
                    Text(draft.dayInterval == 1 ? "Every day" : "Every \(draft.dayInterval) days")
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                }
            case .monthlyDay:
                Stepper(value: $draft.monthDay, in: 1...31) {
                    Text("Day of month \(draft.monthDay)")
                        .font(HabitQuestDesignSystem.Typography.callout)
                        .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                }
            case .dateRange:
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    DatePicker("Start date", selection: $draft.rangeStartDate, displayedComponents: [.date])
                    DatePicker("End date", selection: $draft.rangeEndDate, in: draft.rangeStartDate..., displayedComponents: [.date])
                }
                .datePickerStyle(.compact)
            }
        }
        .habitQuestSurface(.raised)
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Timing")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            Picker("Timing mode", selection: $draft.timingMode) {
                ForEach(HabitAdvancedSchedulingDraft.TimingMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch draft.timingMode {
            case .none:
                Text("The base schedule will decide when the habit is relevant.")
                    .font(HabitQuestDesignSystem.Typography.caption)
                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
            case .routine:
                Picker("Routine target", selection: $draft.routineTarget) {
                    ForEach(HabitRhythm.allCases, id: \.self) { rhythm in
                        Text(rhythmTitle(rhythm)).tag(rhythm)
                    }
                }
                .pickerStyle(.segmented)
            case .timeWindow:
                VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
                    DatePicker("Window start", selection: $draft.windowStart, displayedComponents: [.hourAndMinute])
                    DatePicker("Window end", selection: $draft.windowEnd, displayedComponents: [.hourAndMinute])
                }
                .datePickerStyle(.compact)
            case .exactTime:
                DatePicker("Exact time", selection: $draft.exactTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
            }
        }
        .habitQuestSurface(.raised)
    }

    private var exceptionsCard: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.md) {
            Text("Exceptions")
                .font(HabitQuestDesignSystem.Typography.headline)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))

            DatePicker("Add a quiet day", selection: $draft.newExceptionDate, displayedComponents: [.date])
                .datePickerStyle(.compact)

            Button {
                draft.addException()
            } label: {
                Label("Add exception", systemImage: "plus.circle")
            }
            .habitQuestGlassButtonStyle()

            if !draft.exceptions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(draft.exceptions.enumerated()), id: \.offset) { index, exception in
                        HStack {
                            Text(draft.formatted(date: exception, calendar: calendar))
                                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                                .foregroundStyle(HabitQuestDesignSystem.Palette.textPrimary(for: colorScheme))
                            Spacer()
                            Button {
                                draft.exceptions.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove exception"))
                        }
                        .padding(.horizontal, HabitQuestDesignSystem.Spacing.sm)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: HabitQuestDesignSystem.Radius.md, style: .continuous)
                                .fill(HabitQuestDesignSystem.Palette.surface(for: colorScheme))
                        )
                    }
                }
            }
        }
        .habitQuestSurface(.raised)
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            Text("Select weekdays")
                .font(HabitQuestDesignSystem.Typography.caption.weight(.semibold))
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))

            HStack(spacing: HabitQuestDesignSystem.Spacing.sm) {
                ForEach(Array(Weekday.allCases.enumerated()), id: \.offset) { _, weekday in
                    Button {
                        if draft.selectedWeekdays.contains(weekday) {
                            draft.selectedWeekdays.remove(weekday)
                        } else {
                            draft.selectedWeekdays.insert(weekday)
                        }
                    } label: {
                        Text(weekdayShortTitle(weekday))
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
                    .accessibilityLabel(Text(weekdayTitle(weekday)))
                    .accessibilityAddTraits(draft.selectedWeekdays.contains(weekday) ? .isSelected : [])
                }
            }
        }
    }
}

struct HabitAdvancedSchedulingPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: HabitQuestDesignSystem.Spacing.sm) {
            HStack(spacing: HabitQuestDesignSystem.Spacing.xs) {
                HabitQuestGlassChip(title: "Every 2 weeks", isSelected: true)
                HabitQuestGlassChip(title: "Morning", isSelected: false)
                HabitQuestGlassChip(title: "Exceptions", isSelected: false)
            }

            Text("Advanced scheduling keeps the base habit calm while adding more precise recurrence and timing.")
                .font(HabitQuestDesignSystem.Typography.caption)
                .foregroundStyle(HabitQuestDesignSystem.Palette.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HabitAdvancedSchedulingDraft {
    enum RecurrenceMode: String, CaseIterable {
        case weekdayPattern
        case everyNthDay
        case monthlyDay
        case dateRange

        var title: String {
            switch self {
            case .weekdayPattern:
                return "Weekdays"
            case .everyNthDay:
                return "Every N days"
            case .monthlyDay:
                return "Monthly day"
            case .dateRange:
                return "Date range"
            }
        }
    }

    enum TimingMode: String, CaseIterable {
        case none
        case routine
        case timeWindow
        case exactTime

        var title: String {
            switch self {
            case .none:
                return "None"
            case .routine:
                return "Routine"
            case .timeWindow:
                return "Window"
            case .exactTime:
                return "Exact time"
            }
        }
    }

    var isEnabled: Bool
    var recurrenceMode: RecurrenceMode
    var selectedWeekdays: Set<Weekday>
    var weekInterval: Int
    var dayInterval: Int
    var monthDay: Int
    var rangeStartDate: Date
    var rangeEndDate: Date
    var timingMode: TimingMode
    var routineTarget: HabitRhythm
    var windowStart: Date
    var windowEnd: Date
    var exactTime: Date
    var exceptions: [Date]
    var newExceptionDate: Date
    var anchorDate: Date
    var calendar: Calendar

    init(initialSchedule: HabitAdvancedSchedule?, now: Date, calendar: Calendar) {
        isEnabled = true
        recurrenceMode = .weekdayPattern
        selectedWeekdays = [Weekday(calendarWeekday: calendar.component(.weekday, from: now))]
        weekInterval = 1
        dayInterval = 2
        monthDay = max(1, min(calendar.component(.day, from: now), 31))
        rangeStartDate = calendar.startOfDay(for: now)
        rangeEndDate = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: now)) ?? now
        timingMode = .none
        routineTarget = .morning
        windowStart = HabitAdvancedSchedulingDraft.defaultTime(hour: 6, minute: 0, now: now, calendar: calendar)
        windowEnd = HabitAdvancedSchedulingDraft.defaultTime(hour: 9, minute: 0, now: now, calendar: calendar)
        exactTime = HabitAdvancedSchedulingDraft.defaultTime(hour: 8, minute: 0, now: now, calendar: calendar)
        exceptions = []
        newExceptionDate = calendar.startOfDay(for: now)
        anchorDate = calendar.startOfDay(for: now)
        self.calendar = calendar

        guard let initialSchedule else {
            return
        }

        if let recurrenceRule = initialSchedule.rules.first(where: { $0.isRecurrenceRule }) {
            switch recurrenceRule {
            case .weekdayPattern(let pattern):
                recurrenceMode = .weekdayPattern
                selectedWeekdays = pattern.weekdays.isEmpty ? selectedWeekdays : pattern.weekdays
                weekInterval = pattern.intervalWeeks
                anchorDate = pattern.anchorDate
            case .everyNthDay(let interval, let anchorDate):
                recurrenceMode = .everyNthDay
                dayInterval = interval
                self.anchorDate = anchorDate
            case .monthlyDays(let days):
                recurrenceMode = .monthlyDay
                monthDay = days.sorted().first ?? monthDay
            case .dateRange(let range):
                recurrenceMode = .dateRange
                rangeStartDate = range.startDate
                rangeEndDate = range.endDate
            case .routineTarget, .timeWindow, .specificTime:
                break
            }
        }

        if let timingRule = initialSchedule.rules.first(where: { $0.isTimingRule }) {
            switch timingRule {
            case .routineTarget(let rhythm):
                timingMode = .routine
                routineTarget = rhythm
            case .timeWindow(let window):
                timingMode = .timeWindow
                windowStart = HabitAdvancedSchedulingDraft.defaultTime(hour: window.start.hour, minute: window.start.minute, now: now, calendar: calendar)
                windowEnd = HabitAdvancedSchedulingDraft.defaultTime(hour: window.end.hour, minute: window.end.minute, now: now, calendar: calendar)
            case .specificTime(let time):
                timingMode = .exactTime
                exactTime = HabitAdvancedSchedulingDraft.defaultTime(hour: time.hour, minute: time.minute, now: now, calendar: calendar)
            case .weekdayPattern, .everyNthDay, .monthlyDays, .dateRange:
                break
            }
        }

        exceptions = initialSchedule.exceptions.map(\.date)
        if let lastException = exceptions.last {
            newExceptionDate = lastException
        }
    }

    func makeSchedule(calendar: Calendar) -> HabitAdvancedSchedule {
        var rules: [HabitAdvancedRule] = []

        switch recurrenceMode {
        case .weekdayPattern:
            rules.append(.weekdayPattern(HabitAdvancedWeekdayPattern(weekdays: selectedWeekdays.isEmpty ? [.monday] : selectedWeekdays, intervalWeeks: weekInterval, anchorDate: anchorDate)))
        case .everyNthDay:
            rules.append(.everyNthDay(interval: dayInterval, anchorDate: anchorDate))
        case .monthlyDay:
            rules.append(.monthlyDays([monthDay]))
        case .dateRange:
            rules.append(.dateRange(HabitDateRange(startDate: rangeStartDate, endDate: rangeEndDate)))
        }

        switch timingMode {
        case .none:
            break
        case .routine:
            rules.append(.routineTarget(routineTarget))
        case .timeWindow:
            rules.append(.timeWindow(HabitTimeWindow(
                start: HabitClockTime(hour: calendar.component(.hour, from: windowStart), minute: calendar.component(.minute, from: windowStart)),
                end: HabitClockTime(hour: calendar.component(.hour, from: windowEnd), minute: calendar.component(.minute, from: windowEnd))
            )))
        case .exactTime:
            rules.append(.specificTime(HabitClockTime(hour: calendar.component(.hour, from: exactTime), minute: calendar.component(.minute, from: exactTime))))
        }

        return HabitAdvancedSchedule(
            rules: rules,
            exceptions: exceptions.map { HabitScheduleException(date: $0) },
            createdAt: anchorDate
        )
    }

    mutating func addException() {
        let targetDay = calendar.startOfDay(for: newExceptionDate)
        guard !exceptions.contains(where: { calendar.isDate($0, inSameDayAs: targetDay) }) else {
            return
        }
        exceptions.append(targetDay)
        exceptions.sort()
    }

    func formatted(date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func defaultTime(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? now
    }
}

private func weekdayTitle(_ weekday: Weekday) -> String {
    switch weekday {
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

private func weekdayShortTitle(_ weekday: Weekday) -> String {
    switch weekday {
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

private func rhythmTitle(_ rhythm: HabitRhythm) -> String {
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
