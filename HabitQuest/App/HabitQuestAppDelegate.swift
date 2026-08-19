import UIKit
import UserNotifications

final class HabitQuestAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = HabitQuestNotificationCenterDelegate.shared
        return true
    }
}
