import SwiftUI
import UserNotifications

@main
struct BrainrotAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AlarmStore(scheduler: NotificationScheduler())
    @StateObject private var router = AlarmRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                .task {
                    await store.requestPermissions()
                    await store.reschedule()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        // An AlarmKit stop button may have run in another process.
                        if let handoff = await PendingAlarmHandoff.shared.take() {
                            router.summon(AlarmSummons(alarmID: handoff.alarmID,
                                                       characterID: handoff.characterID,
                                                       firedAt: handoff.firedAt))
                        }
                        await store.reschedule()
                    }
                }
        }
    }
}

/// What the app needs to start ringing: which alarm, and who is chanting.
struct AlarmSummons: Equatable {
    let alarmID: UUID
    let characterID: String
    let firedAt: Date
}

/// Bridges notification callbacks — which arrive on the app delegate — into SwiftUI.
@MainActor
final class AlarmRouter: ObservableObject {
    static let shared = AlarmRouter()

    @Published var summons: AlarmSummons?

    private init() {}

    func summon(_ summons: AlarmSummons) {
        // Ignore a repeat from the same chain; the screen is already up.
        guard self.summons?.alarmID != summons.alarmID else { return }
        self.summons = summons
    }

    func clear() { summons = nil }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// The alarm fired while the app was open.
    ///
    /// Returning an empty set suppresses the system banner and its sound on
    /// purpose: the app is about to take over with its own looping audio, and two
    /// copies of the same chant is worse than one.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        route(notification)
        return []
    }

    /// The user tapped the notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        route(response.notification)
    }

    private func route(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        guard let alarmString = info["alarmID"] as? String,
              let alarmID = UUID(uuidString: alarmString),
              let characterID = info["characterID"] as? String else { return }
        let firedAt = (info["firedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        Task { @MainActor in
            AlarmRouter.shared.summon(AlarmSummons(alarmID: alarmID,
                                                   characterID: characterID,
                                                   firedAt: firedAt))
        }
    }
}
