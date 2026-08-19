import Foundation

struct HabitSchedulingEngine {
    func isScheduled(_ habit: Habit, on date: Date, calendar: Calendar = .current) -> Bool {
        habit.isScheduled(on: date, calendar: calendar)
    }

    func isActive(_ habit: Habit, on date: Date, calendar: Calendar = .current) -> Bool {
        habit.isActive(on: date, calendar: calendar)
    }

    func isPaused(_ habit: Habit) -> Bool {
        habit.isPausedHabit()
    }

    func isCurrentlyRelevant(_ habit: Habit, on date: Date, calendar: Calendar = .current) -> Bool {
        habit.isCurrentlyRelevant(on: date, calendar: calendar)
    }

    func rhythm(for habit: Habit) -> HabitRhythm {
        habit.dailyRhythm
    }
}
