import SwiftUI
import SwiftData
import MedReportKit

/// Sheet to add or edit a report (spec 9.5).
struct ReportFormView: View {
    @Environment(ItemStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query private var reports: [Report]
    @Query private var medications: [Medication]

    @State private var model: ReportFormModel
    @State private var showsExpiredConfirmation = false
    @State private var showsSaveError = false
    @State private var isSaving = false
    @State private var didSetDefaults = false

    private let isNew: Bool

    init(report: Report?) {
        isNew = report == nil
        // The settings are not available yet, so the real default is set in `onAppear` for a new report.
        _model = State(initialValue: ReportFormModel(report: report, defaultLeadDays: 18,
                                                     now: Date(), calendar: .current))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Report name", text: $model.title)
                    NameField(text: $model.personName,
                              suggestions: model.suggestions(from: nameUsages(reports: reports, medications: medications)))
                }
                Section {
                    DatePicker("End date", selection: $model.endDate, displayedComponents: .date)
                    Stepper(value: $model.leadDays, in: ReportFormModel.leadDaysRange) {
                        VStack(alignment: .leading) {
                            Text("Remind how many days before")
                            Text("\(model.leadDays) days").foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $model.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isNew ? LocalizedStringKey("New report") : LocalizedStringKey("Edit report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTapped() }
                        .disabled(!model.isValid || isSaving)
                }
            }
            .confirmationDialog("This report looks expired. Save anyway?", isPresented: $showsExpiredConfirmation,
                                titleVisibility: .visible) {
                Button("Save") { Task { await save() } }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Could not save", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
        }
        .onAppear {
            guard !didSetDefaults else { return }
            didSetDefaults = true
            if isNew { model.leadDays = settings.defaultReportLeadDays }
        }
    }

    private func saveTapped() {
        if model.endDateIsPast(now: Date(), calendar: .current) {
            showsExpiredConfirmation = true
        } else {
            Task { await save() }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        model.apply(to: store.context)
        do {
            try await store.save()
            dismiss()
        } catch {
            showsSaveError = true
        }
    }
}
