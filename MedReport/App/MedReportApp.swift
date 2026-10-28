import SwiftData
import SwiftUI

@main
struct MedReportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        let environment = AppEnvironment.shared
        WindowGroup {
            HomeView()
                .environment(environment.store)
                .environment(environment.router)
                .environment(environment.settings)
        }
        .modelContainer(environment.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await AppEnvironment.shared.sync.sync() }
            }
        }
    }
}
