import Foundation

enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    init(calendarWeekday: Int) {
        self = Weekday(rawValue: calendarWeekday) ?? .sunday
    }
}

enum HabitRhythm: String, Codable, CaseIterable, Hashable, Sendable {
    case morning
    case day
    case evening
    case anytime
}

struct DailyRhythmTimeRange: Codable, Equatable, Hashable, Sendable {
    var start: HabitClockTime
    var end: HabitClockTime

    init(start: HabitClockTime, end: HabitClockTime) {
        self.start = start
        self.end = end
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = start.minutesSinceStartOfDay()
        let endMinute = end.minutesSinceStartOfDay()

        if startMinute <= endMinute {
            return (startMinute...endMinute).contains(minuteOfDay)
        }

        return minuteOfDay >= startMinute || minuteOfDay <= endMinute
    }

    func progress(at date: Date, calendar: Calendar) -> Double? {
        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = start.minutesSinceStartOfDay()
        let endMinute = end.minutesSinceStartOfDay()

        let duration: Int
        let elapsed: Int

        if startMinute <= endMinute {
            duration = max(endMinute - startMinute, 1)
            guard minuteOfDay >= startMinute else {
                return 0
            }
            elapsed = min(max(minuteOfDay - startMinute, 0), duration)
            return Double(elapsed) / Double(duration)
        }

        duration = max((24 * 60 - startMinute) + endMinute, 1)
        let adjustedMinute = minuteOfDay >= startMinute ? minuteOfDay : minuteOfDay + (24 * 60)
        elapsed = min(max(adjustedMinute - startMinute, 0), duration)
        return Double(elapsed) / Double(duration)
    }
}

struct DailyRhythmConfiguration: Codable, Equatable, Sendable {
    var morning: DailyRhythmTimeRange
    var day: DailyRhythmTimeRange
    var evening: DailyRhythmTimeRange

    static let `default` = DailyRhythmConfiguration(
        morning: DailyRhythmTimeRange(
            start: HabitClockTime(hour: 5),
            end: HabitClockTime(hour: 11)
        ),
        day: DailyRhythmTimeRange(
            start: HabitClockTime(hour: 11),
            end: HabitClockTime(hour: 17)
        ),
        evening: DailyRhythmTimeRange(
            start: HabitClockTime(hour: 17),
            end: HabitClockTime(hour: 23, minute: 59)
        )
    )

    var morningWindow: DailyRhythmTimeRange { morning }
    var dayWindow: DailyRhythmTimeRange { day }
    var eveningWindow: DailyRhythmTimeRange { evening }

    func window(for rhythm: HabitRhythm) -> DailyRhythmTimeRange? {
        switch rhythm {
        case .morning:
            return morning
        case .day:
            return day
        case .evening:
            return evening
        case .anytime:
            return nil
        }
    }

    func priorityScore(for rhythm: HabitRhythm, at date: Date, calendar: Calendar) -> Int {
        switch rhythm {
        case .anytime:
            return 12
        case .morning:
            return score(
                for: morning,
                at: date,
                calendar: calendar,
                base: 10,
                active: 18,
                trailing: 6
            )
        case .day:
            return score(
                for: day,
                at: date,
                calendar: calendar,
                base: 9,
                active: 16,
                trailing: 7
            )
        case .evening:
            return score(
                for: evening,
                at: date,
                calendar: calendar,
                base: 4,
                active: 17,
                trailing: 5
            )
        }
    }

    private func score(
        for range: DailyRhythmTimeRange,
        at date: Date,
        calendar: Calendar,
        base: Int,
        active: Int,
        trailing: Int
    ) -> Int {
        if range.contains(date, calendar: calendar) {
            let progress = range.progress(at: date, calendar: calendar) ?? 0
            return active + Int((progress * 12).rounded())
        }

        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = range.start.minutesSinceStartOfDay()
        let endMinute = range.end.minutesSinceStartOfDay()

        if minuteOfDay < startMinute {
            return base
        }

        if minuteOfDay > endMinute {
            return trailing
        }

        return base
    }
}

struct HabitClockTime: Codable, Equatable, Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int = 0) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    static func < (lhs: HabitClockTime, rhs: HabitClockTime) -> Bool {
        if lhs.hour == rhs.hour {
            return lhs.minute < rhs.minute
        }
        return lhs.hour < rhs.hour
    }

    func matches(_ date: Date, calendar: Calendar) -> Bool {
        calendar.component(.hour, from: date) == hour && calendar.component(.minute, from: date) == minute
    }

    func minutesSinceStartOfDay() -> Int {
        hour * 60 + minute
    }
}

struct HabitTimeWindow: Codable, Equatable, Hashable, Sendable {
    var start: HabitClockTime
    var end: HabitClockTime

    init(start: HabitClockTime, end: HabitClockTime) {
        self.start = start
        self.end = end
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let minuteOfDay = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinute = start.minutesSinceStartOfDay()
        let endMinute = end.minutesSinceStartOfDay()

        if startMinute <= endMinute {
            return (startMinute...endMinute).contains(minuteOfDay)
        }

        return minuteOfDay >= startMinute || minuteOfDay <= endMinute
    }
}

enum HabitTimeMode: Codable, Equatable, Sendable {
    case allDay
    case specificTime(HabitClockTime)
    case timeWindow(HabitTimeWindow)

    private enum CodingKeys: String, CodingKey {
        case kind
        case time
        case window
    }

    private enum Kind: String, Codable {
        case allDay
        case specificTime
        case timeWindow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .allDay:
            self = .allDay
        case .specificTime:
            self = .specificTime(try container.decode(HabitClockTime.self, forKey: .time))
        case .timeWindow:
            self = .timeWindow(try container.decode(HabitTimeWindow.self, forKey: .window))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .allDay:
            try container.encode(Kind.allDay, forKey: .kind)
        case .specificTime(let time):
            try container.encode(Kind.specificTime, forKey: .kind)
            try container.encode(time, forKey: .time)
        case .timeWindow(let window):
            try container.encode(Kind.timeWindow, forKey: .kind)
            try container.encode(window, forKey: .window)
        }
    }

    func isCurrentlyRelevant(on date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .allDay:
            return true
        case .specificTime(let time):
            return time.matches(date, calendar: calendar)
        case .timeWindow(let window):
            return window.contains(date, calendar: calendar)
        }
    }
}

struct HabitDateRange: Codable, Equatable, Hashable, Sendable {
    var startDate: Date
    var endDate: Date

    init(startDate: Date, endDate: Date) {
        if startDate <= endDate {
            self.startDate = startDate
            self.endDate = endDate
        } else {
            self.startDate = endDate
            self.endDate = startDate
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let target = calendar.startOfDay(for: date)
        return (start...end).contains(target)
    }
}

struct HabitScheduleException: Codable, Equatable, Hashable, Sendable {
    var date: Date
    var note: String?

    init(date: Date, note: String? = nil) {
        self.date = date
        self.note = note
    }

    func matches(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: self.date)
    }
}

struct HabitAdvancedWeekdayPattern: Codable, Equatable, Hashable, Sendable {
    var weekdays: Set<Weekday>
    var intervalWeeks: Int
    var anchorDate: Date

    init(weekdays: Set<Weekday>, intervalWeeks: Int = 1, anchorDate: Date) {
        self.weekdays = weekdays
        self.intervalWeeks = max(intervalWeeks, 1)
        self.anchorDate = anchorDate
    }
}

enum HabitAdvancedRule: Codable, Equatable, Hashable, Sendable {
    case weekdayPattern(HabitAdvancedWeekdayPattern)
    case everyNthDay(interval: Int, anchorDate: Date)
    case monthlyDays(Set<Int>)
    case dateRange(HabitDateRange)
    case routineTarget(HabitRhythm)
    case timeWindow(HabitTimeWindow)
    case specificTime(HabitClockTime)

    private enum CodingKeys: String, CodingKey {
        case kind
        case weekdayPattern
        case interval
        case anchorDate
        case days
        case range
        case rhythm
        case window
        case time
    }

    private enum Kind: String, Codable {
        case weekdayPattern
        case everyNthDay
        case monthlyDays
        case dateRange
        case routineTarget
        case timeWindow
        case specificTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .weekdayPattern:
            self = .weekdayPattern(try container.decode(HabitAdvancedWeekdayPattern.self, forKey: .weekdayPattern))
        case .everyNthDay:
            self = .everyNthDay(
                interval: try container.decode(Int.self, forKey: .interval),
                anchorDate: try container.decode(Date.self, forKey: .anchorDate)
            )
        case .monthlyDays:
            self = .monthlyDays(Set(try container.decode([Int].self, forKey: .days)))
        case .dateRange:
            self = .dateRange(try container.decode(HabitDateRange.self, forKey: .range))
        case .routineTarget:
            self = .routineTarget(try container.decode(HabitRhythm.self, forKey: .rhythm))
        case .timeWindow:
            self = .timeWindow(try container.decode(HabitTimeWindow.self, forKey: .window))
        case .specificTime:
            self = .specificTime(try container.decode(HabitClockTime.self, forKey: .time))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .weekdayPattern(let pattern):
            try container.encode(Kind.weekdayPattern, forKey: .kind)
            try container.encode(pattern, forKey: .weekdayPattern)
        case .everyNthDay(let interval, let anchorDate):
            try container.encode(Kind.everyNthDay, forKey: .kind)
            try container.encode(max(interval, 1), forKey: .interval)
            try container.encode(anchorDate, forKey: .anchorDate)
        case .monthlyDays(let days):
            try container.encode(Kind.monthlyDays, forKey: .kind)
            try container.encode(days.sorted(), forKey: .days)
        case .dateRange(let range):
            try container.encode(Kind.dateRange, forKey: .kind)
            try container.encode(range, forKey: .range)
        case .routineTarget(let rhythm):
            try container.encode(Kind.routineTarget, forKey: .kind)
            try container.encode(rhythm, forKey: .rhythm)
        case .timeWindow(let window):
            try container.encode(Kind.timeWindow, forKey: .kind)
            try container.encode(window, forKey: .window)
        case .specificTime(let time):
            try container.encode(Kind.specificTime, forKey: .kind)
            try container.encode(time, forKey: .time)
        }
    }

    var isRecurrenceRule: Bool {
        switch self {
        case .weekdayPattern, .everyNthDay, .monthlyDays, .dateRange:
            return true
        case .routineTarget, .timeWindow, .specificTime:
            return false
        }
    }

    var isTimingRule: Bool {
        !isRecurrenceRule
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

    func matchesRecurrence(
        on date: Date,
        createdAt: Date,
        calendar: Calendar = .current
    ) -> Bool {
        switch self {
        case .weekdayPattern(let pattern):
            let targetDay = calendar.startOfDay(for: date)
            let anchorDay = calendar.startOfDay(for: pattern.anchorDate)
            guard targetDay >= anchorDay else {
                return false
            }

            guard pattern.weekdays.contains(Weekday(calendarWeekday: calendar.component(.weekday, from: date))) else {
                return false
            }

            let weekDifference = calendar.dateComponents([.weekOfYear], from: anchorDay, to: targetDay).weekOfYear ?? 0
            return weekDifference >= 0 && weekDifference.isMultiple(of: pattern.intervalWeeks)
        case .everyNthDay(let interval, let anchorDate):
            let targetDay = calendar.startOfDay(for: date)
            let anchorDay = calendar.startOfDay(for: anchorDate)
            guard targetDay >= anchorDay else {
                return false
            }

            let dayDifference = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
            return dayDifference >= 0 && dayDifference.isMultiple(of: max(interval, 1))
        case .monthlyDays(let days):
            return days.contains(calendar.component(.day, from: date))
        case .dateRange(let range):
            return range.contains(date, calendar: calendar)
        case .routineTarget, .timeWindow, .specificTime:
            return true
        }
    }

    func matchesTiming(
        on date: Date,
        calendar: Calendar = .current,
        rhythmConfiguration: DailyRhythmConfiguration = .default
    ) -> Bool {
        switch self {
        case .weekdayPattern, .everyNthDay, .monthlyDays, .dateRange:
            return true
        case .routineTarget(let rhythm):
            guard let window = rhythmConfiguration.window(for: rhythm) else {
                return true
            }
            return window.contains(date, calendar: calendar)
        case .timeWindow(let window):
            return window.contains(date, calendar: calendar)
        case .specificTime(let time):
            return time.matches(date, calendar: calendar)
        }
    }

    func timingWindow(
        on date: Date,
        calendar: Calendar = .current,
        rhythmConfiguration: DailyRhythmConfiguration = .default
    ) -> HabitTimeWindow? {
        switch self {
        case .routineTarget(let rhythm):
            guard let window = rhythmConfiguration.window(for: rhythm) else {
                return nil
            }
            return HabitTimeWindow(start: window.start, end: window.end)
        case .timeWindow(let window):
            return window
        case .specificTime(let time):
            return HabitTimeWindow(start: time, end: time)
        case .weekdayPattern, .everyNthDay, .monthlyDays, .dateRange:
            return nil
        }
    }

    var displaySummary: String {
        switch self {
        case .weekdayPattern(let pattern):
            let weekdays = pattern.weekdays
                .sorted(by: { $0.rawValue < $1.rawValue })
                .map(weekdayShortTitle)
                .joined(separator: " ")
            if pattern.intervalWeeks <= 1 {
                return "Weekdays · \(weekdays)"
            }
            return "Every \(pattern.intervalWeeks) weeks · \(weekdays)"
        case .everyNthDay(let interval, _):
            return "Every \(max(interval, 1)) days"
        case .monthlyDays(let days):
            let value = days.sorted().map(String.init).joined(separator: ", ")
            return "Monthly · Days \(value)"
        case .dateRange(let range):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "\(formatter.string(from: range.startDate)) - \(formatter.string(from: range.endDate))"
        case .routineTarget(let rhythm):
            return "Targets \(rhythmTitle(rhythm))"
        case .timeWindow(let window):
            return "Window \(window.start.hour):\(String(format: "%02d", window.start.minute)) - \(window.end.hour):\(String(format: "%02d", window.end.minute))"
        case .specificTime(let time):
            return "At \(time.hour):\(String(format: "%02d", time.minute))"
        }
    }
}

struct HabitAdvancedSchedule: Codable, Equatable, Hashable, Sendable {
    var rules: [HabitAdvancedRule]
    var exceptions: [HabitScheduleException]
    var createdAt: Date

    init(
        rules: [HabitAdvancedRule] = [],
        exceptions: [HabitScheduleException] = [],
        createdAt: Date
    ) {
        self.rules = rules
        self.exceptions = exceptions
        self.createdAt = createdAt
    }

    func isScheduled(
        on date: Date,
        createdAt habitCreatedAt: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let targetDay = calendar.startOfDay(for: date)
        let habitDay = calendar.startOfDay(for: habitCreatedAt)
        guard targetDay >= habitDay else {
            return false
        }

        guard !exceptions.contains(where: { $0.matches(date, calendar: calendar) }) else {
            return false
        }

        let recurrenceRules = rules.filter(\.isRecurrenceRule)
        guard !recurrenceRules.isEmpty else {
            return true
        }

        return recurrenceRules.allSatisfy { $0.matchesRecurrence(on: date, createdAt: habitCreatedAt, calendar: calendar) }
    }

    func isCurrentlyRelevant(
        on date: Date,
        calendar: Calendar = .current,
        rhythmConfiguration: DailyRhythmConfiguration = .default
    ) -> Bool {
        let timingRules = rules.filter(\.isTimingRule)
        guard !timingRules.isEmpty else {
            return true
        }

        return timingRules.allSatisfy { $0.matchesTiming(on: date, calendar: calendar, rhythmConfiguration: rhythmConfiguration) }
    }

    func timingWindow(
        on date: Date,
        calendar: Calendar = .current,
        rhythmConfiguration: DailyRhythmConfiguration = .default
    ) -> HabitTimeWindow? {
        let timingWindows = rules.compactMap { $0.timingWindow(on: date, calendar: calendar, rhythmConfiguration: rhythmConfiguration) }
        guard !timingWindows.isEmpty else {
            return nil
        }

        let start = timingWindows.map(\.start).max() ?? timingWindows[0].start
        let end = timingWindows.map(\.end).min() ?? timingWindows[0].end
        return HabitTimeWindow(start: start, end: end)
    }

    var displaySummary: String {
        let parts = rules.map(\.displaySummary)
        if exceptions.isEmpty {
            return parts.joined(separator: " · ")
        }

        let exceptionText = exceptions.count == 1 ? "1 exception" : "\(exceptions.count) exceptions"
        let joined = parts.joined(separator: " · ")
        if joined.isEmpty {
            return exceptionText
        }
        return "\(joined) · \(exceptionText)"
    }
}

enum HabitSchedule: Codable, Equatable, Sendable {
    case daily
    case weekly(days: Set<Weekday>)
    case biWeekly(days: Set<Weekday>)
    case monthly(dayOfMonth: Int)
    case customDays(days: Set<Weekday>)
    case specificDateRange(HabitDateRange)

    private enum CodingKeys: String, CodingKey {
        case kind
        case days
        case dayOfMonth
        case range
    }

    private enum Kind: String, Codable {
        case daily
        case weekly
        case biWeekly
        case monthly
        case customDays
        case specificDateRange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .daily:
            self = .daily
        case .weekly:
            self = .weekly(days: Set(try container.decode([Weekday].self, forKey: .days)))
        case .biWeekly:
            self = .biWeekly(days: Set(try container.decode([Weekday].self, forKey: .days)))
        case .monthly:
            self = .monthly(dayOfMonth: try container.decode(Int.self, forKey: .dayOfMonth))
        case .customDays:
            self = .customDays(days: Set(try container.decode([Weekday].self, forKey: .days)))
        case .specificDateRange:
            self = .specificDateRange(try container.decode(HabitDateRange.self, forKey: .range))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode(Kind.daily, forKey: .kind)
        case .weekly(let days):
            try container.encode(Kind.weekly, forKey: .kind)
            try container.encode(days.sorted(by: { $0.rawValue < $1.rawValue }), forKey: .days)
        case .biWeekly(let days):
            try container.encode(Kind.biWeekly, forKey: .kind)
            try container.encode(days.sorted(by: { $0.rawValue < $1.rawValue }), forKey: .days)
        case .monthly(let dayOfMonth):
            try container.encode(Kind.monthly, forKey: .kind)
            try container.encode(dayOfMonth, forKey: .dayOfMonth)
        case .customDays(let days):
            try container.encode(Kind.customDays, forKey: .kind)
            try container.encode(days.sorted(by: { $0.rawValue < $1.rawValue }), forKey: .days)
        case .specificDateRange(let range):
            try container.encode(Kind.specificDateRange, forKey: .kind)
            try container.encode(range, forKey: .range)
        }
    }

    func isScheduled(on date: Date, createdAt: Date, calendar: Calendar = .current) -> Bool {
        let startOfCreatedDay = calendar.startOfDay(for: createdAt)
        let startOfTargetDay = calendar.startOfDay(for: date)
        guard startOfTargetDay >= startOfCreatedDay else {
            return false
        }

        let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: date))

        switch self {
        case .daily:
            return true

        case .weekly(let days), .customDays(let days):
            return days.contains(weekday)

        case .biWeekly(let days):
            guard days.contains(weekday) else {
                return false
            }

            let weekDifference = calendar.dateComponents(
                [.weekOfYear],
                from: startOfCreatedDay,
                to: startOfTargetDay
            ).weekOfYear ?? 0

            return weekDifference >= 0 && weekDifference.isMultiple(of: 2)

        case .monthly(let dayOfMonth):
            let currentDay = calendar.component(.day, from: date)
            guard dayOfMonth == 31 else {
                return currentDay == dayOfMonth
            }

            guard let range = calendar.range(of: .day, in: .month, for: date) else {
                return currentDay == dayOfMonth
            }

            return currentDay == range.count

        case .specificDateRange(let range):
            return range.contains(date, calendar: calendar)
        }
    }
}

struct HabitReminderConfiguration: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var rules: [HabitReminderRule]
    var advancedConfiguration: HabitAdvancedReminderConfiguration?

    init(
        isEnabled: Bool = true,
        rules: [HabitReminderRule] = [],
        advancedConfiguration: HabitAdvancedReminderConfiguration? = nil
    ) {
        self.isEnabled = isEnabled
        self.rules = rules
        self.advancedConfiguration = advancedConfiguration
    }
}

enum HabitReminderRoutineMode: String, Codable, CaseIterable, Sendable {
    case off
    case dailyRhythm
    case assignedDaySection
}

struct HabitAdvancedReminderConfiguration: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var primaryReminderTimes: [HabitClockTime]
    var reminderWindow: HabitTimeWindow?
    var followUpDelayMinutes: Int
    var followUpCount: Int
    var routineAwareMode: HabitReminderRoutineMode
    var adaptiveTimingEnabled: Bool

    init(
        isEnabled: Bool = true,
        primaryReminderTimes: [HabitClockTime] = [],
        reminderWindow: HabitTimeWindow? = nil,
        followUpDelayMinutes: Int = 90,
        followUpCount: Int = 1,
        routineAwareMode: HabitReminderRoutineMode = .off,
        adaptiveTimingEnabled: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.primaryReminderTimes = primaryReminderTimes
        self.reminderWindow = reminderWindow
        self.followUpDelayMinutes = max(followUpDelayMinutes, 0)
        self.followUpCount = max(followUpCount, 0)
        self.routineAwareMode = routineAwareMode
        self.adaptiveTimingEnabled = adaptiveTimingEnabled
    }
}

enum HabitReminderRule: Codable, Equatable, Sendable {
    case atTime(HabitClockTime)
    case beforeScheduledTime(minutes: Int)

    private enum CodingKeys: String, CodingKey {
        case kind
        case time
        case minutes
    }

    private enum Kind: String, Codable {
        case atTime
        case beforeScheduledTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .atTime:
            self = .atTime(try container.decode(HabitClockTime.self, forKey: .time))
        case .beforeScheduledTime:
            self = .beforeScheduledTime(minutes: try container.decode(Int.self, forKey: .minutes))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .atTime(let time):
            try container.encode(Kind.atTime, forKey: .kind)
            try container.encode(time, forKey: .time)
        case .beforeScheduledTime(let minutes):
            try container.encode(Kind.beforeScheduledTime, forKey: .kind)
            try container.encode(minutes, forKey: .minutes)
        }
    }
}

enum HabitDaySectionPeriod: String, Codable, CaseIterable, Hashable, Sendable {
    case morning
    case afternoon
    case evening

    var displayName: String {
        switch self {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        }
    }
}

struct HabitDaySectionTimeMetadata: Codable, Equatable, Hashable, Sendable {
    var start: HabitClockTime
    var end: HabitClockTime

    init(start: HabitClockTime, end: HabitClockTime) {
        self.start = start
        self.end = end
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        DailyRhythmTimeRange(start: start, end: end).contains(date, calendar: calendar)
    }
}

struct HabitDaySection: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var order: Int
    var icon: String?
    var timeMetadata: HabitDaySectionTimeMetadata?
    var contextualNotes: String?
    var isActive: Bool
    var period: HabitDaySectionPeriod?

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        icon: String? = nil,
        timeMetadata: HabitDaySectionTimeMetadata? = nil,
        contextualNotes: String? = nil,
        isActive: Bool = true,
        period: HabitDaySectionPeriod? = nil
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.icon = icon
        self.timeMetadata = timeMetadata
        self.contextualNotes = contextualNotes
        self.isActive = isActive
        self.period = period
    }

    var displayTitle: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Section" : name
    }

    var displayIcon: String {
        let icon = icon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return icon.isEmpty ? "◌" : icon
    }
}

enum HabitDaySectionCatalog {
    static let morningID = UUID(uuidString: "6A4A6D34-5F21-41F8-8D9D-A3B5D7D0A101")!
    static let afternoonID = UUID(uuidString: "6A4A6D34-5F21-41F8-8D9D-A3B5D7D0A102")!
    static let eveningID = UUID(uuidString: "6A4A6D34-5F21-41F8-8D9D-A3B5D7D0A103")!

    static let builtInSections: [HabitDaySection] = [
        HabitDaySection(
            id: morningID,
            name: "Morning",
            order: 0,
            icon: "sunrise",
            timeMetadata: HabitDaySectionTimeMetadata(
                start: HabitClockTime(hour: 5, minute: 0),
                end: HabitClockTime(hour: 11, minute: 0)
            ),
            contextualNotes: "Gentle starts and first priorities.",
            isActive: true,
            period: .morning
        ),
        HabitDaySection(
            id: afternoonID,
            name: "Afternoon",
            order: 1,
            icon: "sun.max",
            timeMetadata: HabitDaySectionTimeMetadata(
                start: HabitClockTime(hour: 11, minute: 0),
                end: HabitClockTime(hour: 17, minute: 0)
            ),
            contextualNotes: "Steady middle-of-day habits.",
            isActive: true,
            period: .afternoon
        ),
        HabitDaySection(
            id: eveningID,
            name: "Evening",
            order: 2,
            icon: "moon",
            timeMetadata: HabitDaySectionTimeMetadata(
                start: HabitClockTime(hour: 17, minute: 0),
                end: HabitClockTime(hour: 23, minute: 59)
            ),
            contextualNotes: "Wind-down habits and reflections.",
            isActive: true,
            period: .evening
        )
    ]

    static func allSections(customSections: [HabitDaySection]) -> [HabitDaySection] {
        builtInSections + customSections
    }

    static func section(with id: UUID, customSections: [HabitDaySection]) -> HabitDaySection? {
        allSections(customSections: customSections).first { $0.id == id }
    }
}

struct Habit: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var notes: String?
    var icon: String?
    var colorHex: String?
    var category: String?
    var isArchived: Bool
    var isPaused: Bool
    var schedule: HabitSchedule
    var timeMode: HabitTimeMode
    var dailyRhythm: HabitRhythm
    var daySectionID: UUID?
    var displayOrder: Int64
    var advancedSchedule: HabitAdvancedSchedule?
    var reminderConfiguration: HabitReminderConfiguration?
    var difficulty: Int?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        category: String? = nil,
        isArchived: Bool = false,
        isPaused: Bool = false,
        schedule: HabitSchedule = .daily,
        timeMode: HabitTimeMode = .allDay,
        dailyRhythm: HabitRhythm = .anytime,
        daySectionID: UUID? = nil,
        displayOrder: Int64 = 0,
        advancedSchedule: HabitAdvancedSchedule? = nil,
        reminderConfiguration: HabitReminderConfiguration? = nil,
        difficulty: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.icon = icon
        self.colorHex = colorHex
        self.category = category
        self.isArchived = isArchived
        self.isPaused = isPaused
        self.schedule = schedule
        self.timeMode = timeMode
        self.dailyRhythm = dailyRhythm
        self.daySectionID = daySectionID
        self.displayOrder = displayOrder
        self.advancedSchedule = advancedSchedule
        self.reminderConfiguration = reminderConfiguration
        self.difficulty = difficulty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func isPausedHabit() -> Bool {
        isPaused
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        guard schedule.isScheduled(on: date, createdAt: createdAt, calendar: calendar) else {
            return false
        }

        guard let advancedSchedule else {
            return true
        }

        return advancedSchedule.isScheduled(on: date, createdAt: createdAt, calendar: calendar)
    }

    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        !isArchived && !isPaused && isScheduled(on: date, calendar: calendar)
    }

    func isRelevant(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isActive(on: date, calendar: calendar) else {
            return false
        }

        guard timeMode.isCurrentlyRelevant(on: date, calendar: calendar) else {
            return false
        }

        guard let advancedSchedule else {
            return true
        }

        return advancedSchedule.isCurrentlyRelevant(on: date, calendar: calendar)
    }

    func isCurrentlyRelevant(on date: Date, calendar: Calendar = .current) -> Bool {
        isRelevant(on: date, calendar: calendar)
    }
}

enum DailyHabitStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case deferred
    case completed
    case expired
    case skipped
}

struct CompletionEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    let timestamp: Date
    let logicalCompletionDate: Date
    let source: CompletionSource
    var reflection: String?

    var completedAt: Date {
        timestamp
    }

    init(
        id: UUID = UUID(),
        habitID: UUID,
        timestamp: Date = .now,
        logicalCompletionDate: Date? = nil,
        source: CompletionSource = .manualHabitAction,
        reflection: String? = nil
    ) {
        self.id = id
        self.habitID = habitID
        self.timestamp = timestamp
        self.logicalCompletionDate = logicalCompletionDate ?? Calendar.current.startOfDay(for: timestamp)
        self.source = source
        self.reflection = reflection?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

enum CompletionSource: String, Codable, CaseIterable, Sendable {
    case todayDeckSwipe
    case todayDeckButton
    case manualHabitAction
}

struct DailyHabitState: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    var date: Date
    var status: DailyHabitStatus
    var deferCount: Int
    var lastDeferredAt: Date?
    var completedAt: Date?
    var deckPriority: Int
    var currentPass: Int
    var nextEligibleAt: Date?
    var streakFreezeAppliedAt: Date?

    init(
        id: UUID = UUID(),
        habitID: UUID,
        date: Date = .now,
        status: DailyHabitStatus = .pending,
        deferCount: Int = 0,
        lastDeferredAt: Date? = nil,
        completedAt: Date? = nil,
        deckPriority: Int = 0,
        currentPass: Int = 1,
        nextEligibleAt: Date? = nil,
        streakFreezeAppliedAt: Date? = nil
    ) {
        self.id = id
        self.habitID = habitID
        self.date = date
        self.status = status
        self.deferCount = deferCount
        self.lastDeferredAt = lastDeferredAt
        self.completedAt = completedAt
        self.deckPriority = deckPriority
        self.currentPass = currentPass
        self.nextEligibleAt = nextEligibleAt
        self.streakFreezeAppliedAt = streakFreezeAppliedAt
    }
}

struct HabitTemplate: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let accentHex: String
    let category: String?
    let notes: String?
    let schedule: HabitSchedule
    let timeMode: HabitTimeMode
    let dailyRhythm: HabitRhythm
    let reminderConfiguration: HabitReminderConfiguration?
    let difficulty: Int?
}

enum HabitTemplateCatalog {
    static let curated: [HabitTemplate] = [
        HabitTemplate(
            id: "drink-water",
            title: "Drink water",
            subtitle: "Stay gently hydrated through the day.",
            icon: "💧",
            accentHex: "6D7E93",
            category: "Wellness",
            notes: "A calm hydration habit that can sit in the background.",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .anytime,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 9, minute: 0))]
            ),
            difficulty: nil
        ),
        HabitTemplate(
            id: "meditate",
            title: "Meditate",
            subtitle: "Begin the day with a quiet reset.",
            icon: "🧘",
            accentHex: "C66A1E",
            category: "Mindfulness",
            notes: "A few minutes of stillness can be enough.",
            schedule: .daily,
            timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)),
            dailyRhythm: .morning,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 8, minute: 0))]
            ),
            difficulty: 2
        ),
        HabitTemplate(
            id: "exercise",
            title: "Exercise",
            subtitle: "Move your body on selected days.",
            icon: "🏃",
            accentHex: "B9775A",
            category: "Fitness",
            notes: "Keep it flexible and sustainable.",
            schedule: .weekly(days: [.monday, .wednesday, .friday]),
            timeMode: .timeWindow(HabitTimeWindow(
                start: HabitClockTime(hour: 6, minute: 0),
                end: HabitClockTime(hour: 9, minute: 0)
            )),
            dailyRhythm: .morning,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 7, minute: 0))]
            ),
            difficulty: 3
        ),
        HabitTemplate(
            id: "walk",
            title: "Walk",
            subtitle: "Step outside and reset the day.",
            icon: "🚶",
            accentHex: "6B8A71",
            category: "Wellness",
            notes: "A short walk counts.",
            schedule: .daily,
            timeMode: .timeWindow(HabitTimeWindow(
                start: HabitClockTime(hour: 12, minute: 0),
                end: HabitClockTime(hour: 18, minute: 0)
            )),
            dailyRhythm: .day,
            reminderConfiguration: nil,
            difficulty: nil
        ),
        HabitTemplate(
            id: "read",
            title: "Read",
            subtitle: "Make a little time for reading.",
            icon: "📖",
            accentHex: "B99363",
            category: "Learning",
            notes: "Even a few pages is enough.",
            schedule: .daily,
            timeMode: .specificTime(HabitClockTime(hour: 21, minute: 0)),
            dailyRhythm: .evening,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 21, minute: 0))]
            ),
            difficulty: nil
        ),
        HabitTemplate(
            id: "journal",
            title: "Journal",
            subtitle: "Capture what matters before the day ends.",
            icon: "✍️",
            accentHex: "B9775A",
            category: "Reflection",
            notes: "Use a sentence or two if that feels right.",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .evening,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 20, minute: 30))]
            ),
            difficulty: nil
        ),
        HabitTemplate(
            id: "stretch",
            title: "Stretch",
            subtitle: "Unwind tension during the day.",
            icon: "🤸",
            accentHex: "C66A1E",
            category: "Mobility",
            notes: "A short stretch break can be enough.",
            schedule: .daily,
            timeMode: .timeWindow(HabitTimeWindow(
                start: HabitClockTime(hour: 13, minute: 0),
                end: HabitClockTime(hour: 16, minute: 0)
            )),
            dailyRhythm: .day,
            reminderConfiguration: nil,
            difficulty: nil
        ),
        HabitTemplate(
            id: "skincare",
            title: "Skincare",
            subtitle: "A soft evening routine.",
            icon: "🫧",
            accentHex: "B9775A",
            category: "Care",
            notes: "Keep the routine simple and repeatable.",
            schedule: .daily,
            timeMode: .specificTime(HabitClockTime(hour: 21, minute: 30)),
            dailyRhythm: .evening,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 21, minute: 30))]
            ),
            difficulty: nil
        ),
        HabitTemplate(
            id: "language-practice",
            title: "Practice a language",
            subtitle: "Show up for a little focused repetition.",
            icon: "🗣️",
            accentHex: "6D7E93",
            category: "Learning",
            notes: "A short session still counts.",
            schedule: .daily,
            timeMode: .allDay,
            dailyRhythm: .day,
            reminderConfiguration: nil,
            difficulty: 2
        ),
        HabitTemplate(
            id: "take-vitamins",
            title: "Take vitamins",
            subtitle: "A tiny ritual for your morning.",
            icon: "💊",
            accentHex: "C66A1E",
            category: "Health",
            notes: "Simple, quick, and easy to remember.",
            schedule: .daily,
            timeMode: .specificTime(HabitClockTime(hour: 8, minute: 0)),
            dailyRhythm: .morning,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 8, minute: 0))]
            ),
            difficulty: nil
        ),
        HabitTemplate(
            id: "sleep-routine",
            title: "Sleep routine",
            subtitle: "Settle into a calmer evening.",
            icon: "🌙",
            accentHex: "6D7E93",
            category: "Rest",
            notes: "A soft sequence that helps the day close.",
            schedule: .daily,
            timeMode: .timeWindow(HabitTimeWindow(
                start: HabitClockTime(hour: 21, minute: 0),
                end: HabitClockTime(hour: 22, minute: 30)
            )),
            dailyRhythm: .evening,
            reminderConfiguration: HabitReminderConfiguration(
                isEnabled: true,
                rules: [.atTime(HabitClockTime(hour: 21, minute: 0))]
            ),
            difficulty: nil
        )
    ]

    static func template(withID id: String) -> HabitTemplate? {
        curated.first { $0.id == id }
    }

    static let onboardingHighlights: [HabitTemplate] = [
        template(withID: "drink-water"),
        template(withID: "meditate"),
        template(withID: "walk")
    ].compactMap { $0 }
}
