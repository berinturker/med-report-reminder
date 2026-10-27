# Plan 2 — App Shell and Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS app project, the SwiftData models, the settings, and the complete notification flow: plan → schedule → button actions.

**Architecture:** XcodeGen makes the Xcode project from `project.yml`. The app target is thin: SwiftData models, an adapter to `UNUserNotificationCenter` behind a protocol, `ReminderSync` as the single entry point, and `NotificationActionHandler`. All decisions stay in `MedReportKit` (Plans 1 and 1b). Screens come in Plan 3; this plan has only a placeholder view.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, XcodeGen, Swift Testing, GitHub Actions (macOS).

**Spec:** `docs/superpowers/specs/2026-10-27-ilac-rapor-design.md` (sections 5.3, 5.4, 6.1–6.5, 7.6–7.8, 8, 13, 14.3; decisions D3, D10)

## Global Constraints

- iOS 17.0 minimum. iPhone only (`TARGETED_DEVICE_FAMILY = 1`).
- Swift 6 language mode for all targets.
- The `.xcodeproj` is not in git. `project.yml` is the source. Run `xcodegen generate` after each change to `project.yml`.
- Names: app target and scheme `MedReport`; test target `MedReportTests`; package `MedReportKit`; bundle identifier `com.berinturker.medreport`; display name `MedReport` (working name, spec 17).
- `DEVELOPMENT_TEAM` is never committed. It comes from the git-ignored `Config/Local.xcconfig`.
- All models obey spec 6.1: default value on every field, optional relationships, no `@Attribute(.unique)`, `VersionedSchema` (`SchemaV1`).
- No component adds or removes a notification directly. All changes go through `ReminderSync` (spec 5.4).
- `Date()`, `.now` and `Calendar.current` are allowed only in the app layer entry points (`ReminderSync.sync()`, `NotificationActionHandler`, views). Every function under test receives `now` and `calendar`.
- No analytics and no third-party SDK (D3). XcodeGen is a build tool, not a dependency of the app.
- App tests run in CI on macOS with an iOS simulator. On Linux, only `swift test` for the kit runs.

## Review Focus

1. **A notification action for an item that the user deleted.** Expected: no crash, no change, a sync runs. Test: Task 6, `actionForDeletedItemOnlySyncs`.
2. **Notification permission denied.** Expected: sync still completes and `add` failures do not stop the other notifications. Test: Task 5, `addFailureDoesNotStopOtherRequests`.
3. **A stored notification time that is out of range in `UserDefaults`** (for example hour 99 after a bug). Expected: `AppSettings` returns the clamped value, so the planner gets 23. Test: Task 3, `outOfRangeStoredTimeIsClamped`.
4. **"3 saat sonra" pressed twice.** Expected: one snooze notification only, at the later time (the identifier `snooze-<uuid>` replaces the old one). Test: Task 6, `secondSnoozeReplacesFirst`.
5. **Fast mode in a Release build.** Expected: fire dates are never shortened. Test: Task 5, `fastModeIsIgnoredWhenNotAllowed`.

---

## File Structure

```
project.yml                                   (Task 1)
Config/Base.xcconfig                          (Task 1, committed)
Config/Local.xcconfig.example                 (Task 1, committed; Local.xcconfig is git-ignored)
scripts/ci-app-tests.sh                       (Task 1)
.github/workflows/ci.yml                      (Task 1, add app-tests job)
Packages/MedReportKit/                        (Task 1, renamed from IlacRaporKit)
MedReport/
├── App/
│   ├── MedReportApp.swift                    (Task 1, then Task 7)
│   ├── AppDelegate.swift                     (Task 7)
│   └── AppEnvironment.swift                  (Task 7)
├── Models/
│   ├── SchemaV1.swift                        (Task 2)
│   ├── Report.swift                          (Task 2, moved from IlacRapor/Models)
│   └── Medication.swift                      (Task 2, moved from IlacRapor/Models)
├── Settings/
│   └── AppSettings.swift                     (Task 3)
├── Notifications/
│   ├── ReminderItemMapping.swift             (Task 4)
│   ├── NotificationCenterProtocol.swift      (Task 5)
│   ├── NotificationScheduler.swift           (Task 5)
│   ├── NotificationCategories.swift          (Task 5)
│   ├── ReminderSync.swift                    (Task 5)
│   ├── NotificationActionHandler.swift       (Task 6)
│   └── NavigationRouter.swift                (Task 6)
└── Views/
    └── PlaceholderView.swift                 (Task 1)
MedReportTests/
├── TestSupport.swift                         (Task 2)
├── FakeNotificationCenter.swift              (Task 5)
├── ModelTests.swift                          (Task 2, moved from IlacRaporTests)
├── AppSettingsTests.swift                    (Task 3)
├── ReminderItemMappingTests.swift            (Task 4)
├── NotificationSchedulerTests.swift          (Task 5)
├── ReminderSyncTests.swift                   (Task 5)
└── NotificationActionHandlerTests.swift      (Task 6)
```

**How to run the app tests (all tasks from Task 1):**

- In CI: push the branch. The `app-tests` job runs `scripts/ci-app-tests.sh`.
- On a Mac: `xcodegen generate && ./scripts/ci-app-tests.sh`.
- Read the result: `gh api repos/berinturker/med-report-reminder/actions/runs?branch=<branch>` and the job log.

Below, "**Run app tests**" means one of these. "Expected: FAIL" for an app test means the CI job fails at the named test or at compile time with the named symbol.

---

### Task 1: Rename, XcodeGen project, app shell and CI

**Files:**
- Move: `Packages/IlacRaporKit` → `Packages/MedReportKit` (package name, product, targets, folders and `@testable import` lines)
- Move: `IlacRapor/Models/*` → `MedReport/Models/`; `IlacRaporTests/ModelTests.swift` → `MedReportTests/ModelTests.swift` (Task 2 changes their content)
- Create: `project.yml`, `Config/Base.xcconfig`, `Config/Local.xcconfig.example`, `MedReport/App/MedReportApp.swift`, `MedReport/Views/PlaceholderView.swift`, `scripts/ci-app-tests.sh`
- Modify: `.gitignore` (add `*.xcodeproj/`, `Config/Local.xcconfig`), `.github/workflows/ci.yml`, `SETUP.md`

**Interfaces:**
- Produces: scheme `MedReport` that builds the app and runs `MedReportTests`; library `MedReportKit`.

`project.yml` decisions:
- `options.deploymentTarget.iOS: "17.0"`; `settings.base.SWIFT_VERSION: "6.0"`; `TARGETED_DEVICE_FAMILY: "1"`.
- `packages.MedReportKit.path: Packages/MedReportKit`.
- Target `MedReport`: type `application`, platform `iOS`, sources `MedReport`, dependency `package: MedReportKit`, `configFiles` Debug and Release → `Config/Base.xcconfig`, `info.properties`: `CFBundleDisplayName: MedReport`, `UILaunchScreen: {}`, `UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]`; `PRODUCT_BUNDLE_IDENTIFIER: com.berinturker.medreport`; `CODE_SIGN_STYLE: Automatic`.
- Target `MedReportTests`: type `bundle.unit-test`, sources `MedReportTests`, dependency `target: MedReport`, `GENERATE_INFOPLIST_FILE: YES`.
- Scheme `MedReport`: build `MedReport`, test `MedReportTests`.

`Config/Base.xcconfig`: `#include? "Local.xcconfig"`. `Config/Local.xcconfig.example`: `DEVELOPMENT_TEAM = YOUR_TEAM_ID`.

`scripts/ci-app-tests.sh` (`set -euo pipefail`): pick the first available iPhone simulator id from `xcrun simctl list devices available --json` (python3), then `xcodebuild test -project MedReport.xcodeproj -scheme MedReport -destination "id=$ID" CODE_SIGNING_ALLOWED=NO`.

CI: keep job `domain-tests` (path changed to `Packages/MedReportKit`). Add job `app-tests` on `macos-15`: checkout, `brew install xcodegen`, `xcodegen generate`, `./scripts/ci-app-tests.sh`.

`MedReportApp`: `@main` struct with one `WindowGroup { PlaceholderView() }`. `PlaceholderView`: `Text("MedReport")`.

- [ ] **Step 1: Move the package and update all references**

Run: `git mv Packages/IlacRaporKit Packages/MedReportKit`, then rename inside `Package.swift`, the `Sources`/`Tests` folder names, and every `@testable import IlacRaporKit`.

- [ ] **Step 2: Run the kit tests**

Run: `swift test --package-path Packages/MedReportKit`
Expected: PASS, 67 tests.

- [ ] **Step 3: Add the project files, the shell and the CI job**

To keep Task 1 green before Task 2, put `ModelTests.swift` aside: move it to `MedReportTests/ModelTests.swift` and add `#if false` / `#endif` around its body. Task 2 removes them. Add one smoke test in `MedReportTests/SmokeTests.swift`: `@Test func appModuleLoads() { #expect(Bundle.main.bundleIdentifier != nil) }`.

- [ ] **Step 4: Push and run app tests**

Run app tests on branch `plan2-app-shell`.
Expected: both CI jobs PASS; the `app-tests` log shows `appModuleLoads` passed.

- [ ] **Step 5: Update `SETUP.md`**

New first section: "Install XcodeGen (`brew install xcodegen`). Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your team ID. Run `xcodegen generate`. Open `MedReport.xcodeproj`."

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "build: rename to MedReport, add XcodeGen project, app shell and app CI"
```

---

### Task 2: `SchemaV1` models

**Files:**
- Create: `MedReport/Models/SchemaV1.swift`, `MedReportTests/TestSupport.swift`
- Modify: `MedReport/Models/Report.swift`, `MedReport/Models/Medication.swift`, `MedReportTests/ModelTests.swift`

**Interfaces:**
- Produces:

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Report.self, Medication.self] }
}
enum MedReportMigrationPlan: SchemaMigrationPlan { /* schemas: [SchemaV1.self], stages: [] */ }
typealias Report = SchemaV1.Report
typealias Medication = SchemaV1.Medication

// Report: fields of spec 6.2, including snoozeUntil: Date? = nil, isArchived: Bool = false
//   func markHandled(at: Date), func renew(newEndDate: Date)  (renew also sets snoozeUntil = nil)
// Medication: fields of spec 6.3 (no isHandled), snoozeUntil, isArchived
//   var effectivePersonName: String
//   var isEffectivelyArchived: Bool   // isArchived || report?.isArchived == true (spec 6.5)
//   func supplyEndDate(calendar: Calendar) -> Date
//   func markPickedUp(on: Date, calendar: Calendar)   (also sets snoozeUntil = nil)
```

Remove from the models: `reminderState`, `daysRemaining` and all default `.now`/`.current` arguments. The views (Plan 3) use `ReminderItem` for state and days.

- Produces (tests only), `MedReportTests/TestSupport.swift`: `let istanbul: Calendar`, `func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date`, `@MainActor func makeContainer() throws -> ModelContainer` (in-memory, `SchemaV1`, `MedReportMigrationPlan`).

- [ ] **Step 1: Write the failing tests**

Remove `#if false`. Change the existing tests to the new API (no `reminderState`). Add:

```swift
    @Test func newFieldsHaveDefaults() {
        let r = Report(title: "Tansiyon raporu", endDate: date(2027, 1, 1))
        let m = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        #expect(r.snoozeUntil == nil && r.isArchived == false)
        #expect(m.snoozeUntil == nil && m.isArchived == false)
    }

    @Test func archivedReportArchivesItsMedications() {
        let r = Report(title: "Tansiyon raporu", endDate: date(2027, 1, 1))
        let linked = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        #expect(!linked.isEffectivelyArchived)
        r.isArchived = true
        #expect(linked.isEffectivelyArchived)
        #expect(linked.isArchived == false)   // the record does not change (spec 6.5)
    }

    @Test func pickupAndRenewClearSnooze() {
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 1))
        r.snoozeUntil = date(2026, 10, 27, 15)
        r.renew(newEndDate: date(2027, 11, 1))
        #expect(r.snoozeUntil == nil)
        let m = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        m.snoozeUntil = date(2026, 10, 27, 15)
        m.markPickedUp(on: date(2026, 10, 27, 18), calendar: istanbul)
        #expect(m.snoozeUntil == nil)
        #expect(m.lastPickupDate == istanbul.startOfDay(for: date(2026, 10, 27)))
    }
```

- [ ] **Step 2: Run app tests**

Expected: FAIL at compile time (`snoozeUntil`, `isEffectivelyArchived` not found).

- [ ] **Step 3: Implement `SchemaV1`, `Report`, `Medication`**

Models are nested types in `SchemaV1` (`extension SchemaV1 { @Model final class Report … }`). The app and tests use the typealiases.

- [ ] **Step 4: Run app tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(app): SchemaV1 models with archive and snooze"
```

---

### Task 3: `AppSettings`

**Files:**
- Create: `MedReport/Settings/AppSettings.swift`
- Test: `MedReportTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: `PlannerSettings`, `AppLanguage` (kit).
- Produces:

```swift
@MainActor @Observable final class AppSettings {
    init(defaults: UserDefaults)
    var notificationHour: Int            // key "notificationHour", default 10, read clamped to 0...23
    var notificationMinute: Int          // key "notificationMinute", default 0, read clamped to 0...59
    var defaultReportLeadDays: Int       // key "defaultReportLeadDays", default 18, clamped 0...90
    var defaultMedicationLeadDays: Int   // key "defaultMedicationLeadDays", default 7, clamped 0...90
    var hasCompletedOnboarding: Bool     // key "hasCompletedOnboarding", default false
    var isFastModeOn: Bool               // key "isFastModeOn", default false
    func plannerSettings(language: AppLanguage) -> PlannerSettings
}
```

Each property reads from and writes to `defaults` directly (no cached copy), so two instances on the same suite agree. A missing key gives the default. Validation ranges come from spec 12.

- [ ] **Step 1: Write the failing tests**

Each test uses `UserDefaults(suiteName: "test-\(UUID())")!`.

```swift
    @Test func defaultsMatchSpec() {
        let s = AppSettings(defaults: fresh())
        #expect(s.notificationHour == 10 && s.notificationMinute == 0)
        #expect(s.defaultReportLeadDays == 18 && s.defaultMedicationLeadDays == 7)
        #expect(!s.hasCompletedOnboarding && !s.isFastModeOn)
    }

    @Test func valuesPersistAcrossInstances() {
        let d = fresh()
        AppSettings(defaults: d).notificationHour = 8
        #expect(AppSettings(defaults: d).notificationHour == 8)
    }

    @Test func outOfRangeStoredTimeIsClamped() {
        let d = fresh()
        d.set(99, forKey: "notificationHour")
        d.set(-4, forKey: "notificationMinute")
        let s = AppSettings(defaults: d)
        #expect(s.notificationHour == 23 && s.notificationMinute == 0)
        #expect(s.plannerSettings(language: .en) ==
                PlannerSettings(notificationHour: 23, notificationMinute: 0, language: .en))
    }
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (`AppSettings` not found).
- [ ] **Step 3: Implement `AppSettings`**
- [ ] **Step 4: Run app tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): AppSettings in UserDefaults"`

---

### Task 4: `ReminderItem` mapping

**Files:**
- Create: `MedReport/Notifications/ReminderItemMapping.swift`
- Test: `MedReportTests/ReminderItemMappingTests.swift`

**Interfaces:**
- Consumes: `Report`, `Medication` (Task 2); `ReminderItem` (kit).
- Produces:

```swift
extension ReminderItem {
    init(report: Report)
    init(medication: Medication, calendar: Calendar)
    /// Items that are not archived (reports with isArchived false; medications with isEffectivelyArchived false).
    static func active(reports: [Report], medications: [Medication], calendar: Calendar) -> [ReminderItem]
}
```

Values: report → kind `.report`, title, `personName`, `endDate`, `leadDays`, `isHandled`, `handledAt`, `snoozeUntil`. Medication → kind `.medication`, title = `name`, person = `effectivePersonName`, endDate = `supplyEndDate(calendar:)`, `leadDays`, `isHandled` false, `handledAt` nil, `snoozeUntil`.

- [ ] **Step 1: Write the failing tests**

```swift
    @Test func medicationUsesReportPersonAndSupplyEnd() {
        let r = Report(title: "Tansiyon raporu", personName: "Babam", endDate: date(2027, 1, 1))
        let m = Medication(name: "Beloc", personName: "Yanlış", lastPickupDate: date(2026, 10, 1),
                           supplyDays: 30, leadDays: 7, report: r)
        let item = ReminderItem(medication: m, calendar: istanbul)
        #expect(item.kind == .medication && item.id == m.id && item.title == "Beloc")
        #expect(item.personName == "Babam")
        #expect(item.endDate == istanbul.startOfDay(for: date(2026, 10, 31)))
        #expect(!item.isHandled)
    }

    @Test func reportCopiesHandledAndSnooze() {
        let r = Report(title: "Kardiyoloji", endDate: date(2026, 10, 20))
        r.markHandled(at: date(2026, 10, 21))
        r.snoozeUntil = date(2026, 10, 27, 15)
        let item = ReminderItem(report: r)
        #expect(item.isHandled && item.handledAt == date(2026, 10, 21))
        #expect(item.snoozeUntil == date(2026, 10, 27, 15))
    }

    @Test func activeExcludesArchivedAndMedicationsOfArchivedReports() {
        let archived = Report(title: "Eski", endDate: date(2027, 1, 1)); archived.isArchived = true
        let open = Report(title: "Tansiyon raporu", endDate: date(2027, 1, 1))
        let m1 = Medication(name: "A", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: archived)
        let m2 = Medication(name: "B", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        let m3 = Medication(name: "C", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7); m3.isArchived = true
        let items = ReminderItem.active(reports: [archived, open], medications: [m1, m2, m3], calendar: istanbul)
        #expect(Set(items.map(\.title)) == ["Tansiyon raporu", "B"])
    }
```

- [ ] **Step 2: Run app tests** — Expected: FAIL (initializers not found).
- [ ] **Step 3: Implement the mapping**
- [ ] **Step 4: Run app tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): map models to ReminderItem"`

---

### Task 5: Scheduler, categories and `ReminderSync`

**Files:**
- Create: `MedReport/Notifications/NotificationCenterProtocol.swift`, `NotificationCategories.swift`, `NotificationScheduler.swift`, `ReminderSync.swift`
- Test: `MedReportTests/FakeNotificationCenter.swift`, `NotificationSchedulerTests.swift`, `ReminderSyncTests.swift`

**Interfaces:**
- Consumes: `NotificationPlanner.plan`, `PlannedNotification` (kit); `AppSettings` (Task 3); `ReminderItem.active` (Task 4).
- Produces:

```swift
protocol NotificationCenterProtocol: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}
extension UNUserNotificationCenter: NotificationCenterProtocol {}
// If Swift 6 reports a Sendable error for UNUserNotificationCenter with the CI Xcode version,
// add `@retroactive @unchecked Sendable` to this extension and ledger it as a ruling.

enum NotificationAction: String, Sendable { case renewed = "RENEWED", pickedUp = "PICKED_UP", snooze = "SNOOZE" }
enum NotificationUserInfoKey { static let kind = "itemKind"; static let id = "itemID" }
enum NotificationCategories {
    static func all(language: AppLanguage) -> Set<UNNotificationCategory>
}

@MainActor final class NotificationScheduler {
    init(center: any NotificationCenterProtocol, calendar: Calendar, isFastModeAllowed: Bool)
    /// Removes all pending requests, then adds one request for each planned notification.
    /// An `add` failure is logged and does not stop the other requests (spec 13).
    func replaceAll(with planned: [PlannedNotification], now: Date, fastMode: Bool) async
    /// For tests: the request a planned notification becomes.
    func request(for planned: PlannedNotification, now: Date, fastMode: Bool) -> UNNotificationRequest
}

@MainActor final class ReminderSync {
    init(container: ModelContainer, settings: AppSettings, scheduler: NotificationScheduler,
         language: @escaping @MainActor () -> AppLanguage)
    /// Uses Date() and Calendar.current. Entry point for the app (spec 5.4).
    func sync() async
    /// Testable form.
    func sync(now: Date, calendar: Calendar) async
}
```

Rules:
- Request: identifier, `content.title`, `content.body`, `content.sound = .default`, `content.categoryIdentifier = planned.category.rawValue`, `content.userInfo` = `[kind: itemKind.rawValue, id: itemID.uuidString]` (empty for the backup).
- Trigger (spec 7.7): `UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)`.
- Fast mode (spec 7.8): only when `isFastModeAllowed && fastMode`. Fire date = `now + (calendar days from startOfDay(now) to startOfDay(fireDate)) minutes`, minimum `now + 5 seconds`; trigger is `UNTimeIntervalNotificationTrigger(timeInterval:, repeats: false)`. The app passes `isFastModeAllowed: true` only under `#if DEBUG`.
- Categories (spec 7.6, 8.2): `REPORT_REMINDER` → actions `RENEWED` and `SNOOZE`; `MED_REMINDER` → `PICKED_UP` and `SNOOZE`; `RENEWAL_DATE` and `BACKUP` → no actions. Options for actions: none (no `.foreground`, no `.authenticationRequired`). Titles:

| Action | en | tr |
|---|---|---|
| RENEWED | "Renewed" | "Yeniledim" |
| PICKED_UP | "Picked up" | "Aldım" |
| SNOOZE | "In 3 hours" | "3 saat sonra" |

- `ReminderSync.sync(now:calendar:)`: fetch all `Report` and `Medication` from `container.mainContext`, `ReminderItem.active(...)`, `NotificationPlanner.plan(items:now:settings: settings.plannerSettings(language: language()), calendar:)`, then `scheduler.replaceAll(with:now:fastMode: settings.isFastModeOn)`.

- [ ] **Step 1: Write the fake center and the failing tests**

`FakeNotificationCenter`: records `added: [UNNotificationRequest]`, `removeAllCount: Int`, `categories`; `failingIdentifiers: Set<String>` makes `add` throw for those identifiers.

```swift
    @Test func requestHasContentCategoryUserInfoAndCalendarTrigger() {
        let p = PlannedNotification(identifier: "report-X-20261028", fireDate: date(2026, 10, 28, 10),
                                    title: "T", body: "B", category: .reportReminder,
                                    itemKind: .report, itemID: uuid(1))
        let r = scheduler(fake()).request(for: p, now: date(2026, 10, 27, 12), fastMode: false)
        #expect(r.identifier == "report-X-20261028")
        #expect(r.content.categoryIdentifier == "REPORT_REMINDER")
        #expect(r.content.userInfo["itemKind"] as? String == "report")
        #expect(r.content.userInfo["itemID"] as? String == uuid(1).uuidString)
        let t = r.trigger as! UNCalendarNotificationTrigger
        #expect(t.dateComponents.hour == 10 && t.dateComponents.day == 28 && !t.repeats)
    }

    @Test func fastModeMapsDaysToMinutes() {
        let p = planned(fire: date(2026, 10, 30, 10))   // 3 days after now
        let r = scheduler(fake(), allowed: true).request(for: p, now: date(2026, 10, 27, 12), fastMode: true)
        #expect((r.trigger as! UNTimeIntervalNotificationTrigger).timeInterval == 180)
    }

    @Test func fastModeIsIgnoredWhenNotAllowed() {
        let p = planned(fire: date(2026, 10, 30, 10))
        let r = scheduler(fake(), allowed: false).request(for: p, now: date(2026, 10, 27, 12), fastMode: true)
        #expect(r.trigger is UNCalendarNotificationTrigger)
    }

    @Test func replaceAllRemovesThenAdds() async {
        let f = fake()
        await scheduler(f).replaceAll(with: [planned(id: "a"), planned(id: "b")], now: date(2026, 10, 27), fastMode: false)
        #expect(f.removeAllCount == 1)
        #expect(f.added.map(\.identifier) == ["a", "b"])
    }

    @Test func addFailureDoesNotStopOtherRequests() async {
        let f = fake(); f.failingIdentifiers = ["a"]
        await scheduler(f).replaceAll(with: [planned(id: "a"), planned(id: "b")], now: date(2026, 10, 27), fastMode: false)
        #expect(f.added.map(\.identifier) == ["b"])
    }

    @Test func categoriesHaveSpecButtons() {
        let cats = NotificationCategories.all(language: .tr)
        let report = cats.first { $0.identifier == "REPORT_REMINDER" }!
        #expect(report.actions.map(\.identifier) == ["RENEWED", "SNOOZE"])
        #expect(report.actions.map(\.title) == ["Yeniledim", "3 saat sonra"])
        #expect(report.actions.allSatisfy { $0.options.isEmpty })
        #expect(cats.first { $0.identifier == "MED_REMINDER" }!.actions.map(\.identifier) == ["PICKED_UP", "SNOOZE"])
        #expect(cats.first { $0.identifier == "RENEWAL_DATE" }!.actions.isEmpty)
        #expect(NotificationCategories.all(language: .en).first { $0.identifier == "MED_REMINDER" }!
                .actions.map(\.title) == ["Picked up", "In 3 hours"])
    }
```

`ReminderSyncTests` (in-memory container, fake center, `AppSettings` on a fresh suite):

```swift
    @Test func syncSchedulesActiveItemsOnly() async throws {
        // one open report ending 2026-11-05, one archived report → only "report-<open id>-…" identifiers + "backup"
    }

    @Test func syncUsesLanguage() async throws {
        // language closure returns .en → first title ends with "ends in 8 days"
    }
```

Write both with concrete assertions: identifiers all start with `"report-\(open.id.uuidString)"` except the last, which is `"backup"`; total count 64; the archived id never appears.

- [ ] **Step 2: Run app tests** — Expected: FAIL (types not found).
- [ ] **Step 3: Implement the four files**
- [ ] **Step 4: Run app tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): notification scheduler, categories and ReminderSync"`

---

### Task 6: Notification actions and navigation

**Files:**
- Create: `MedReport/Notifications/NotificationActionHandler.swift`, `MedReport/Notifications/NavigationRouter.swift`
- Test: `MedReportTests/NotificationActionHandlerTests.swift`

**Interfaces:**
- Consumes: `NotificationAction`, `NotificationUserInfoKey` (Task 5); `ReminderSync` (Task 5); models (Task 2).
- Produces:

```swift
enum Destination: Equatable, Sendable {
    case reportDetail(UUID), medicationForm(UUID), renewal(UUID), home
}
@MainActor @Observable final class NavigationRouter { var pending: Destination? }

@MainActor final class NotificationActionHandler {
    init(container: ModelContainer, sync: ReminderSync, router: NavigationRouter)
    /// Button actions (spec 8.3). Steps: find item → change → save → sync.
    func handle(actionIdentifier: String, userInfo: [AnyHashable: Any], now: Date, calendar: Calendar) async
    /// Tap on the notification body (spec 8.2).
    func handleTap(categoryIdentifier: String, userInfo: [AnyHashable: Any])
}
```

Rules:
- `RENEWED` on a report: `markHandled(at: now)`, `snoozeUntil = nil`.
- `PICKED_UP` on a medication: `markPickedUp(on: now, calendar:)` (clears snooze).
- `SNOOZE`: `snoozeUntil = now + 3 hours` (10 800 s).
- Unknown action, missing or bad `userInfo`, or a missing item: no change, but still `sync`.
- Tap: `REPORT_REMINDER` → `.reportDetail(id)`; `MED_REMINDER` → `.reportDetail(report.id)` if the medication has a report, else `.medicationForm(id)`; `RENEWAL_DATE` → `.renewal(id)`; `BACKUP` or unknown → `.home`.

- [ ] **Step 1: Write the failing tests**

Use an in-memory container, a fake center and a real `ReminderSync`. Helper `info(_ kind: String, _ id: UUID) -> [AnyHashable: Any]`.

```swift
    @Test func renewedMarksReportHandledAndSyncs() async throws
    // after: report.isHandled, handledAt == now, fake.removeAllCount == 1,
    // fake.added contains only "renewal-…" and "backup" for that report

    @Test func pickedUpResetsSupply() async throws
    // lastPickupDate == startOfDay(now); first added identifier for the med is "med-<id>-…" ≥ 23 days later (30 − 7)

    @Test func secondSnoozeReplacesFirst() async throws
    // snooze at 12:00, then at 13:00 → snoozeUntil == 16:00; exactly one "snooze-<id>" in fake.added after the second sync

    @Test func actionForDeletedItemOnlySyncs() async throws
    // unknown UUID → no throw, fake.removeAllCount == 1

    @Test func tapRoutes() throws
    // four cases from the rules above, checked through router.pending
```

Write each with the concrete values in the comments.

- [ ] **Step 2: Run app tests** — Expected: FAIL (types not found).
- [ ] **Step 3: Implement the handler and the router**
- [ ] **Step 4: Run app tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): notification actions and tap navigation"`

---

### Task 7: App wiring and sync triggers

**Files:**
- Create: `MedReport/App/AppDelegate.swift`, `MedReport/App/AppEnvironment.swift`
- Modify: `MedReport/App/MedReportApp.swift`, `MedReport/Views/PlaceholderView.swift`
- Modify: `SETUP.md` (manual device test section)

**Interfaces:**
- Consumes: everything above.
- Produces:

```swift
@MainActor final class AppEnvironment {
    static let shared: AppEnvironment     // one ModelContainer for the scene and the delegate (spec 8.1)
    let container: ModelContainer
    let settings: AppSettings
    let router: NavigationRouter
    let sync: ReminderSync
    let actions: NotificationActionHandler
    static var currentLanguage: AppLanguage { get }   // AppLanguage.current(preferredLanguages: Locale.preferredLanguages)
}
```

Wiring:
- `AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate`. In `application(_:didFinishLaunchingWithOptions:)`: set `UNUserNotificationCenter.current().delegate = self`, set categories for `AppEnvironment.currentLanguage`, start `sync()`.
- `userNotificationCenter(_:didReceive:)`: default action → `handleTap`; other actions → `handle(...)` with `Date()` and `Calendar.current`. `willPresent` → `[.banner, .sound, .list]` (spec 8.4).
- `MedReportApp`: `@UIApplicationDelegateAdaptor`; `.modelContainer(AppEnvironment.shared.container)`; on `scenePhase == .active` → `sync()`; on `UIApplication.significantTimeChangeNotification` → `sync()` (spec 5.4).
- `PlaceholderView` (debug aid until Plan 3): a list of pending notification identifiers and fire dates, a button "Add sample report" (title "Sample report", end date today + 10 days, then save and sync), a toggle for fast mode under `#if DEBUG`, and a button "Request permission" (`requestAuthorization(options: [.alert, .sound, .badge])`).
- "Sync after each save" (spec 5.4): every save in the app goes through `AppEnvironment.shared.saveAndSync()`; add that method (`try container.mainContext.save()` then `await sync.sync()`). Plan 3 views use it.

- [ ] **Step 1: Run app tests**

The wiring has no new unit test; the previous suites must stay green.
Expected: PASS.

- [ ] **Step 2: Manual device test (the user, on a real iPhone)**

Add to `SETUP.md` and run:
1. Run on the iPhone. Tap "Request permission" → allow.
2. Turn on fast mode. Tap "Add sample report". The list shows 64 pending notifications.
3. Lock the phone. A notification comes in about 1 minute with the buttons "Renewed / Yeniledim" and "In 3 hours / 3 saat sonra".
4. Press "Yeniledim" on the lock screen without opening the app. Open the app: the list now shows only `renewal-…` and `backup`.
5. Kill the app (swipe up). Wait for the next notification. Press a button. Open the app: the change is saved.

Expected: all five steps behave as written.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(app): wire delegate, container and sync triggers"
```

---

## Spec coverage of this plan

| Spec item | Task |
|---|---|
| 4 (iOS 17, SwiftUI, SwiftData, privacy: no SDK) | 1 |
| 5.3 Infrastructure components | 3, 5, 6, 7 |
| 5.4 `ReminderSync` and its triggers | 5, 7 |
| 6.1–6.5 Models, settings, calculated values | 2, 3, 4 |
| 7.6 Categories, 7.7 Trigger, 7.8 Fast mode | 5 |
| 8.1–8.4 Setup, buttons, action steps, foreground banner | 5, 6, 7 |
| 13 Error handling (add failure, deleted item, time change) | 5, 6, 7 |
| 14.3 Integration tests, 14.7 CI | 1–6 |
| D10 Language selection in the app layer | 5, 7 |
| 16.1–16.4 Draft code changes | 2 |

Not in this plan: screens (spec 9), onboarding and permission banner (9.2, 13 first two rows), String Catalog (Plan 3); privacy manifest, accessibility pass (Plan 4); 8.5 renewal screen (Plan 3; the model method exists).
