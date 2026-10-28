import SwiftUI
import SwiftData
import UIKit
import MedReportKit

/// The first screen: upcoming strip, hero card, lists and archive (spec 9.3).
struct HomeView: View {
    @Environment(ItemStore.self) private var store
    @Environment(NavigationRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Query private var reports: [Report]
    @Query private var medications: [Medication]

    @State private var path: [Destination] = []
    @State private var now = Date()
    @State private var sheet: HomeSheet?
    @State private var showsSaveError = false
    @State private var isWorking = false

    private enum HomeSheet: Identifiable {
        case addReport, addMedication, renewal(UUID)
        #if DEBUG
        case debug
        #endif

        var id: String {
            switch self {
            case .addReport: "addReport"
            case .addMedication: "addMedication"
            case .renewal(let id): "renewal-\(id.uuidString)"
            #if DEBUG
            case .debug: "debug"
            #endif
            }
        }
    }

    var body: some View {
        let calendar = Calendar.current
        let sections = HomeSections.make(reports: reports, medications: medications, now: now, calendar: calendar)
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Reminders")
                        .font(Theme.rounded(.largeTitle))
                        .padding(.horizontal, 16)
                    if reports.isEmpty && medications.isEmpty {
                        emptyState
                    } else {
                        content(sections: sections, calendar: calendar)
                    }
                }
                .padding(.vertical, 16)
                // Room for the floating button.
                .padding(.bottom, 72)
            }
            .background(Color(.systemGroupedBackground))
            // The visible title is the rounded heading above; this one is the back button text.
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Replaces the inline title, so the heading is not shown twice.
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .debug } label: {
                        Image(systemName: "ladybug").accessibilityLabel(Text(verbatim: "Debug"))
                    }
                }
                #endif
            }
            .overlay(alignment: .bottomTrailing) { addButton }
            .navigationDestination(for: Destination.self) { destination in
                screen(for: destination)
            }
        }
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
        }
        .alert("Could not save", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
        .onAppear { openPending() }
        .onChange(of: router.pending) { openPending() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        // Midnight, time zone, date or clock change (spec 5.4, 13).
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = Date()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func content(sections: HomeSections, calendar: Calendar) -> some View {
        if !sections.summary.strip.isEmpty {
            UpcomingStrip(items: sections.summary.strip, now: now, calendar: calendar) { item in
                open(kind: item.kind, id: item.id)
            }
        }
        if let hero = sections.summary.hero {
            HeroCard(item: hero, now: now, calendar: calendar, isWorking: isWorking,
                     onOpen: { open(kind: hero.kind, id: hero.id) },
                     onAction: { action in perform(action, on: hero) })
                .padding(.horizontal, 16)
        }
        if !sections.reports.isEmpty {
            list(title: "Reports",
                 items: sections.reports.map { (ReminderItem(report: $0), false) },
                 calendar: calendar)
        }
        if !sections.unlinkedMedications.isEmpty {
            list(title: "Medications without a report",
                 items: sections.unlinkedMedications.map { (ReminderItem(medication: $0, calendar: calendar), false) },
                 calendar: calendar)
        }
        if sections.archiveCount > 0 {
            DisclosureGroup {
                VStack(spacing: 12) {
                    let archived = sections.archivedReports.map { ReminderItem(report: $0) }
                        + sections.archivedMedications.map { ReminderItem(medication: $0, calendar: calendar) }
                    ForEach(archived, id: \.id) { item in
                        cardButton(item: item, isArchived: true, calendar: calendar)
                    }
                }
                .padding(.top, 12)
            } label: {
                Text("Archive (\(sections.archiveCount))")
                    .font(Theme.rounded(.title3))
                    .foregroundStyle(.primary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 16)
        }
    }

    private func list(title: LocalizedStringKey, items: [(ReminderItem, Bool)], calendar: Calendar) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.rounded(.title3))
            ForEach(items, id: \.0.id) { item, isArchived in
                cardButton(item: item, isArchived: isArchived, calendar: calendar)
            }
        }
        .padding(.horizontal, 16)
    }

    private func cardButton(item: ReminderItem, isArchived: Bool, calendar: Calendar) -> some View {
        Button { open(kind: item.kind, id: item.id) } label: {
            ItemCard(item: item, isArchived: isArchived, now: now, calendar: calendar)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Button("Add your first report") { sheet = .addReport }
            .buttonStyle(PrimaryPillButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 32)
    }

    private var addButton: some View {
        Menu {
            Button("Add report") { sheet = .addReport }
            Button("Add medication") { sheet = .addMedication }
        } label: {
            Image(systemName: "plus")
                .font(Theme.rounded(.title2))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 60, height: 60)
                .background(Color.primary, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .accessibilityLabel(Text("Add"))
        .padding(20)
    }

    // MARK: - Screens

    /// Models are fetched by id at render time; a deleted item shows nothing.
    @ViewBuilder
    private func screen(for destination: Destination) -> some View {
        switch destination {
        case .reportDetail(let id), .renewal(let id):
            // A renewal is opened as a sheet over the report detail (see `openPending`), so the path only
            // holds `.renewal` if something appends it directly; the report detail is shown then.
            if let report = Report.find(id, in: store.context) {
                ReportDetailView(report: report)
            } else {
                Color.clear
            }
        case .medicationForm(let id):
            if let medication = Medication.find(id, in: store.context) {
                MedicationFormView(medication: medication, preselectedReport: nil)
            } else {
                Color.clear
            }
        case .home:
            Color.clear
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .addReport:
            ReportFormView(report: nil)
        case .addMedication:
            MedicationFormView(medication: nil, preselectedReport: nil)
        case .renewal(let id):
            if let report = Report.find(id, in: store.context) {
                RenewalView(report: report)
            } else {
                Color.clear
            }
        #if DEBUG
        case .debug:
            DebugView()
        #endif
        }
    }

    // MARK: - Actions

    private func open(kind: ReminderItem.Kind, id: UUID) {
        let destination = Destination.forItem(kind: kind, id: id, in: store.context)
        if destination != .home { path.append(destination) }
    }

    /// Opens the screen of a notification tap and clears it. A missing item opens Home.
    private func openPending() {
        guard let pending = router.pending else { return }
        router.pending = nil
        sheet = nil
        switch pending.resolved(in: store.context) {
        case .home:
            path = []
        case .renewal(let id):
            // RenewalView is a sheet with its own navigation stack; show it over the report detail.
            path = [.reportDetail(id)]
            sheet = .renewal(id)
        case let destination:
            path = [destination]
        }
    }

    /// The primary button of the hero card. The model is fetched by id when tapped.
    private func perform(_ action: PrimaryAction, on item: ReminderItem) {
        switch action {
        case .enterDate:
            sheet = .renewal(item.id)
        case .renewed:
            guard let report = Report.find(item.id, in: store.context) else { return }
            run { try await store.markRenewed(report, now: Date()) }
        case .pickedUp:
            guard let medication = Medication.find(item.id, in: store.context) else { return }
            run { try await store.markPickedUp(medication, now: Date(), calendar: .current) }
        }
    }

    private func run(_ change: @escaping @MainActor () async throws -> Void) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await change()
                now = Date()
            } catch {
                showsSaveError = true
            }
        }
    }
}
