# Plan 3 — Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the debug screen with the real screens: Home, report detail, report form, renewal, medication form and archive, in English and Turkish.

**Architecture:** All decisions that a screen shows (order, hero item, ring, text) come from pure code: `HomeLayout` in `MedReportKit` (tested on Linux) and small `@MainActor` helpers in the app (tested in CI). The views only show values and call `ItemActions`. Every change goes through `ItemActions`, which saves and syncs (spec 5.4).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, String Catalog (`Localizable.xcstrings`), Swift Testing, XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-27-ilac-rapor-design.md` (sections 6.5, 6.6, 8.5, 9.1, 9.3–9.6, 10, 12, 14.4; D6, D9, D10). Follow-ups: `docs/superpowers/followups.md`.

## Global Constraints

- All Global Constraints of Plan 2 apply.
- Views contain no decision logic. Order, hero, ring, validation and text come from `HomeLayout`, `StatusText`, the form models and `DestinationResolver`.
- Every save goes through `ItemActions` (save, then `ReminderSync.sync()`).
- Screen text uses the String Catalog. English is the source language; every key has a Turkish translation. Debug-only text uses `Text(verbatim:)`.
- Visual direction (spec 9.1): page background `Color(.systemGroupedBackground)`; cards `Color(.secondarySystemGroupedBackground)`, corner radius 20; state colors only `.green` (normal), `.orange` (reminding), `.red` (overdue), `.gray` (handled); the one primary button per screen is a pill with `Color.primary` background and `Color(.systemBackground)` text; numbers and headings use `design: .rounded`; all fonts are text styles (Dynamic Type), never fixed sizes.
- Rings appear only on the hero card and in the upcoming strip.
- Validation ranges (spec 12): title and name not empty after trim; `leadDays` 0...90; `supplyDays` 1...365.
- Out of scope (Plan 4): onboarding, settings screen, privacy manifest, VoiceOver labels, largest-Dynamic-Type pass.

## Review Focus

1. **A tap on a notification for a deleted item** (follow-up from Plan 2). Expected: Home stays open, no empty screen. Test: Task 2, `deletedItemRoutesNowhere`.
2. **Editing the end date of a handled report.** Expected: the report becomes unhandled and daily reminders start again for the new date. Test: Task 3, `editingEndDateOfHandledReportRenews`.
3. **Linking a medication to a report after typing a person name.** Expected: the person field disappears, the saved `personName` is empty, and the report's person is used. Test: Task 3, `linkedMedicationDropsOwnPersonName`.
4. **Deleting a report with linked medications.** Expected: the medications and all their pending notifications disappear. Test: Task 2, `deleteReportRemovesMedicationNotifications`.
5. **More than 8 active items.** Expected: the strip shows 8, the lists show all. Test: Task 1, `stripIsCappedListsAreNot`.

---

## File Structure

```
Packages/MedReportKit/Sources/MedReportKit/
├── HomeLayout.swift                     (Task 1)
├── ReminderLogic.swift                  (Task 1: ringProgress)
└── StatusText.swift                     (Task 1: short)
MedReport/
├── App/AppEnvironment.swift             (Task 2: items; Task 7: -uiTesting store)
├── Data/
│   ├── ItemActions.swift                (Task 2)
│   ├── HomeItems.swift                  (Task 2)
│   ├── NameDirectory.swift              (Task 2)
│   └── DestinationResolver.swift        (Task 2)
├── Forms/
│   ├── ReportFormModel.swift            (Task 3)
│   └── MedicationFormModel.swift        (Task 3)
├── Resources/Localizable.xcstrings      (Task 4)
├── Views/
│   ├── Theme.swift                      (Task 4)
│   ├── Components/RingView.swift, StateBadge.swift, ItemCard.swift, PrimaryButton.swift, NameField.swift (Task 4)
│   ├── Home/HomeView.swift, UpcomingStrip.swift, HeroCard.swift, ArchiveSection.swift, PermissionBanner.swift (Task 5)
│   ├── Report/ReportDetailView.swift, ReportFormView.swift, RenewalView.swift (Task 6)
│   ├── Medication/MedicationFormView.swift (Task 6)
│   └── Debug/DebugView.swift            (Task 5, renamed from PlaceholderView)
├── Notifications/NotificationPermission.swift (Task 5)
MedReportTests/ HomeItemsTests, ItemActionsTests, DestinationResolverTests, NameDirectoryTests, FormModelTests, LocalizationTests
MedReportUITests/ReportFlowUITests.swift (Task 7)
scripts/check-strings.py                 (Task 4)
```

---

### Task 1: `HomeLayout`, ring progress and short status text (kit)

**Files:**
- Create: `Packages/MedReportKit/Sources/MedReportKit/HomeLayout.swift`
- Modify: `ReminderLogic.swift`, `StatusText.swift`
- Test: `Packages/MedReportKit/Tests/MedReportKitTests/HomeLayoutTests.swift`, add to `ReminderLogicTests.swift`, `StatusTextTests.swift`

**Interfaces:**
- Produces:

```swift
public struct HomeLayout: Sendable, Equatable {
    public enum HeroAction: Sendable, Equatable { case renewed, pickedUp, enterDate }
    public struct Hero: Sendable, Equatable { public let item: ReminderItem; public let action: HeroAction? }
    public static let maxStripItems = 8
    public let strip: [ReminderItem]                 // all active items, urgency order, first 8
    public let hero: Hero?                           // nil when there are no items
    public let reports: [ReminderItem]               // endDate ascending, then title
    public let standaloneMedications: [ReminderItem] // endDate ascending, then title
    public var isEmpty: Bool { get }                 // no reports and no medications
    public static func make(reports: [ReminderItem], standaloneMedications: [ReminderItem],
                            linkedMedications: [ReminderItem], now: Date, calendar: Calendar) -> HomeLayout
}

extension ReminderLogic {
    /// Part of the reminder period that is past (spec 9.3). nil for a handled report.
    /// remaining < 0 → 1; leadDays ≤ 0 → (remaining ≤ 0 ? 1 : 0); else clamp((leadDays − remaining) / leadDays, 0...1).
    public static func ringProgress(daysRemaining: Int, leadDays: Int, isHandled: Bool) -> Double?
}

extension StatusText {
    /// Text under a ring in the strip.
    public static func short(daysRemaining: Int, isHandled: Bool, language: AppLanguage) -> String
}
```

Hero rule: `hero.item` is the first item of `ReminderItem.sortedByUrgency(all)`. `action` is nil when its state is `.normal`; else `.enterDate` for a handled report, `.renewed` for a report, `.pickedUp` for a medication.

Short text: en — handled "waiting", overdue "overdue", 0 "today", 1 "tomorrow", N "days"; tr — "tarih bekliyor", "geçti", "bugün", "yarın", "gün". The ring center shows `abs(daysRemaining)` (or an icon for handled), so the short text has no number.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("HomeLayout")
struct HomeLayoutTests {
    let now = date(2026, 10, 27)

    @Test func heroIsMostUrgentWithAction() {
        let overdue = report(1, end: date(2026, 10, 24))
        let soon = medication(2, end: date(2026, 10, 28))
        let l = HomeLayout.make(reports: [overdue], standaloneMedications: [soon], linkedMedications: [],
                                now: now, calendar: istanbul)
        #expect(l.hero == .init(item: overdue, action: .renewed))
        #expect(l.strip.map(\.id) == [uuid(1), uuid(2)])
    }

    @Test func heroActions() {
        let handled = report(1, end: date(2026, 10, 20), handledAt: date(2026, 10, 21))
        #expect(HomeLayout.make(reports: [handled], standaloneMedications: [], linkedMedications: [],
                                now: now, calendar: istanbul).hero?.action == .enterDate)
        let med = medication(2, end: date(2026, 10, 30))
        #expect(HomeLayout.make(reports: [], standaloneMedications: [med], linkedMedications: [],
                                now: now, calendar: istanbul).hero?.action == .pickedUp)
    }

    @Test func calmHeroHasNoAction() {
        let far = report(1, end: date(2027, 6, 1)), nearer = report(2, end: date(2027, 3, 1))
        let l = HomeLayout.make(reports: [far, nearer], standaloneMedications: [], linkedMedications: [],
                                now: now, calendar: istanbul)
        #expect(l.hero == .init(item: nearer, action: nil))
    }

    @Test func linkedMedicationsAreInStripNotInLists() {
        let r = report(1, end: date(2027, 6, 1)), linked = medication(2, end: date(2026, 10, 29))
        let l = HomeLayout.make(reports: [r], standaloneMedications: [], linkedMedications: [linked],
                                now: now, calendar: istanbul)
        #expect(l.strip.first?.id == uuid(2) && l.hero?.item.id == uuid(2))
        #expect(l.reports.map(\.id) == [uuid(1)] && l.standaloneMedications.isEmpty)
    }

    @Test func listsSortByEndDateThenTitle() {
        let b = report(1, title: "B", end: date(2027, 1, 1)), a = report(2, title: "A", end: date(2027, 1, 1))
        let c = report(3, title: "C", end: date(2026, 12, 1))
        #expect(HomeLayout.make(reports: [b, a, c], standaloneMedications: [], linkedMedications: [],
                                now: now, calendar: istanbul).reports.map(\.title) == ["C", "A", "B"])
    }

    @Test func stripIsCappedListsAreNot() {
        let items = (1...10).map { report($0, end: date(2026, 11, $0)) }
        let l = HomeLayout.make(reports: items, standaloneMedications: [], linkedMedications: [],
                                now: now, calendar: istanbul)
        #expect(l.strip.count == 8 && l.reports.count == 10)
    }

    @Test func emptyHasNoHero() {
        let l = HomeLayout.make(reports: [], standaloneMedications: [], linkedMedications: [], now: now, calendar: istanbul)
        #expect(l.isEmpty && l.hero == nil && l.strip.isEmpty)
    }
}
```

Add to `ReminderLogicTests`:

```swift
    @Test func ringProgress() {
        #expect(ReminderLogic.ringProgress(daysRemaining: 18, leadDays: 18, isHandled: false) == 0)
        #expect(ReminderLogic.ringProgress(daysRemaining: 9, leadDays: 18, isHandled: false) == 0.5)
        #expect(ReminderLogic.ringProgress(daysRemaining: 40, leadDays: 18, isHandled: false) == 0)
        #expect(ReminderLogic.ringProgress(daysRemaining: -3, leadDays: 18, isHandled: false) == 1)
        #expect(ReminderLogic.ringProgress(daysRemaining: 0, leadDays: 0, isHandled: false) == 1)
        #expect(ReminderLogic.ringProgress(daysRemaining: 5, leadDays: 18, isHandled: true) == nil)
    }
```

Add to `StatusTextTests` one parameterized test per language with the values above (days 12, 1, 0, -3 and handled).

- [ ] **Step 2: Run the kit tests** — `swift test --package-path Packages/MedReportKit` — Expected: FAIL (`HomeLayout` not found).
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run the kit tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(kit): HomeLayout, ring progress, short status text"`

---

### Task 2: Data helpers — `ItemActions`, `HomeItems`, `NameDirectory`, `DestinationResolver`

**Files:**
- Create: `MedReport/Data/ItemActions.swift`, `HomeItems.swift`, `NameDirectory.swift`, `DestinationResolver.swift`
- Modify: `MedReport/App/AppEnvironment.swift` (add `items: ItemActions`; `saveAndSync()` calls `items.save()`)
- Test: `MedReportTests/ItemActionsTests.swift`, `HomeItemsTests.swift`, `NameDirectoryTests.swift`, `DestinationResolverTests.swift`

**Interfaces:**
- Consumes: `ReminderItem(report:)`, `ReminderItem(medication:calendar:)`, `ReminderSync`, `Destination`, models.
- Produces:

```swift
@MainActor final class ItemActions {
    init(container: ModelContainer, sync: ReminderSync)
    func save() async throws                                   // context.save(), then sync.sync()
    func markRenewed(_ report: Report, now: Date) async throws  // markHandled(at:), snoozeUntil = nil
    func pickUp(_ medication: Medication, now: Date, calendar: Calendar) async throws
    func renew(_ report: Report, newEndDate: Date) async throws
    func setArchived(_ report: Report, _ archived: Bool) async throws
    func setArchived(_ medication: Medication, _ archived: Bool) async throws
    func delete(_ report: Report) async throws                 // cascade deletes its medications
    func delete(_ medication: Medication) async throws
}

struct HomeItems {
    var reports: [ReminderItem]              // not archived
    var standaloneMedications: [ReminderItem] // no report, not archived
    var linkedMedications: [ReminderItem]    // has a report, not effectively archived
    var archivedReports: [Report]            // isArchived, sorted by title
    var archivedMedications: [Medication]    // isArchived and (no report or report not archived), sorted by name
    var archivedCount: Int { get }
    @MainActor static func make(reports: [Report], medications: [Medication], calendar: Calendar) -> HomeItems
}

enum NameDirectory {
    /// One usage per report and per medication without a report; usedAt = createdAt; empty names skipped.
    @MainActor static func usages(reports: [Report], medications: [Medication]) -> [NameUsage]
}

enum Route: Hashable, Sendable { case reportDetail(UUID), medicationForm(UUID), renewal(UUID) }
enum DestinationResolver {
    /// nil for `.home` and for an id that no longer exists (follow-up from Plan 2).
    @MainActor static func route(for destination: Destination, in context: ModelContext) -> Route?
}
```

- [ ] **Step 1: Write the failing tests**

`ItemActionsTests` (in-memory container, `FakeNotificationCenter`, real `ReminderSync`; `now = date(2026, 10, 27, 12)` passed through `sync(now:calendar:)` is not possible here, so tests check model state and `center.removeAllCount`; pending ids are checked where the date does not matter):

```swift
    @Test func archiveRemovesNotificationsAndRestoreAddsThem() async throws
    // report ending 30 days after Date(): setArchived(true) → center.added is empty;
    // setArchived(false) → center.added contains an id with prefix "report-<id>-"

    @Test func deleteReportRemovesMedicationNotifications() async throws
    // report + linked medication; delete(report) → fetchCount(Medication) == 0,
    // no added id contains the medication's uuid

    @Test func markRenewedSetsHandledAndClearsSnooze() async throws
    // snoozeUntil set; markRenewed(now:) → isHandled, handledAt == now, snoozeUntil == nil
```

`HomeItemsTests`:

```swift
    @Test func splitsActiveAndArchived()
    // open report R1 with linked M1; archived report R2 with linked M2; standalone M3; standalone archived M4;
    // M5 archived but linked to R1.
    // reports == [R1]; linked == [M1]; standalone == [M3]; archivedReports == [R2];
    // archivedMedications == [M4, M5] by name; archivedCount == 3
```

`NameDirectoryTests`: report "Babam", linked medication with personName "X" (skipped), standalone medication "Annem", report with "" (skipped) → names `["Babam", "Annem"]` in any order, `usedAt == createdAt`.

`DestinationResolverTests`:

```swift
    @Test func existingItemsRoute()      // reportDetail(r.id) → .reportDetail; medicationForm(m.id) → .medicationForm; renewal(r.id) → .renewal
    @Test func deletedItemRoutesNowhere() // reportDetail(uuid(99)) → nil; medicationForm(uuid(98)) → nil; .home → nil
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (types not found).
- [ ] **Step 3: Implement the four files and add `items` to `AppEnvironment`**
- [ ] **Step 4: Run app tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): item actions, home items, name directory, destination resolver"`

---

### Task 3: Form models

**Files:**
- Create: `MedReport/Forms/ReportFormModel.swift`, `MedReport/Forms/MedicationFormModel.swift`
- Test: `MedReportTests/FormModelTests.swift`

**Interfaces:**
- Consumes: models, `PersonNameSuggester.normalize`, `ReminderLogic.supplyEndDate`.
- Produces:

```swift
@MainActor @Observable final class ReportFormModel {
    init(report: Report?, defaultLeadDays: Int, now: Date, calendar: Calendar)
    let isNew: Bool
    var title: String; var personName: String; var endDate: Date; var leadDays: Int; var notes: String
    var canSave: Bool { get }
    func endDateIsPast(now: Date, calendar: Calendar) -> Bool
    /// Creates and inserts, or updates. Trims title and person. For an existing handled report,
    /// a changed end date (another calendar day) calls `renew(newEndDate:)`.
    @discardableResult func apply(to context: ModelContext, calendar: Calendar) -> Report
}

@MainActor @Observable final class MedicationFormModel {
    static let quickSupplyDays = [30, 60, 90]
    init(medication: Medication?, report: Report?, defaultLeadDays: Int, now: Date, calendar: Calendar)
    let isNew: Bool
    var name: String; var dosageNote: String; var personName: String; var report: Report?
    var lastPickupDate: Date; var supplyDays: Int; var leadDays: Int
    var showsPersonField: Bool { get }          // report == nil
    var canSave: Bool { get }
    func estimatedEnd(calendar: Calendar) -> Date
    /// lastPickupDate is saved as start of day; personName is saved as "" when a report is linked.
    @discardableResult func apply(to context: ModelContext, calendar: Calendar) -> Medication
}
```

Defaults for a new item: report `endDate` = start of today, `leadDays` = `defaultLeadDays`; medication `lastPickupDate` = start of today, `supplyDays` = 30, `leadDays` = `defaultLeadDays`, `report` = the given report.

- [ ] **Step 1: Write the failing tests**

```swift
    @Test func reportValidation()           // "  " → !canSave; "Tansiyon" → canSave; leadDays 91 → !canSave; -1 → !canSave
    @Test func pastEndDateWarns()           // endDate 2026-10-20, now 2026-10-27 → true; endDate today → false
    @Test func newReportIsInsertedTrimmed() // title "  Tansiyon raporu ", person " Babam" → saved "Tansiyon raporu", "Babam"; fetchCount == 1
    @Test func editingEndDateOfHandledReportRenews()
    // report handled; form endDate = 2027-11-10 → after apply: !isHandled, handledAt == nil, endDate == 2027-11-10
    @Test func editingOtherFieldsKeepsHandled() // handled report, change notes only → still isHandled
    @Test func medicationDefaultsAndPreview()
    // new, now 2026-10-27 15:00 → lastPickupDate == startOfDay, supplyDays 30, estimatedEnd == 2026-11-26 00:00
    @Test func medicationValidation()       // name "" → !canSave; supplyDays 0 → !canSave; 366 → !canSave; 365 → canSave
    @Test func linkedMedicationDropsOwnPersonName()
    // personName "Annem", report set → !showsPersonField; after apply: personName == "", effectivePersonName == report's
```

- [ ] **Step 2: Run app tests** — Expected: FAIL.
- [ ] **Step 3: Implement both form models**
- [ ] **Step 4: Run app tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): report and medication form models"`

---

### Task 4: String Catalog, theme and shared components

**Files:**
- Create: `MedReport/Resources/Localizable.xcstrings`, `scripts/check-strings.py`, `MedReport/Views/Theme.swift`, `MedReport/Views/Components/{RingView,StateBadge,ItemCard,PrimaryButton,NameField}.swift`
- Modify: `project.yml` (`options.developmentLanguage: en`; `info.properties.CFBundleLocalizations: [en, tr]`), `.github/workflows/ci.yml` (domain job runs `python3 scripts/check-strings.py`)
- Test: `MedReportTests/LocalizationTests.swift`

**Strings** (key = English source; Turkish translation):

| English | Turkish |
|---|---|
| Reminders | Hatırlatmalar |
| Reports | Raporlar |
| Medications without a report | Raporsuz ilaçlar |
| Archive (%lld) | Arşiv (%lld) |
| Add report | Rapor ekle |
| Add medication | İlaç ekle |
| Add your first report | İlk raporunu ekle |
| Notifications are off | Bildirimler kapalı |
| Open Settings | Ayarları aç |
| Most urgent | En acil |
| Renewed | Yeniledim |
| Picked up | Aldım |
| Enter date | Tarihi gir |
| Enter the new end date | Yeni bitiş tarihini gir |
| Stop tracking | Takibi durdur |
| Resume tracking | Takibi yeniden başlat |
| End date | Bitiş tarihi |
| Notes | Notlar |
| Medications | İlaçlar |
| Edit | Düzenle |
| Delete report | Raporu sil |
| Delete this report? Its medications are also deleted. | Bu rapor silinsin mi? Bağlı ilaçları da silinir. |
| Delete | Sil |
| Cancel | Vazgeç |
| Save | Kaydet |
| New report | Yeni rapor |
| Edit report | Raporu düzenle |
| Report name | Rapor adı |
| For whom | Kimin için |
| Days before to remind | Kaç gün önce hatırlatılsın |
| This report seems to have ended. Save it anyway? | Bu rapor bitmiş görünüyor, yine de kaydedilsin mi? |
| New end date | Yeni bitiş tarihi |
| Enter the end date on the new report. | Yeni rapordaki bitiş tarihini gir. |
| New medication | Yeni ilaç |
| Edit medication | İlacı düzenle |
| Medication name | İlaç adı |
| Dose note | Doz notu |
| Linked report | Bağlı rapor |
| None | Yok |
| Last pickup date | Son alım tarihi |
| Supply in days | Kaç günlük |
| Estimated end: %@ | Tahmini bitiş: %@ |
| Delete medication | İlacı sil |
| Delete this medication? | Bu ilaç silinsin mi? |

`check-strings.py`: reads the catalog JSON; exits 1 and prints the key when a key has no `tr` localization or its state is not `translated`. Prints `OK <N> keys` on success.

Components (no logic; inputs are values):
- `RingView(progress: Double?, state: ReminderState, center: String)` — a circle stroke; `progress == nil` draws a dashed gray ring.
- `StateBadge(text: String, state: ReminderState)` — a pill with the state color at low opacity and the state color text.
- `ItemCard(title: String, subtitle: String, badge: StateBadge)` — a white card row, whole card tappable.
- `PrimaryButton(title: LocalizedStringKey, action:)` — the black pill (spec 9.1).
- `NameField(text: Binding<String>, suggestions: [String])` — a text field with suggestion chips under it; a tap on a chip fills the field.
- `Theme` — the colors in Global Constraints; `Color.forState(_ state: ReminderState) -> Color`.

- [ ] **Step 1: Write the failing test and the check**

```swift
@Suite("Localization")
struct LocalizationTests {
    private func turkish(_ key: String) -> String {
        let bundle = Bundle(path: Bundle.main.path(forResource: "tr", ofType: "lproj")!)!
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    @Test func turkishTranslationsAreInTheApp() {
        #expect(turkish("Reminders") == "Hatırlatmalar")
        #expect(turkish("Delete this report? Its medications are also deleted.") ==
                "Bu rapor silinsin mi? Bağlı ilaçları da silinir.")
    }
}
```

Run `python3 scripts/check-strings.py` before the catalog exists. Expected: exit 1.

- [ ] **Step 2: Run app tests** — Expected: FAIL (no `tr.lproj`).
- [ ] **Step 3: Add the catalog, `project.yml` changes, theme and components**
- [ ] **Step 4: Run `python3 scripts/check-strings.py` (Expected: `OK 44 keys`) and app tests (Expected: PASS)**
- [ ] **Step 5: Commit** — `git commit -m "feat(app): string catalog en/tr, theme and components"`

---

### Task 5: Home screen

**Files:**
- Create: `MedReport/Views/Home/{HomeView,UpcomingStrip,HeroCard,ArchiveSection,PermissionBanner}.swift`, `MedReport/Notifications/NotificationPermission.swift`
- Move: `MedReport/Views/PlaceholderView.swift` → `MedReport/Views/Debug/DebugView.swift` (all its text becomes `Text(verbatim:)`)
- Modify: `MedReport/App/MedReportApp.swift` (root view `HomeView`)
- Test: `MedReportTests/NotificationPermissionTests.swift`

**Interfaces:**
- Consumes: `HomeItems.make`, `HomeLayout.make`, `StatusText`, `ReminderLogic.ringProgress`, `ItemActions`, `DestinationResolver`, `NavigationRouter`, components.
- Produces:

```swift
@MainActor @Observable final class NotificationPermission {
    enum Status: Equatable { case allowed, denied, notDetermined }
    var status: Status
    init(status: Status = .notDetermined)
    /// Maps UNAuthorizationStatus: .authorized/.provisional/.ephemeral → .allowed; .denied → .denied; else .notDetermined.
    static func map(_ status: UNAuthorizationStatus) -> Status
    /// Reads the current settings (completion handler marked @Sendable) and updates `status`.
    func refresh() async
}
```

`HomeView` layout from top (spec 9.3): navigation title "Reminders"; toolbar button (gear) that opens `DebugView` in Debug builds only (Plan 4 adds Settings); `PermissionBanner` only when `status == .denied` (button opens `UIApplication.openNotificationSettingsURLString`); `UpcomingStrip` when `layout.strip` is not empty; `HeroCard`; section "Reports"; section "Medications without a report"; `ArchiveSection` closed by default with "Archive (%lld)" only when `archivedCount > 0`; floating "+" `Menu` at the bottom right with "Add report" and "Add medication". Empty state: when `layout.isEmpty`, show only `PrimaryButton("Add your first report")`.

Data: `@Query` all reports and all medications; `HomeItems.make(...)`, then `HomeLayout.make(...)` with `Date()` and `Calendar.current`. Language: `AppEnvironment.currentLanguage`.

Navigation: `NavigationStack(path: $path)` with `[Route]`; `.navigationDestination(for: Route.self)`. On `router.pending` change: `DestinationResolver.route(for:in:)`; non-nil → append to `path`; then set `router.pending = nil`. Card taps push `.reportDetail` or `.medicationForm`.

Hero button: `.renewed` → `items.markRenewed(report, now: Date())`; `.pickedUp` → `items.pickUp(...)`; `.enterDate` → push `.renewal(id)`. Strip tap → same route as the card.

Permission: `refresh()` on appear and on `scenePhase == .active`.

- [ ] **Step 1: Write the failing test**

```swift
    @Test func mapsAuthorizationStatus() {
        #expect(NotificationPermission.map(.authorized) == .allowed)
        #expect(NotificationPermission.map(.provisional) == .allowed)
        #expect(NotificationPermission.map(.denied) == .denied)
        #expect(NotificationPermission.map(.notDetermined) == .notDetermined)
    }
```

- [ ] **Step 2: Run app tests** — Expected: FAIL.
- [ ] **Step 3: Implement the Home views, the permission object and the debug move**
- [ ] **Step 4: Run app tests** — Expected: PASS (all earlier suites stay green; the app builds).
- [ ] **Step 5: Commit** — `git commit -m "feat(app): home screen"`

---

### Task 6: Report and medication screens

**Files:**
- Create: `MedReport/Views/Report/{ReportDetailView,ReportFormView,RenewalView}.swift`, `MedReport/Views/Medication/MedicationFormView.swift`
- Modify: `HomeView.swift` (destinations and the "+" menu sheets)

**Interfaces:**
- Consumes: form models (Task 3), `ItemActions`, `NameDirectory`, `PersonNameSuggester.suggestions(for:from:)`, components.

Rules:
- `ReportDetailView(reportID: UUID)` (spec 9.4): fetches the report; if it does not exist, pops back (the item may be deleted while the screen is open). Shows title and person; a state card with `RingView`, `StatusText.text(...)` and one `PrimaryButton` ("Renewed", or "Enter date" for a handled report); end date and notes; linked medications as `ItemCard`s (tap → medication form); buttons "Add medication" (form with this report preset), "Edit" (report form), "Stop tracking"/"Resume tracking"; at the bottom "Delete report" in red with a confirmation dialog using the delete copy, then pop.
- `ReportFormView` (sheet, spec 9.5): fields from the form model; `NameField` with suggestions; `DatePicker` (date only); `Stepper` 0...90; "Save" disabled while `!canSave`; when `endDateIsPast` an alert with the past-date copy and the buttons "Save" and "Cancel"; save → `apply(to:calendar:)` then `items.save()`, dismiss.
- `RenewalView(reportID:)` (spec 8.5): copy "Enter the end date on the new report."; `DatePicker` with default `ReminderLogic.suggestedRenewalEndDate(previousEndDate:calendar:)`; `PrimaryButton("Save")` → `items.renew(report, newEndDate:)`, pop.
- `MedicationFormView` (sheet or pushed for `.medicationForm`, spec 9.6): fields; "Linked report" `Picker` with "None" and the non-archived reports; `NameField` only when `showsPersonField`; quick buttons 30/60/90 and a `Stepper` 1...365; live preview "Estimated end: %@" with `.formatted(date: .long, time: .omitted)`; for an existing medication "Stop tracking"/"Resume tracking" and "Delete medication" with confirmation.

- [ ] **Step 1: Run app tests after adding the views** — Expected: PASS (the app builds; logic is covered by Tasks 1–3).
- [ ] **Step 2: Commit** — `git commit -m "feat(app): report detail, report form, renewal and medication form"`

---

### Task 7: UI test and device check

**Files:**
- Modify: `project.yml` (target `MedReportUITests`, type `bundle.ui-testing`, `dependencies: [target: MedReport]`; add it to the scheme's test targets)
- Modify: `MedReport/App/AppEnvironment.swift` — when `ProcessInfo.processInfo.arguments.contains("-uiTesting")`: in-memory `ModelConfiguration` and `UserDefaults(suiteName: "uiTesting")` cleared at launch
- Create: `MedReportUITests/ReportFlowUITests.swift`
- Modify: `SETUP.md` (device check)

Accessibility identifiers used by the test: `addMenu`, `addReport`, `reportTitleField`, `saveButton`, `reportCard-<title>`, `deleteReportButton`, and the confirmation button `confirmDelete`.

- [ ] **Step 1: Write the UI test (spec 14.4)**

```swift
final class ReportFlowUITests: XCTestCase {
    @MainActor func testAddOpenAndDeleteReport() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["addMenu"].tap()
        app.buttons["addReport"].tap()
        let title = app.textFields["reportTitleField"]
        title.tap(); title.typeText("UI Test Report")
        app.buttons["saveButton"].tap()
        // The end date defaults to today, so the past-date alert does not appear.
        let card = app.buttons["reportCard-UI Test Report"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        app.buttons["deleteReportButton"].tap()
        app.buttons["confirmDelete"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
    }
}
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (identifiers or target missing).
- [ ] **Step 3: Add the target, the `-uiTesting` store and the identifiers**
- [ ] **Step 4: Run app tests** — Expected: PASS, including `testAddOpenAndDeleteReport`.
- [ ] **Step 5: Device check (the user)**

Add to `SETUP.md` and run on the iPhone: add a report and a medication with and without a report; check the hero card, the strip, the lists and the archive; press the hero button; use "Enter date"; check the screens in light and dark mode and with the phone language set to English once.

Expected: all screens show the right data; nothing is cut off at the default text size.

- [ ] **Step 6: Commit** — `git commit -m "test(app): UI flow test and device check"`

---

## Spec coverage of this plan

| Spec item | Task |
|---|---|
| 6.5 archive rules on screens | 2 |
| 6.6 state colors and text | 1, 4 |
| 8.5 renewal flow | 6 |
| 9.1 visual direction | 4 |
| 9.3 Home (strip, hero, lists, archive, "+", banner, empty state) | 1, 5 |
| 9.4 Report detail | 6 |
| 9.5 Report form, past-date warning | 3, 6 |
| 9.6 Medication form, preview | 3, 6 |
| 10 name suggestions in forms | 2, 4, 6 |
| 12 input validation | 3 |
| 14.4 UI test | 7 |
| D10 two languages for screens | 4 |
| Follow-up: tap on a deleted item | 2 |

Not in this plan: onboarding (9.2), settings (9.7), privacy manifest, VoiceOver labels and the largest-Dynamic-Type pass (Plan 4).
