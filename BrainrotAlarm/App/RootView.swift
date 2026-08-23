import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: AlarmRouter

    var body: some View {
        TabView {
            AlarmListView()
                .tabItem { Label("Alarms", systemImage: "alarm.fill") }
            RosterView()
                .tabItem { Label("Roster", systemImage: "square.grid.3x3.fill") }
            StatsView()
                .tabItem { Label("Record", systemImage: "chart.bar.fill") }
        }
        .tint(Theme.accent)
        .fullScreenCover(item: Binding(
            get: { ringingContext },
            set: { if $0 == nil { router.clear() } }
        )) { context in
            ChallengeView(context: context)
        }
    }

    /// Resolves a summons into everything the challenge screen needs, dropping it
    /// if the alarm has been deleted since it was scheduled.
    private var ringingContext: RingingContext? {
        guard let summons = router.summons,
              let alarm = store.alarm(id: summons.alarmID) else { return nil }
        return RingingContext(alarm: alarm, firedAt: summons.firedAt)
    }
}

enum Theme {
    static let accent = Color(hex: 0xFF7A45)
    static let background = Color(hex: 0x0E0B14)
    static let surface = Color(hex: 0x1A1522)
    static let surfaceRaised = Color(hex: 0x241D30)
    static let hairline = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.6)
}
