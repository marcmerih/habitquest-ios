import Foundation

protocol HabitRepository {
    func fetchHabits() throws -> [Habit]
    func fetchActiveHabits(on date: Date, calendar: Calendar) throws -> [Habit]
    @discardableResult func createHabit(_ habit: Habit) throws -> Habit
    @discardableResult func updateHabit(_ habit: Habit) throws -> Habit
    func archiveHabit(id: UUID) throws
    func setHabitPaused(id: UUID, isPaused: Bool) throws
    func deleteHabit(id: UUID) throws
}
