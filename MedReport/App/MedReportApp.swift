import SwiftData
import SwiftUI
import UIKit

@main
struct MedReportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PlaceholderView()
                // Midnight, time zone, date or clock change (spec 5.4, 13).
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await AppEnvironment.shared.sync.sync() }
                }
        }
        .modelContainer(AppEnvironment.shared.container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await AppEnvironment.shared.sync.sync() }
            }
        }
    }
}
