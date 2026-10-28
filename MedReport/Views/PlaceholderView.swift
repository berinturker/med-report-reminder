import SwiftUI
import UserNotifications

/// Temporary debug screen until Plan 3 adds the real screens.
/// It shows the pending notifications and lets the developer test the notification flow.
struct PlaceholderView: View {
    struct PendingRow: Identifiable, Sendable {
        let id: String
        let fireDate: Date?
    }

    @State private var rows: [PendingRow] = []
    @State private var fastMode = AppEnvironment.shared.settings.isFastModeOn

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Request permission") { Task { await requestPermission() } }
                    Button("Add sample report") { Task { await addSampleReport() } }
                    #if DEBUG
                    Toggle("Fast mode (1 day = 1 minute)", isOn: $fastMode)
                        .onChange(of: fastMode) { _, on in
                            AppEnvironment.shared.settings.isFastModeOn = on
                            Task { await AppEnvironment.shared.sync.sync(); await reload() }
                        }
                    #endif
                    Button("Refresh") { Task { await reload() } }
                }
                Section("Pending notifications: \(rows.count)") {
                    ForEach(rows) { row in
                        VStack(alignment: .leading) {
                            Text(row.id).font(.caption.monospaced())
                            Text(row.fireDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "-")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("MedReport")
            .task { await reload() }
        }
    }

    private func requestPermission() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { @Sendable _, _ in
                continuation.resume()
            }
        }
        await AppEnvironment.shared.sync.sync()
        await reload()
    }

    private func addSampleReport() async {
        let environment = AppEnvironment.shared
        let end = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
        environment.container.mainContext.insert(Report(title: "Sample report", endDate: end))
        try? await environment.store.save()
        await reload()
    }

    private func reload() async {
        rows = await withCheckedContinuation { (continuation: CheckedContinuation<[PendingRow], Never>) in
            UNUserNotificationCenter.current().getPendingNotificationRequests { @Sendable requests in
                let rows = requests.map { request in
                    let next = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                        ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
                    return PendingRow(id: request.identifier, fireDate: next)
                }
                continuation.resume(returning: rows.sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) })
            }
        }
    }
}
