import SwiftUI
import SwiftData
import MedReportKit

/// Add or edit a medication (spec 9.6). A sheet when new, pushed when existing.
struct MedicationFormView: View {
    @Environment(ItemStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Report> { !$0.isArchived }, sort: \Report.title) private var activeReports: [Report]
    @Query private var reports: [Report]
    @Query private var medications: [Medication]

    @State private var model: MedicationFormModel
    @State private var showsDeleteConfirmation = false
    @State private var showsSaveError = false
    @State private var isSaving = false
    /// Set after a successful delete, so `body` stops reading the deleted model before the dismiss lands.
    @State private var isDeleted = false
    @State private var didSetDefaults = false

    private let medication: Medication?
    private let isNew: Bool
    /// A copy for `body`, which must never read the stored model (it can be deleted while a save is in flight).
    @State private var isArchived: Bool

    init(medication: Medication?, preselectedReport: Report?) {
        self.medication = medication
        isNew = medication == nil
        _isArchived = State(initialValue: medication?.isArchived ?? false)
        // The settings are not available yet, so the real default is set in `onAppear` for a new medication.
        _model = State(initialValue: MedicationFormModel(medication: medication, preselectedReport: preselectedReport,
                                                         defaultLeadDays: 7, now: Date(), calendar: .current))
    }

    /// The active reports, plus the linked one if it is archived, so the picker always has a matching tag.
    private var pickerReports: [Report] {
        if let linked = model.report, !activeReports.contains(where: { $0 === linked }) {
            return [linked] + activeReports
        }
        return activeReports
    }

    var body: some View {
        let title: LocalizedStringKey = isNew ? "New medication" : "Edit medication"
        Group {
            if isDeleted {
                Color.clear
            } else if isNew {
                NavigationStack { form.navigationTitle(title).toolbar { toolbar } }
            } else {
                form.navigationTitle(title).toolbar { toolbar }
            }
        }
        .onAppear {
            guard !didSetDefaults else { return }
            didSetDefaults = true
            if isNew { model.leadDays = settings.defaultMedicationLeadDays }
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField("Medication name", text: $model.name)
                TextField("Dosage note", text: $model.dosageNote)
            }
            Section {
                Picker("Linked report", selection: $model.report) {
                    Text("None").tag(Report?.none)
                    ForEach(pickerReports) { report in
                        Text(report.title).tag(Optional(report))
                    }
                }
                if model.showsPersonField {
                    NameField(text: $model.personName,
                              suggestions: model.suggestions(from: nameUsages(reports: reports, medications: medications)))
                }
            }
            Section {
                DatePicker("Last pickup date", selection: $model.lastPickupDate, displayedComponents: .date)
                VStack(alignment: .leading) {
                    Text("Supply (days)")
                    HStack {
                        ForEach(MedicationFormModel.quickSupplyDays, id: \.self) { days in
                            Button { model.supplyDays = days } label: {
                                Text(verbatim: "\(days)").frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    Stepper(value: $model.supplyDays, in: MedicationFormModel.supplyDaysRange) {
                        Text("\(model.supplyDays) days").foregroundStyle(.secondary)
                    }
                }
                Text("Estimated end: \(model.previewEndDate(calendar: .current).formatted(date: .long, time: .omitted))")
                    .foregroundStyle(.secondary)
                Stepper(value: $model.leadDays, in: MedicationFormModel.leadDaysRange) {
                    VStack(alignment: .leading) {
                        Text("Remind how many days before")
                        Text("\(model.leadDays) days").foregroundStyle(.secondary)
                    }
                }
            }
            if let medication {
                let trackingLabel: LocalizedStringKey = isArchived ? "Resume tracking" : "Stop tracking"
                Section {
                    Button(trackingLabel) {
                        Task { await setArchived(medication, !isArchived) }
                    }
                    Button("Delete medication", role: .destructive) { showsDeleteConfirmation = true }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this medication?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let medication { Task { await delete(medication) } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Could not save", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isNew {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { Task { await save() } }
                .disabled(!model.isValid || isSaving)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        model.apply(to: store.context, calendar: .current)
        do {
            try await store.save()
            dismiss()
        } catch {
            showsSaveError = true
        }
    }

    private func setArchived(_ medication: Medication, _ archived: Bool) async {
        do {
            try await store.setArchived(medication, archived)
            isArchived = archived
            dismiss()
        } catch {
            showsSaveError = true
        }
    }

    private func delete(_ medication: Medication) async {
        do {
            try await store.delete(medication)
            // Hide the form first: the model is gone, so `body` must not read it again.
            isDeleted = true
            dismiss()
        } catch {
            showsSaveError = true
        }
    }
}
