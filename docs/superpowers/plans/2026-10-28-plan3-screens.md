# Plan 3 — Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the debug placeholder with the real screens: Home, report form, report detail, renewal screen and medication form, in English and Turkish, so the user can add, edit, archive, restore and delete reports and medications.

**Architecture:** The views stay thin (spec 5.5, D7). The decisions live in pure code that has tests: `HomeSummary` and `reminderProgress` in `MedReportKit`, and `HomeSections`, `ItemStore`, `ReportFormModel`, `MedicationFormModel` and `Destination` resolution in the app. `ItemStore` is the only path from a view to a save, and every save is followed by a sync (spec 5.4). Screen text is in a String Catalog; status text still comes from the kit table (D11).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, String Catalog (`Localizable.xcstrings`), XcodeGen, Swift Testing, XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-27-ilac-rapor-design.md` (sections 3.1, 4 Text, 5.5, 6.5, 8.2, 8.5, 9.1, 9.3–9.6, 10, 11 (state labels, delete confirmations), 12, 13 (save failure), 14.4; milestones 3 and 4)

## Global Constraints

- All Plan 2 constraints stay: iOS 17.0, iPhone only, Swift 6, `project.yml` is the source, no third-party SDK, `Date()` / `Calendar.current` only in views and app entry points.
- No view saves the model context directly. Every change goes through `ItemStore` (save, then `ReminderSync`).
- No view decides a state, a day count, a sort order or a validation rule. These come from the kit or from the tested types in this plan.
- Screen text: English is the development language; every string in `Localizable.xcstrings` has a Turkish translation (table below). Debug-only text uses `Text(verbatim:)` and is not in the catalog.
- Status badge text comes from `StatusText.text(daysRemaining:isHandled:language:)` with `AppEnvironment.currentLanguage` (D11).
- Fonts: numbers and headings use `.system(<text style>, design: .rounded)`; body uses the default font. Only text styles, never fixed point sizes (Dynamic Type, spec 11).
- Color shows only the state (spec 9.1): green `normal`, orange `reminding`, red `overdue`, gray `handled`. Everything else uses `.primary`, `.secondary` and system backgrounds. Maximum one black pill primary button per screen.
- Dates on screen use `Date.formatted(date: .long, time: .omitted)`, so the format follows the device region.
- Each delete asks for confirmation (spec 11). Each touch target is at least 44 × 44 pt.
- Not in this plan (Plan 4): settings screen, onboarding, permission banner, privacy manifest, combined VoiceOver card labels, accessibility pass.

### Screen text (English key → Turkish)

| English (catalog key) | Turkish |
|---|---|
| Reminders | Hatırlatmalar |
| Reports | Raporlar |
| Medications without a report | Raporsuz ilaçlar |
| Archive (%lld) | Arşiv (%lld) |
| Add | Ekle |
| Add report | Rapor ekle |
| Add medication | İlaç ekle |
| Add your first report | İlk raporunu ekle |
| Renewed | Yeniledim |
| Picked up | Aldım |
| Enter date | Tarihi gir |
| Enter the new end date | Yeni bitiş tarihini gir |
| End date | Bitiş tarihi |
| Notes | Notlar |
| Medications | İlaçlar |
| Edit | Düzenle |
| Stop tracking | Takibi durdur |
| Resume tracking | Takibi yeniden başlat |
| Tracking stopped | Takip durduruldu |
| Delete report | Raporu sil |
| Delete this report? | Bu rapor silinsin mi? |
| The medications linked to this report are also deleted. | Bu rapora bağlı ilaçlar da silinir. |
| Delete medication | İlacı sil |
| Delete this medication? | Bu ilaç silinsin mi? |
| Delete | Sil |
| Cancel | Vazgeç |
| Save | Kaydet |
| New report | Yeni rapor |
| Edit report | Raporu düzenle |
| Report name | Rapor adı |
| For whom | Kimin için |
| Remind how many days before | Kaç gün önce hatırlatılsın |
| %lld days (plural: en one "%lld day", other "%lld days") | %lld gün |
| This report looks expired. Save anyway? | Bu rapor bitmiş görünüyor, yine de kaydedilsin mi? |
| Could not save | Kaydedilemedi |
| Please try again. | Lütfen tekrar deneyin. |
| OK | Tamam |
| New medication | Yeni ilaç |
| Edit medication | İlacı düzenle |
| Medication name | İlaç adı |
| Dosage note | Doz notu |
| Linked report | Bağlı rapor |
| None | Yok |
| Last pickup date | Son alım tarihi |
| Supply (days) | Kaç günlük |
| Estimated end: %@ | Tahmini bitiş: %@ |
| New end date | Yeni bitiş tarihi |

## Review Focus

1. **A notification tap for an item that was deleted after the notification came** (Plan 2 follow-up). Expected: Home opens, no crash, no empty detail screen. Test: Task 7, `resolvedDestinationOfDeletedItemIsHome`.
2. **The save fails** (spec 13). Expected: an alert; the form keeps the typed data; no half-saved item stays in the context; no sync runs. Test: Task 3, `failedSaveRollsBackAndDoesNotSync`.
3. **The app stays open across midnight** (spec 14.5). Expected: the days on Home change without a restart. Test: Task 3, `sectionsUseTheGivenNow`; the view re-reads `now` on `significantTimeChangeNotification` and on `scenePhase == .active` (Task 7).
4. **A title of only spaces, or a person name with spaces around it** (spec 10, 12). Expected: Save is disabled; the saved name is trimmed. Tests: Task 4, `titleOfOnlySpacesIsInvalid`, `applyTrimsTitleAndPerson`.
5. **The user edits an item and then taps Cancel.** Expected: the stored item does not change. Tests: Task 4, `editWithoutApplyLeavesReportUnchanged`; Task 5, `editWithoutApplyLeavesMedicationUnchanged`.

---

## File Structure

```
Packages/MedReportKit/Sources/MedReportKit/
├── ReminderLogic.swift                       (Task 1, add reminderProgress)
└── HomeSummary.swift                         (Task 1)
Packages/MedReportKit/Tests/MedReportKitTests/HomeSummaryTests.swift   (Task 1)
project.yml                                   (Task 2 regions; Task 8 UI test target)
scripts/check-strings.py                      (Task 2)
.github/workflows/ci.yml                      (Task 2, run check-strings)
MedReport/
├── App/MedReportApp.swift                    (Task 7, Task 8)
├── App/AppDelegate.swift                     (Task 7, Task 8)
├── App/AppEnvironment.swift                  (Task 3, Task 8)
├── Resources/Localizable.xcstrings           (Task 2, rows added in Tasks 4–7)
├── Data/ItemStore.swift                      (Task 3)
├── Data/HomeSections.swift                   (Task 3)
├── Data/NameUsages.swift                     (Task 4)
├── Forms/ReportFormModel.swift               (Task 4)
├── Forms/MedicationFormModel.swift           (Task 5)
├── Models/Report.swift                       (Task 3, markHandled clears snooze)
├── Notifications/NavigationRouter.swift      (Task 7)
├── Notifications/NotificationActionHandler.swift (Task 3, Task 7)
└── Views/
    ├── Theme.swift                           (Task 2)
    ├── Components/StatusBadge.swift          (Task 2)
    ├── Components/RingView.swift             (Task 2)
    ├── Components/NameField.swift            (Task 4)
    ├── ReportFormView.swift                  (Task 4)
    ├── MedicationFormView.swift              (Task 5)
    ├── ReportDetailView.swift                (Task 6)
    ├── RenewalView.swift                     (Task 6)
    ├── Home/HomeView.swift                   (Task 7)
    ├── Home/UpcomingStrip.swift              (Task 7)
    ├── Home/HeroCard.swift                   (Task 7)
    ├── Home/ItemCard.swift                   (Task 7)
    └── DebugView.swift                       (Task 7, renamed from PlaceholderView.swift)
MedReportTests/
├── LocalizationTests.swift                   (Task 2)
├── ItemStoreTests.swift                      (Task 3)
├── HomeSectionsTests.swift                   (Task 3)
├── ReportFormModelTests.swift                (Task 4)
├── MedicationFormModelTests.swift            (Task 5)
├── RenewalTests.swift                        (Task 6)
└── DestinationTests.swift                    (Task 7)
MedReportUITests/ReportLifecycleUITests.swift (Task 8)
```

**How to run tests:** "**Run kit tests**" = `swift test --package-path Packages/MedReportKit`. "**Run app tests**" = `xcodegen generate && ./scripts/ci-app-tests.sh` on a Mac, or push and read the `app-tests` CI job (`gh run list --branch <branch>`, `gh run view <id> --log-failed`). "Expected: FAIL" means the named test fails or the build fails at the named symbol.

---

### Task 1: Home summary and ring progress (kit)

**Files:**
- Modify: `Packages/MedReportKit/Sources/MedReportKit/ReminderLogic.swift`
- Create: `Packages/MedReportKit/Sources/MedReportKit/HomeSummary.swift`
- Test: `Packages/MedReportKit/Tests/MedReportKitTests/HomeSummaryTests.swift`

**Interfaces:**
- Consumes: `ReminderItem`, `ReminderItem.sortedByUrgency`, `ReminderState`.
- Produces:

```swift
extension ReminderLogic {
    /// Part of the reminder period that is past, 0...1 (spec 9.3). Normal → 0, overdue → 1, handled → 1.
    public static func reminderProgress(endDate: Date, leadDays: Int, isHandled: Bool, now: Date, calendar: Calendar) -> Double
}
public enum PrimaryAction: Sendable, Equatable { case renewed, pickedUp, enterDate }
extension ReminderItem {
    public func progress(now: Date, calendar: Calendar) -> Double
    /// report reminding/overdue → .renewed; medication reminding/overdue → .pickedUp;
    /// handled → .enterDate; normal → nil (spec 9.3 hero, 9.4 state card)
    public func primaryAction(now: Date, calendar: Calendar) -> PrimaryAction?
}
public struct HomeSummary: Sendable, Equatable {
    public static let stripLimit = 8
    public let strip: [ReminderItem]   // first 8 of sortedByUrgency
    public let hero: ReminderItem?     // first of sortedByUrgency; nil when there are no items
    public static func make(items: [ReminderItem], now: Date, calendar: Calendar) -> HomeSummary
}
```

The spec's "if no item needs attention, show the item with the nearest end date" needs no extra rule: when all items are normal, `sortedByUrgency` already puts the nearest end date first, and `primaryAction` is nil, so the hero has no button.

- [ ] **Step 1: Write the failing tests** (now = `date(2026, 10, 27)`, `lead` 10 unless stated)

```swift
@Test func progressAcrossThePeriod() {
    func p(_ end: Date, lead: Int = 10, handled: Bool = false) -> Double {
        ReminderLogic.reminderProgress(endDate: end, leadDays: lead, isHandled: handled, now: now, calendar: istanbul)
    }
    #expect(p(date(2026, 11, 20)) == 0)              // 24 days, normal
    #expect(p(date(2026, 11, 6)) == 0)               // 10 days, first reminder day
    #expect(p(date(2026, 11, 1)) == 0.5)             // 5 of 10
    #expect(p(date(2026, 10, 27)) == 1)              // ends today
    #expect(p(date(2026, 10, 20)) == 1)              // overdue
    #expect(p(date(2026, 10, 27), lead: 0) == 1)
    #expect(p(date(2026, 10, 28), lead: -3) == 0)    // negative lead acts as 0: 1 day left is normal
    #expect(p(date(2026, 11, 20), handled: true) == 1)
}

@Test func primaryActionByKindAndState() {
    #expect(report(1, end: date(2026, 11, 1)).primaryAction(now: now, calendar: istanbul) == .renewed)
    #expect(report(2, end: date(2026, 10, 20)).primaryAction(now: now, calendar: istanbul) == .renewed)
    #expect(report(3, end: date(2026, 10, 20), handledAt: date(2026, 10, 21)).primaryAction(now: now, calendar: istanbul) == .enterDate)
    #expect(medication(4, end: date(2026, 10, 30)).primaryAction(now: now, calendar: istanbul) == .pickedUp)
    #expect(report(5, end: date(2027, 6, 1)).primaryAction(now: now, calendar: istanbul) == nil)
}

@Test func summaryKeepsEightAndHeroIsFirst() {
    let items = (1...10).map { medication($0, end: date(2026, 11, 10 + $0)) } + [report(11, end: date(2026, 10, 25))]
    let s = HomeSummary.make(items: items, now: now, calendar: istanbul)
    #expect(s.strip.count == 8)
    #expect(s.strip.first?.id == uuid(11))
    #expect(s.hero?.id == uuid(11))
}

@Test func summaryOfNoItemsIsEmpty() {
    let s = HomeSummary.make(items: [], now: now, calendar: istanbul)
    #expect(s.strip.isEmpty && s.hero == nil)
}
```

- [ ] **Step 2: Run kit tests** — Expected: FAIL (`reminderProgress`, `HomeSummary` not found).
- [ ] **Step 3: Implement.** Reminding: `Double(lead - daysRemaining) / Double(lead)` with `lead = max(leadDays, 0)`; when `lead == 0` the reminding state is day 0 only, so return 1.
- [ ] **Step 4: Run kit tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(kit): home summary, primary action and ring progress"`

---

### Task 2: String Catalog, theme and state components

**Files:**
- Modify: `project.yml` (`options.developmentLanguage: en`; the catalog is picked up from `MedReport/`)
- Create: `MedReport/Resources/Localizable.xcstrings`, `scripts/check-strings.py`, `MedReport/Views/Theme.swift`, `MedReport/Views/Components/StatusBadge.swift`, `MedReport/Views/Components/RingView.swift`
- Modify: `.github/workflows/ci.yml` (step `python3 scripts/check-strings.py` in `app-tests`, before the tests)
- Test: `MedReportTests/LocalizationTests.swift`

**Interfaces:**
- Consumes: `ReminderState`, `StatusText`, `AppLanguage`.
- Produces:

```swift
extension ReminderState {
    var color: Color          // .green / .orange / .red / .gray (spec 6.6)
}
enum Theme {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font
}
struct CardBackground: ViewModifier   // white card (secondarySystemGroupedBackground), corner radius 24
extension View { func card() -> some View }
struct PrimaryPillButtonStyle: ButtonStyle   // black (.primary) capsule, inverted label, min height 50
struct StatusBadge: View { init(daysRemaining: Int, isHandled: Bool, state: ReminderState) }   // colored dot + StatusText
struct RingView: View { init(progress: Double, state: ReminderState, centerText: String?) }   // trimmed circle stroke in state.color
```

Page background: `Color(.systemGroupedBackground)` (light gray, dark in dark mode, spec 9.1).

- [ ] **Step 1: Write the failing tests**

```swift
@Test func turkishTranslationIsBundled() throws {
    let path = try #require(Bundle.main.path(forResource: "tr", ofType: "lproj"))
    let tr = try #require(Bundle(path: path))
    #expect(tr.localizedString(forKey: "Reminders", value: nil, table: nil) == "Hatırlatmalar")
}

@Test func stateColorsMatchSpec() {
    #expect(ReminderState.normal.color == .green)
    #expect(ReminderState.reminding.color == .orange)
    #expect(ReminderState.overdue.color == .red)
    #expect(ReminderState.handled.color == .gray)
}
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (no `tr.lproj`; `color` not found).
- [ ] **Step 3: Implement.** Add the catalog with the first row of the screen text table (`Reminders`); Tasks 4–7 add the rows their views use. `check-strings.py` reads the catalog JSON and exits 1 with the key names when an entry has no `tr` localization with `state == "translated"` and a non-empty value (for plural entries, every `tr` variation). It skips entries with `"shouldTranslate": false`.
- [ ] **Step 4: Run app tests and `python3 scripts/check-strings.py`** — Expected: PASS; the script prints nothing and exits 0.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): string catalog, theme, status badge and ring"`

---

### Task 3: `ItemStore` and `HomeSections`

**Files:**
- Create: `MedReport/Data/ItemStore.swift`, `MedReport/Data/HomeSections.swift`
- Modify: `MedReport/Models/Report.swift` (`markHandled(at:)` also sets `snoozeUntil = nil`, spec 8.3), `MedReport/Notifications/NotificationActionHandler.swift` (remove its extra `snoozeUntil = nil` line), `MedReport/App/AppEnvironment.swift` (add `let store: ItemStore`; remove `saveAndSync()`; `PlaceholderView` calls `store.save()`)
- Test: `MedReportTests/ItemStoreTests.swift`, `MedReportTests/HomeSectionsTests.swift`

**Interfaces:**
- Consumes: `ReminderSync`, `ReminderItem.active`, `HomeSummary` (Task 1).
- Produces:

```swift
@MainActor @Observable
final class ItemStore {
    /// `saveContext` is for tests; the default calls `context.save()`.
    init(container: ModelContainer, sync: ReminderSync, saveContext: ((ModelContext) throws -> Void)? = nil)
    var context: ModelContext { get }
    /// Save, then sync. On failure: `context.rollback()`, rethrow, no sync (spec 13).
    func save() async throws
    func markRenewed(_ report: Report, now: Date) async throws
    func markPickedUp(_ medication: Medication, now: Date, calendar: Calendar) async throws
    func renew(_ report: Report, newEndDate: Date) async throws
    func setArchived(_ report: Report, _ archived: Bool) async throws
    func setArchived(_ medication: Medication, _ archived: Bool) async throws
    func delete(_ report: Report) async throws      // cascade deletes its medications
    func delete(_ medication: Medication) async throws
}

struct HomeSections {
    let summary: HomeSummary
    let reports: [Report]                    // not archived, by endDate, then title, then createdAt
    let unlinkedMedications: [Medication]    // report == nil, not archived, by supply end, then name, then createdAt
    let archivedReports: [Report]            // isArchived, by endDate
    let archivedMedications: [Medication]    // report == nil && isArchived, by supply end
    var archiveCount: Int { get }
    static func make(reports: [Report], medications: [Medication], now: Date, calendar: Calendar) -> HomeSections
}
```

A linked medication that the user archived on its own stays out of the Home lists and the archive; the report detail lists it with "Tracking stopped" (Task 6).

- [ ] **Step 1: Write the failing tests** (use `makeContainer()`, `FakeNotificationCenter`, a `ReminderSync` as in `NotificationActionHandlerTests.make()`)

`ItemStoreTests`:
```swift
@Test func saveSyncs()                       // insert a report, save → center.added is not empty
@Test func markRenewedClearsSnoozeAndSyncs() // snoozeUntil set → nil; isHandled; added ids have prefix "renewal-" or are "backup"
@Test func archiveAndRestoreReport()         // report with a linked medication: archive → no added id contains either uuid; restore → both come back
@Test func deleteReportDeletesItsMedications() // fetch counts 0 and 0; no added id contains the report uuid
@Test func failedSaveRollsBackAndDoesNotSync() async throws {
    let env = try make(saveContext: { _ in throw CocoaError(.validationMissingMandatoryProperty) })
    env.store.context.insert(Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5)))
    await #expect(throws: CocoaError.self) { try await env.store.save() }
    #expect(try env.store.context.fetchCount(FetchDescriptor<Report>()) == 0)
    #expect(env.center.removeAllCount == 0)
}
```

`HomeSectionsTests` (now = `date(2026, 10, 27)`):
```swift
@Test func reportsByEndDateAndArchivedApart()       // 3 reports, one archived → reports order by endDate; archivedReports == [archived]
@Test func unlinkedMedicationsBySupplyEnd()         // linked med is not in unlinkedMedications but is in summary.strip
@Test func medicationOfArchivedReportIsNowhere()    // not in unlinked, not in archivedMedications, not in summary
@Test func archiveCountCountsReportsAndUnlinkedMedications()
@Test func sectionsUseTheGivenNow() {
    // one report ending 2026-10-28: with now 2026-10-27 23:59 hero days == 1; with now 2026-10-28 00:01 hero days == 0
}
```

Also extend `ModelTests.pickupAndRenewClearSnooze` with `markHandled` clearing `snoozeUntil`.

- [ ] **Step 2: Run app tests** — Expected: FAIL (`ItemStore`, `HomeSections` not found).
- [ ] **Step 3: Implement.** `AppEnvironment` creates `store = ItemStore(container: container, sync: sync)`.
- [ ] **Step 4: Run app tests** — Expected: PASS (all Plan 2 suites stay green).
- [ ] **Step 5: Commit** — `git commit -m "feat(app): item store and home sections"`

---

### Task 4: Report form

**Files:**
- Create: `MedReport/Data/NameUsages.swift`, `MedReport/Forms/ReportFormModel.swift`, `MedReport/Views/Components/NameField.swift`, `MedReport/Views/ReportFormView.swift`
- Modify: `MedReport/Resources/Localizable.xcstrings` (rows: New report, Edit report, Report name, For whom, End date, Remind how many days before, %lld days, Notes, Save, Cancel, This report looks expired. Save anyway?, Could not save, Please try again., OK)
- Test: `MedReportTests/ReportFormModelTests.swift`

**Interfaces:**
- Consumes: `ItemStore` (Task 3), `PersonNameSuggester`, `NameUsage`, `ReminderLogic.daysRemaining`.
- Produces:

```swift
/// Person names of all reports and of medications without a report; `usedAt` = `createdAt` (spec 10).
func nameUsages(reports: [Report], medications: [Medication]) -> [NameUsage]

@MainActor @Observable
final class ReportFormModel {
    static let leadDaysRange = 0...90                 // spec 12
    let original: Report?                             // nil = new report
    var title: String
    var personName: String
    var endDate: Date                                 // new report: start of today
    var leadDays: Int                                 // new report: settings.defaultReportLeadDays
    var notes: String
    init(report: Report?, defaultLeadDays: Int, now: Date, calendar: Calendar)
    var isValid: Bool                                 // trimmed title not empty && leadDays in range
    func endDateIsPast(now: Date, calendar: Calendar) -> Bool
    func suggestions(from usages: [NameUsage]) -> [String]   // PersonNameSuggester.suggestions(for: personName, ...)
    /// Writes the trimmed values into `original`, or inserts a new Report into `context`. Does not save.
    @discardableResult func apply(to context: ModelContext) -> Report
}

struct NameField: View { init(text: Binding<String>, suggestions: [String]) }   // TextField + tappable suggestion rows under it
```

`ReportFormView(report: Report?)`: a sheet with a `NavigationStack`, toolbar Cancel and Save (Save disabled when `!isValid`). Fields in spec 9.5 order; `Stepper` for lead days with the "%lld days" value. Save: if `endDateIsPast` show a confirmation dialog with "This report looks expired. Save anyway?"; then `apply` + `store.save()`; on throw show the "Could not save" alert and keep the sheet open.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func newReportUsesDefaults()          // original == nil, title "", endDate == startOfDay(now), leadDays == 21 when defaultLeadDays 21
@Test func titleOfOnlySpacesIsInvalid() {   // "   " → false; "Tansiyon raporu" → true; leadDays 91 → false
}
@Test func applyTrimsTitleAndPerson() {     // "  Tansiyon raporu " / " Babam " → inserted Report has "Tansiyon raporu" / "Babam"
}
@Test func editWithoutApplyLeavesReportUnchanged() {
    // model on an existing report; change title, endDate, leadDays; do not apply → the report keeps its old values
}
@Test func applyUpdatesTheOriginal()        // existing report: apply → same id, new values, fetchCount still 1
@Test func pastEndDateIsDetected()          // endDate yesterday → true; today → false
@Test func nameUsagesSkipLinkedMedications() // report "Babam", linked med person "X" (ignored), unlinked med "Annem" → names ["Babam", "Annem"] in any order
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (`ReportFormModel` not found).
- [ ] **Step 3: Implement the model, `nameUsages`, `NameField` and the view.** Add the catalog rows with the Turkish text from the table.
- [ ] **Step 4: Run app tests and `check-strings.py`** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): report form with validation and name suggestions"`

---

### Task 5: Medication form

**Files:**
- Create: `MedReport/Forms/MedicationFormModel.swift`, `MedReport/Views/MedicationFormView.swift`
- Modify: `MedReport/Resources/Localizable.xcstrings` (rows: New medication, Edit medication, Medication name, Dosage note, Linked report, None, Last pickup date, Supply (days), Estimated end: %@, Stop tracking, Resume tracking, Delete medication, Delete this medication?, Delete, Add medication)
- Test: `MedReportTests/MedicationFormModelTests.swift`

**Interfaces:**
- Consumes: `ItemStore`, `NameField`, `nameUsages` (Task 4), `ReminderLogic.supplyEndDate`.
- Produces:

```swift
@MainActor @Observable
final class MedicationFormModel {
    static let supplyDaysRange = 1...365              // spec 12
    static let quickSupplyDays = [30, 60, 90]         // spec 9.6
    let original: Medication?
    var name: String
    var dosageNote: String
    var report: Report?                               // nil = "None"
    var personName: String                            // shown only when report == nil
    var lastPickupDate: Date                          // new: start of today
    var supplyDays: Int                               // new: 30
    var leadDays: Int                                 // new: settings.defaultMedicationLeadDays
    init(medication: Medication?, preselectedReport: Report?, defaultLeadDays: Int, now: Date, calendar: Calendar)
    var showsPersonField: Bool                        // report == nil
    var isValid: Bool                                 // trimmed name not empty, supplyDays and leadDays in range
    func previewEndDate(calendar: Calendar) -> Date   // ReminderLogic.supplyEndDate
    func suggestions(from usages: [NameUsage]) -> [String]
    /// Trims name and person; lastPickupDate → start of day; with a report, personName is saved as "". Does not save.
    @discardableResult func apply(to context: ModelContext, calendar: Calendar) -> Medication
}
```

`MedicationFormView(medication: Medication?, preselectedReport: Report?)`: fields in spec 9.6 order. "Linked report" is a `Picker` over the reports that are not archived plus "None". "Supply (days)" has three quick buttons (`Text(verbatim: "30")` etc.) and a `Stepper`. Under the dates: "Estimated end: %@" with `previewEndDate` formatted. For an existing medication: "Stop tracking" / "Resume tracking" (`store.setArchived`) and "Delete medication" in red with a confirmation dialog. As a new item it is a sheet with Cancel/Save; as an existing item it is pushed (Task 7) and has Save only.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func newMedicationDefaults()          // supplyDays 30, leadDays from default, lastPickupDate == startOfDay(now), report == preselected
@Test func previewIsPickupPlusSupply()      // pickup 2026-10-01, supply 60 → startOfDay(2026-11-30)
@Test func validation()                     // name "  " false; supplyDays 0 false; 366 false; 365 true; leadDays 91 false
@Test func linkingAReportClearsOwnPerson()  // personName "Babam", report set → apply → personName == "", report linked
@Test func unlinkingUsesOwnPerson()         // existing linked med; report = nil, personName " Annem " → apply → report nil, personName "Annem", effectivePersonName "Annem"
@Test func editWithoutApplyLeavesMedicationUnchanged()
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (`MedicationFormModel` not found).
- [ ] **Step 3: Implement the model and the view.** Add the catalog rows.
- [ ] **Step 4: Run app tests and `check-strings.py`** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): medication form with live end date preview"`

---

### Task 6: Report detail and renewal screen

**Files:**
- Create: `MedReport/Views/ReportDetailView.swift`, `MedReport/Views/RenewalView.swift`
- Modify: `MedReport/Resources/Localizable.xcstrings` (rows: Enter the new end date, Renewed, Enter date, Medications, Edit, Tracking stopped, Delete report, Delete this report?, The medications linked to this report are also deleted., New end date)
- Test: `MedReportTests/RenewalTests.swift`

**Interfaces:**
- Consumes: `ItemStore`, `ReminderItem(report:)`, `ReminderItem(medication:calendar:)`, `primaryAction`, `StatusBadge`, `RingView`, `ReportFormView`, `MedicationFormView`, `ReminderLogic.suggestedRenewalEndDate`.
- Produces:

```swift
struct ReportDetailView: View { init(report: Report) }
struct RenewalView: View {
    init(report: Report)
    /// Default of the date picker (spec 8.5): previous end + 1 year, 29 Feb → 28 Feb.
    static func defaultDate(for report: Report, calendar: Calendar) -> Date
}
```

`ReportDetailView` (spec 9.4), top to bottom: title and person; a state card (`card()`) with the big day number, `StatusBadge`, and one primary button from `primaryAction`: `.renewed` → "Renewed" (`store.markRenewed`), `.enterDate` → the card text "Enter the new end date" and the button "Enter date" (opens `RenewalView` as a sheet); end date and notes; "Medications" with each linked medication (name, `StatusBadge`, or "Tracking stopped" when `isArchived`), a tap opens its form; buttons "Add medication" (medication form sheet with `preselectedReport`), "Edit" (report form sheet), "Stop tracking" / "Resume tracking"; at the bottom "Delete report" in red with the confirmation title "Delete this report?" and message "The medications linked to this report are also deleted.", then `store.delete` and dismiss.

`RenewalView`: a graphical `DatePicker` "New end date" with `defaultDate`, Cancel and Save; Save → `store.renew(report, newEndDate:)` and dismiss; on throw, the "Could not save" alert.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func renewalDefaultIsOneYearLater()   // end 2026-11-05 → startOfDay(2027-11-05)
@Test func renewalDefaultOnLeapDay()        // end 2028-02-29 → startOfDay(2029-02-28)
@Test func renewThroughStoreStartsANewCycle() async throws {
    // handled report with snooze; store.renew(newEndDate: 2027-11-05) → isHandled false, handledAt nil,
    // snoozeUntil nil, added ids include "report-<uuid>-…" and none "renewal-…"
}
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (`RenewalView` not found).
- [ ] **Step 3: Implement both views.** Add the catalog rows.
- [ ] **Step 4: Run app tests and `check-strings.py`** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): report detail and renewal screen"`

---

### Task 7: Home, navigation and app wiring

**Files:**
- Create: `MedReport/Views/Home/HomeView.swift`, `UpcomingStrip.swift`, `HeroCard.swift`, `ItemCard.swift`
- Move: `MedReport/Views/PlaceholderView.swift` → `MedReport/Views/DebugView.swift` (type `DebugView`, all text `verbatim`, shown only under `#if DEBUG`)
- Modify: `MedReport/Notifications/NavigationRouter.swift`, `MedReport/Notifications/NotificationActionHandler.swift`, `MedReport/App/MedReportApp.swift`, `MedReport/App/AppDelegate.swift`, `MedReport/Resources/Localizable.xcstrings` (rows: Reports, Medications without a report, Archive (%lld), Add, Add report, Add your first report, Picked up)
- Test: `MedReportTests/DestinationTests.swift`

**Interfaces:**
- Consumes: everything above.
- Produces:

```swift
enum Destination: Hashable, Sendable { /* the same four cases */ }
extension Destination {
    /// The screen for one item (spec 8.2): report → .reportDetail; medication → its report's detail,
    /// or .medicationForm when it has no report; an id that does not exist → .home.
    @MainActor static func forItem(kind: ReminderItem.Kind, id: UUID, in context: ModelContext) -> Destination
    /// .home when the report or medication of this destination does not exist (Plan 2 follow-up).
    @MainActor func resolved(in context: ModelContext) -> Destination
}
```

`NotificationActionHandler.handleTap` does not change: it routes to the id also when the item is missing (the existing `tapRoutes` test stays), and `HomeView` calls `resolved` when it shows the screen.

`HomeView` (spec 9.3): `NavigationStack(path: $path)` with `path: [Destination]` and `.navigationDestination(for: Destination.self)`. `@Query` all reports and medications; `HomeSections.make(..., now: now, calendar: .current)`. `@State now = Date()` is reset on `scenePhase == .active` and on `UIApplication.significantTimeChangeNotification` (Review Focus 3). On appear and on each change of `router.pending`: take the value, set `router.pending = nil`, then `path = []` for `.home` or `[destination.resolved(in: context)]` otherwise (a resolved `.home` also gives `[]`). Layout top to bottom: title "Reminders" (large, rounded); toolbar under `#if DEBUG` a button that opens `DebugView` as a sheet; `UpcomingStrip` (hidden when empty) — horizontal `RingView`s with the day number, the title under each and the `StatusBadge` text, a tap navigates with `Destination.forItem`; `HeroCard` — person, title, large day number, ring, and the primary button ("Renewed" / "Picked up" / "Enter date") calling the store, or opening `RenewalView` for `.enterDate`; section "Reports" with `ItemCard`s; section "Medications without a report"; a collapsed `DisclosureGroup` "Archive (%lld)" listing `archivedReports` and `archivedMedications`; empty state (no items at all) — the primary button "Add your first report"; a floating black circular "+" button (accessibility label "Add") at the bottom right with a `Menu`: "Add report", "Add medication" (sheets). When the empty state is shown, the hero card is hidden, so the screen still has one primary button.

`MedReportApp`: `HomeView()` as the root, `.environment(store)`, `.environment(router)`, `.environment(settings)`. Remove the `.onReceive(significantTimeChangeNotification)` sync from the scene and add `applicationSignificantTimeChange(_:)` in `AppDelegate`, which starts `sync()` (Plan 2 follow-up). The views read `ItemStore`, `NavigationRouter` and `AppSettings` from the environment, not from `AppEnvironment.shared`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func forItemRoutesByKind()            // report → .reportDetail(r.id); linked med → .reportDetail(r.id); unlinked med → .medicationForm(m.id); uuid(99) → .home
@Test func resolvedDestinationOfDeletedItemIsHome() throws {
    // insert and save a report and an unlinked medication, then delete both and save
    #expect(Destination.reportDetail(r.id).resolved(in: context) == .home)
    #expect(Destination.renewal(r.id).resolved(in: context) == .home)
    #expect(Destination.medicationForm(m.id).resolved(in: context) == .home)
}
@Test func resolvedKeepsExistingItems()     // existing report → same destination
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (`forItem`, `resolved` not found).
- [ ] **Step 3: Implement the router extension, the four Home views and the wiring.** Add the catalog rows.
- [ ] **Step 4: Run app tests and `check-strings.py`** — Expected: PASS.
- [ ] **Step 5: Manual check in the simulator** — run the app in English and in Turkish (scheme App Language): add a report and a medication, open them from the strip, the hero and the lists, archive and restore, delete. Use the largest Dynamic Type size once; no text is cut. Debug menu → fast mode → a notification tap opens the correct screen; delete the item, tap an old notification → Home.
- [ ] **Step 6: Commit** — `git commit -m "feat(app): home screen, navigation and app wiring"`

---

### Task 8: UI test and test launch modes

**Files:**
- Modify: `project.yml` (target `MedReportUITests`, `type: bundle.ui-testing`, `dependencies: [target: MedReport]`, `GENERATE_INFOPLIST_FILE: YES`, bundle id `com.berinturker.medreport.uitests`; add it to the scheme's test targets)
- Modify: `MedReport/App/AppEnvironment.swift`, `MedReport/App/MedReportApp.swift`, `MedReport/App/AppDelegate.swift`
- Create: `MedReportUITests/ReportLifecycleUITests.swift`
- Modify: `MedReportTests/SmokeTests.swift`

**Interfaces:**
- Produces:

```swift
extension AppEnvironment {
    /// True in the app process that hosts the unit tests (`XCTestConfigurationFilePath` is set).
    nonisolated static var isHostingUnitTests: Bool { get }
    /// True when the app was launched with the argument "-uiTesting".
    nonisolated static var isUITesting: Bool { get }
}
```

- When `isHostingUnitTests`: `AppDelegate` returns `true` at once and the scene shows an empty view, so `AppEnvironment.shared` (on-disk store, real notification center) is never created (Plan 2 follow-up).
- When `isUITesting`: the store is in memory and `AppSettings` uses the suite `"uiTesting"`, cleared at launch.
- The on-disk store uses `ModelConfiguration(cloudKitDatabase: .none)` until iCloud sync is a decision (Plan 2 follow-up).

- [ ] **Step 1: Write the UI test and the smoke assertion**

```swift
// ReportLifecycleUITests (spec 14.4)
func testAddSeeAndDeleteReport() {
    let app = XCUIApplication()
    app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    app.buttons["Add"].tap()
    app.buttons["Add report"].tap()
    let name = app.textFields["Report name"]
    name.tap(); name.typeText("Blood pressure report")
    app.buttons["Save"].tap()
    let card = app.staticTexts["Blood pressure report"].firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    card.tap()
    app.buttons["Delete report"].tap()
    app.buttons["Delete"].firstMatch.tap()
    XCTAssertFalse(app.staticTexts["Blood pressure report"].waitForExistence(timeout: 2))
}
```

In `SmokeTests.appModuleLoads`, add `#expect(AppEnvironment.isHostingUnitTests)`.

- [ ] **Step 2: Run app tests** — Expected: FAIL (`isHostingUnitTests` not found; the UI test target is new).
- [ ] **Step 3: Implement the launch modes.** The new report's default end date is today, so the UI test does not get the expired warning. Use `.accessibilityIdentifier` only if a label does not match.
- [ ] **Step 4: Run app tests** — Expected: PASS, including `testAddSeeAndDeleteReport`. If the UI test runner does not start with `CODE_SIGNING_ALLOWED=NO`, change `scripts/ci-app-tests.sh` to pass `CODE_SIGN_IDENTITY=-` for the simulator and run again.
- [ ] **Step 5: Update `docs/superpowers/followups.md`** — remove the five Plan 2 items that this plan closed (deleted-item tap, hosted test app, significant-time-change observer, `cloudKitDatabase`, and the "Plan 3 must do" item).
- [ ] **Step 6: Commit** — `git commit -m "test(app): report lifecycle UI test and test launch modes"`

---

## Spec coverage of this plan

| Spec item | Task |
|---|---|
| 3.1 Add, edit, archive, restore, delete reports and medications | 3, 4, 5, 6, 7 |
| 4 Text: String Catalog, English base, Turkish translation | 2, 4–7 |
| 5.5 Views; form models | 4, 5, 6, 7 |
| 6.5 Calculated values on screen (effective person, effective archive, days) | 3, 5 |
| 8.2 Tap routing, incl. deleted items | 7 |
| 8.5 Renewal screen | 6 |
| 9.1 Visual direction | 2 |
| 9.3 Home (title, strip ≤ 8, hero, lists, archive, "+") | 1, 3, 7 |
| 9.4 Report detail | 6 |
| 9.5 Report form, expired warning | 4 |
| 9.6 Medication form, preview | 5 |
| 10 Name suggestions in the forms | 4, 5 |
| 11 State text labels, delete confirmations | 2, 5, 6 |
| 12 Input validation | 4, 5 |
| 13 Save failure | 3, 4, 6 |
| 14.4 UI test | 8 |

Not in this plan (Plan 4): 9.2 onboarding, 9.3 item 2 permission banner and the settings button, 9.7 settings, 13 permission rows, privacy manifest, combined VoiceOver labels (11), the accessibility pass and the manual test list (14.5).
