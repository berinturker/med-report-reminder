import SwiftUI
import MedReportKit

/// Sheet to enter the new end date of a renewed report (spec 8.5).
struct RenewalView: View {
    @Environment(ItemStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newEndDate: Date
    @State private var showsSaveError = false
    @State private var isSaving = false

    private let report: Report

    init(report: Report) {
        self.report = report
        _newEndDate = State(initialValue: Self.defaultDate(for: report, calendar: .current))
    }

    /// Default of the date picker (spec 8.5): previous end + 1 year, 29 Feb → 28 Feb.
    static func defaultDate(for report: Report, calendar: Calendar) -> Date {
        ReminderLogic.suggestedRenewalEndDate(previousEndDate: report.endDate, calendar: calendar)
    }

    var body: some View {
        // A deleted model must not be read; a delete can be in flight while this re-renders.
        if report.isDeleted || report.modelContext == nil {
            Color.clear
        } else {
            NavigationStack {
                Form {
                    DatePicker("New end date", selection: $newEndDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                .navigationTitle("Enter the new end date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .disabled(isSaving)
                    }
                }
                .alert("Could not save", isPresented: $showsSaveError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Please try again.")
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.renew(report, newEndDate: newEndDate)
            dismiss()
        } catch {
            showsSaveError = true
        }
    }
}
