import SwiftUI
import MedReportKit

/// One report with its state, medications and actions (spec 9.4).
struct ReportDetailView: View {
    @Environment(ItemStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var sheet: DetailSheet?
    @State private var showsDeleteConfirmation = false
    @State private var showsSaveError = false

    private let report: Report

    init(report: Report) {
        self.report = report
    }

    private enum DetailSheet: Identifiable {
        case edit, renew, addMedication
        case medication(Medication)

        var id: String {
            switch self {
            case .edit: "edit"
            case .renew: "renew"
            case .addMedication: "addMedication"
            case .medication(let medication): "medication-\(medication.id.uuidString)"
            }
        }
    }

    var body: some View {
        // A deleted model must not be read; `ItemStore.delete` awaits a sync after deleting, and this can re-render then.
        if report.isDeleted || report.modelContext == nil {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        let now = Date()
        let calendar = Calendar.current
        let item = ReminderItem(report: report)
        let trackingLabel: LocalizedStringKey = report.isArchived ? "Resume tracking" : "Stop tracking"
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title).font(Theme.rounded(.title2))
                    if !report.personName.isEmpty {
                        Text(report.personName).foregroundStyle(.secondary)
                    }
                }
                stateCard(item: item, now: now, calendar: calendar)
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("End date", value: report.endDate.formatted(date: .long, time: .omitted))
                    if !report.notes.isEmpty {
                        Text("Notes").font(.footnote).foregroundStyle(.secondary)
                        Text(report.notes)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                medicationsSection(now: now, calendar: calendar)
                VStack(spacing: 0) {
                    Button("Add medication") { sheet = .addMedication }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    Button("Edit") { sheet = .edit }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    Button(trackingLabel) { Task { await setArchived(!report.isArchived) } }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    Button("Delete report", role: .destructive) { showsDeleteConfirmation = true }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .card()
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .edit: ReportFormView(report: report)
            case .renew: RenewalView(report: report)
            case .addMedication: MedicationFormView(medication: nil, preselectedReport: report)
            case .medication(let medication):
                NavigationStack { MedicationFormView(medication: medication, preselectedReport: nil) }
            }
        }
        .confirmationDialog("Delete this report?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete report", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The medications linked to this report are also deleted.")
        }
        .alert("Could not save", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    private func stateCard(item: ReminderItem, now: Date, calendar: Calendar) -> some View {
        let action = item.primaryAction(now: now, calendar: calendar)
        return VStack(spacing: 12) {
            if action == .enterDate {
                Text("Enter the new end date").font(Theme.rounded(.title3))
            } else {
                Text(verbatim: "\(item.daysRemaining(now: now, calendar: calendar))")
                    .font(Theme.rounded(.largeTitle))
            }
            StatusBadge(daysRemaining: item.daysRemaining(now: now, calendar: calendar),
                        isHandled: item.isHandled, state: item.state(now: now, calendar: calendar))
            switch action {
            case .renewed:
                Button("Renewed") { Task { await markRenewed() } }
                    .buttonStyle(PrimaryPillButtonStyle())
            case .enterDate:
                Button("Enter date") { sheet = .renew }
                    .buttonStyle(PrimaryPillButtonStyle())
            case .pickedUp, nil:
                EmptyView()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .card()
    }

    @ViewBuilder
    private func medicationsSection(now: Date, calendar: Calendar) -> some View {
        let medications = (report.medications ?? []).sorted { $0.name < $1.name }
        if !medications.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Medications").font(Theme.rounded(.headline)).padding(.vertical, 12)
                ForEach(medications) { medication in
                    let item = ReminderItem(medication: medication, calendar: calendar)
                    Button { sheet = .medication(medication) } label: {
                        HStack {
                            Text(medication.name).foregroundStyle(.primary)
                            Spacer()
                            if medication.isArchived {
                                Text("Tracking stopped").font(.footnote).foregroundStyle(.secondary)
                            } else {
                                StatusBadge(daysRemaining: item.daysRemaining(now: now, calendar: calendar),
                                            isHandled: item.isHandled, state: item.state(now: now, calendar: calendar))
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func markRenewed() async {
        do {
            try await store.markRenewed(report, now: Date())
        } catch {
            showsSaveError = true
        }
    }

    private func setArchived(_ archived: Bool) async {
        do {
            try await store.setArchived(report, archived)
        } catch {
            showsSaveError = true
        }
    }

    private func delete() async {
        do {
            try await store.delete(report)
            dismiss()
        } catch {
            showsSaveError = true
        }
    }
}
