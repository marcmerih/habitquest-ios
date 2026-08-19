import SwiftUI

@main
struct HabitQuestApp: App {
    @UIApplicationDelegateAdaptor(HabitQuestAppDelegate.self) private var appDelegate
    private let environment = HabitQuestEnvironment.live
    @AppStorage(HabitQuestAppearanceMode.storageKey) private var appearanceModeRaw = HabitQuestAppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            AppRootView(environment: environment)
                .preferredColorScheme((HabitQuestAppearanceMode(rawValue: appearanceModeRaw) ?? .system).preferredColorScheme)
        }
    }
}
