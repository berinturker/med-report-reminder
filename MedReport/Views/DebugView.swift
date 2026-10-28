#if DEBUG
import SwiftUI
import UserNotifications

/// Developer screen, only in debug builds. It shows the pending notifications and lets the
/// developer test the notification flow. Its text is not translated.
struct DebugView: View {
    struct PendingRow: Identifiable, Sendable {
        let id: String
        let fireDate: Date?
    }

    @Environment(ItemStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var rows: [PendingRow] = []
    @State private var fastMode = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { Task { await requestPermission() } } label: { Text(verbatim: "Request permission") }
                    Button { Task { await addSampleReport() } } label: { Text(verbatim: "Add sample report") }
                    Toggle(isOn: $fastMode) { Text(verbatim: "Fast mode (1 day = 1 minute)") }
                        .onChange(of: fastMode) { _, on in
                            guard settings.isFastModeOn != on else { return }
                            settings.isFastModeOn = on
                            Task { try? await store.save(); await reload() }
                        }
                    Button { Task { await reload() } } label: { Text(verbatim: "Refresh") }
                }
                Section {
                    ForEach(rows) { row in
                        VStack(alignment: .leading) {
                            Text(verbatim: row.id).font(.caption.monospaced())
                            Text(verbatim: row.fireDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "-")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text(verbatim: "Pending notifications: \(rows.count)")
                }
            }
            .navigationTitle(Text(verbatim: "Debug"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { fastMode = settings.isFastModeOn }
            .task { await reload() }
        }
    }

    private func requestPermission() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { @Sendable _, _ in
                continuation.resume()
            }
        }
        try? await store.save()
        await reload()
    }

    private func addSampleReport() async {
        let end = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
        store.context.insert(Report(title: "Sample report", endDate: end))
        try? await store.save()
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
#endif
