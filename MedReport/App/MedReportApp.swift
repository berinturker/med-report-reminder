import SwiftData
import SwiftUI

@main
struct MedReportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            // The unit test host shows an empty view, so `AppEnvironment.shared` is never created.
            if AppEnvironment.isHostingUnitTests {
                Color.clear
            } else {
                AppRootView()
            }
        }
    }
}

/// The real app content, with the shared objects of `AppEnvironment`.
private struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let environment = AppEnvironment.shared

    var body: some View {
        HomeView()
            // Color shows only the state; other buttons are plain (spec 9.1). Sheets inherit it.
            .tint(.primary)
            .environment(environment.store)
            .environment(environment.router)
            .environment(environment.settings)
            .modelContainer(environment.container)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await environment.sync.sync() }
                }
            }
    }
}
