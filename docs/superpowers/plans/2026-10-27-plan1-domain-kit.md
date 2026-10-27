# Plan 1 — Domain Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Domain layer of IlacRapor as a Swift package (`IlacRaporKit`) with full tests and CI.

**Architecture:** The Domain layer is a local Swift package that uses only Foundation. The iOS app (Plan 2) imports it. Thus, `swift test` runs the tests on macOS and on Linux without a simulator.

**Tech Stack:** Swift 6.1, Swift Package Manager, Swift Testing, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-27-ilac-rapor-design.md`

**Plan series:** Plan 1 (this plan): Domain kit and CI. Plan 2: app shell, SwiftData models, `ReminderItem` mapping, `ReminderSync`, scheduler, actions. Plan 3: screens. Plan 4: onboarding, settings, privacy, accessibility pass.

## Global Constraints

- `swift-tools-version: 6.0`. Swift 6 language mode.
- Platforms: `.iOS(.v17)`, `.macOS(.v14)`.
- Files in `Sources/IlacRaporKit` import only `Foundation`.
- No file in `Sources/IlacRaporKit` uses `Date()`, `Date.now`, `.now` or `Calendar.current`. Each function receives `now` and a `Calendar`.
- All types that the app uses are `public`. All value types are `Sendable`.
- Tests use Swift Testing only (`import Testing`). No XCTest.
- All user text is Turkish and is copied exactly from spec 7.3 and 6.6.
- Notification limits: 64 in total, 63 for each item, 1 backup (spec 7.4).
- Handled report interval: 3 days (spec 7.2).
- Run the tests from the repository root: `swift test --package-path Packages/IlacRaporKit`.

## Review Focus

1. **Very many items (70 overdue items).** The total stays at 64 and the earliest notifications are kept. Test: Task 6, `seventyItemsKeepEarliest`.
2. **A fire time equal to `now`.** That notification is not planned, because it cannot fire. Test: Task 5, `fireTimeEqualToNowIsSkipped`.
3. **A person name that contains only spaces.** The body does not show " için.". Test: Task 4, `whitespacePersonIsEmpty`.
4. **A notification time that does not exist on a daylight saving day** (02:30 in Berlin on 29 March 2026). The day still gets one notification on the correct date. Test: Task 5, `nonexistentLocalTimeStillPlansThatDay`.
5. **Two notifications with the same fire date and the same priority.** The order is stable (identifier ascending). Thus, the same input always gives the same 63 notifications. Test: Task 6, `samePrioritySortsByIdentifier`.

---

## File Structure

```
Packages/IlacRaporKit/
├── Package.swift
├── Sources/IlacRaporKit/
│   ├── ReminderState.swift          (moved from the app, made public)
│   ├── ReminderLogic.swift          (moved from the app, made public)
│   ├── ReminderItem.swift           (Task 2)
│   ├── PersonNameSuggester.swift    (Task 3)
│   └── Notifications/
│       ├── PlannedNotification.swift   (Task 4)
│       ├── NotificationText.swift      (Task 4)
│       └── NotificationPlanner.swift   (Tasks 5, 6)
└── Tests/IlacRaporKitTests/
    ├── TestSupport.swift
    ├── ReminderLogicTests.swift     (moved from the app)
    ├── ReminderItemTests.swift
    ├── PersonNameSuggesterTests.swift
    ├── NotificationTextTests.swift
    └── NotificationPlannerTests.swift
.github/workflows/ci.yml
```

---

### Task 1: Package, moved logic and CI

**Files:**
- Create: `Packages/IlacRaporKit/Package.swift`
- Move: `IlacRapor/Services/ReminderLogic.swift` → `Packages/IlacRaporKit/Sources/IlacRaporKit/ReminderLogic.swift`
- Move: `IlacRapor/Models/ReminderState.swift` → `Packages/IlacRaporKit/Sources/IlacRaporKit/ReminderState.swift`
- Move: `IlacRaporTests/ReminderLogicTests.swift` → `Packages/IlacRaporKit/Tests/IlacRaporKitTests/ReminderLogicTests.swift`
- Create: `Packages/IlacRaporKit/Tests/IlacRaporKitTests/TestSupport.swift`
- Modify: `IlacRapor/Models/Report.swift`, `IlacRapor/Models/Medication.swift` (add `import IlacRaporKit` only)
- Modify: `KURULUM.md` (add the step to link the local package)
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: library product `IlacRaporKit`. `public enum ReminderState` and `public enum ReminderLogic` with the same members as the draft.
- Produces (tests only): `TestSupport.swift`:
  - `let istanbul: Calendar` (Gregorian, `Europe/Istanbul`)
  - `func calendar(_ timeZone: String) -> Calendar`
  - `func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, in cal: Calendar = istanbul) -> Date`
  - `func uuid(_ n: Int) -> UUID` gives `00000000-0000-0000-0000-` followed by `n` as 12 digits.

- [ ] **Step 1: Make the package and move the files**

`Package.swift`: one library product and one target `IlacRaporKit`, one test target `IlacRaporKitTests`. Use `git mv` for the three moved files. Make every type and member in the two moved source files `public`. In the moved test file, change `@testable import IlacRapor` to `@testable import IlacRaporKit`. Move its private `calendar` and `date` helpers to `TestSupport.swift` (internal, not private).

- [ ] **Step 2: Run the tests**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: all tests in `ReminderLogicTests.swift` PASS.

- [ ] **Step 3: Check the Domain rule**

Run: `grep -rnE "Date\(\)|Date\.now|\.now\b|Calendar\.current" Packages/IlacRaporKit/Sources || echo CLEAN`
Expected: `CLEAN`

- [ ] **Step 4: Add the import to the draft models**

Add `import IlacRaporKit` to `Report.swift` and `Medication.swift`. Do not change anything else. Plan 2 changes these files.

In `KURULUM.md`, add: "Xcode → File → Add Package Dependencies → Add Local… → `Packages/IlacRaporKit`. Add `IlacRaporKit` to the app target."

- [ ] **Step 5: Add CI**

`.github/workflows/ci.yml`: trigger on `push` and `pull_request`. One job on `macos-15`. Steps: `actions/checkout@v4`, then `swift test --package-path Packages/IlacRaporKit`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "build: move domain logic into IlacRaporKit package, add CI"
```

---

### Task 2: `ReminderItem` and urgency order

**Files:**
- Create: `Packages/IlacRaporKit/Sources/IlacRaporKit/ReminderItem.swift`
- Test: `Packages/IlacRaporKit/Tests/IlacRaporKitTests/ReminderItemTests.swift`
- Modify: `TestSupport.swift` (add the factories below)

**Interfaces:**
- Consumes: `ReminderLogic.daysRemaining(until:now:calendar:)`, `ReminderLogic.state(endDate:leadDays:isHandled:now:calendar:)`, `ReminderState.sortPriority`.
- Produces:

```swift
public struct ReminderItem: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable { case report, medication }
    public let kind: Kind
    public let id: UUID
    public let title: String        // report title or medication name
    public let personName: String   // effective person name (spec 6.5)
    public let endDate: Date        // report end date or supply end date
    public let leadDays: Int
    public let isHandled: Bool      // always false for a medication
    public let handledAt: Date?
    public let snoozeUntil: Date?
    public init(kind: Kind, id: UUID, title: String, personName: String, endDate: Date,
                leadDays: Int, isHandled: Bool = false, handledAt: Date? = nil, snoozeUntil: Date? = nil)
    public func daysRemaining(now: Date, calendar: Calendar) -> Int
    public func state(now: Date, calendar: Calendar) -> ReminderState
    public static func sortedByUrgency(_ items: [ReminderItem], now: Date, calendar: Calendar) -> [ReminderItem]
}
```

- Produces (tests only), in `TestSupport.swift`:
  - `func report(_ n: Int, title: String = "Tansiyon raporu", person: String = "Babam", end: Date, lead: Int = 18, handledAt: Date? = nil, snooze: Date? = nil) -> ReminderItem` (id `uuid(n)`, `isHandled` = `handledAt != nil`)
  - `func medication(_ n: Int, name: String = "Beloc", person: String = "Babam", end: Date, lead: Int = 7, snooze: Date? = nil) -> ReminderItem` (id `uuid(n)`)

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("ReminderItem")
struct ReminderItemTests {
    let now = date(2026, 10, 27)

    @Test func stateAndDaysUseLogic() {
        let r = report(1, end: date(2026, 11, 5))
        #expect(r.daysRemaining(now: now, calendar: istanbul) == 9)
        #expect(r.state(now: now, calendar: istanbul) == .reminding)
    }

    @Test func urgencyOrder() {
        let overdue  = report(1, end: date(2026, 10, 24))                              // -3
        let tomorrow = medication(2, end: date(2026, 10, 28))                          // 1
        let handled  = report(3, title: "Kardiyoloji raporu", end: date(2026, 10, 20),
                              handledAt: date(2026, 10, 21))
        let normal24 = medication(4, name: "Parol", end: date(2026, 11, 20))           // 24
        let normal19 = medication(5, name: "Coraspin", end: date(2026, 11, 15))        // 19
        let sorted = ReminderItem.sortedByUrgency([normal24, handled, normal19, tomorrow, overdue],
                                                  now: now, calendar: istanbul)
        #expect(sorted.map(\.id) == [uuid(1), uuid(2), uuid(3), uuid(5), uuid(4)])
    }

    @Test func sameStateAndDaysSortsByTitle() {
        let b = medication(1, name: "Beloc", end: date(2026, 11, 15))
        let a = medication(2, name: "Aspirin", end: date(2026, 11, 15))
        #expect(ReminderItem.sortedByUrgency([b, a], now: now, calendar: istanbul).map(\.title)
                == ["Aspirin", "Beloc"])
    }
}
```

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit --filter ReminderItem`
Expected: FAIL (`ReminderItem` not found).

- [ ] **Step 3: Implement `ReminderItem`**

Order for `sortedByUrgency`: `state.sortPriority` ascending, then `daysRemaining` ascending, then `title` ascending, then `id.uuidString` ascending.

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): add ReminderItem with urgency order"
```

---

### Task 3: `PersonNameSuggester`

**Files:**
- Create: `Packages/IlacRaporKit/Sources/IlacRaporKit/PersonNameSuggester.swift`
- Test: `Packages/IlacRaporKit/Tests/IlacRaporKitTests/PersonNameSuggesterTests.swift`

**Interfaces:**
- Produces:

```swift
public struct NameUsage: Sendable, Equatable {
    public let name: String
    public let usedAt: Date
    public init(name: String, usedAt: Date)
}
public enum PersonNameSuggester {
    public static func normalize(_ name: String) -> String
    public static func suggestions(for typed: String, from usages: [NameUsage]) -> [String]
}
```

Rules (spec 10):
- `normalize` removes whitespace and newlines at the start and at the end.
- Two names are the same if their lowercased forms with `Locale(identifier: "tr_TR")` are equal. The result keeps the spelling with the latest `usedAt`.
- A suggestion starts with `normalize(typed)` when the app compares lowercased forms with the Turkish locale.
- A name equal to the typed text (Turkish lowercase) is not a suggestion.
- Empty names are ignored.
- The result is sorted by `usedAt`, latest first.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("PersonNameSuggester")
struct PersonNameSuggesterTests {
    @Test func normalizeTrims() {
        #expect(PersonNameSuggester.normalize("  Babam \n") == "Babam")
    }

    @Test func caseInsensitiveDedupKeepsLatestSpelling() {
        let u = [NameUsage(name: "babam", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Babam", usedAt: date(2026, 5, 1))]
        #expect(PersonNameSuggester.suggestions(for: "", from: u) == ["Babam"])
    }

    @Test func prefixMatchIgnoresCase() {
        let u = [NameUsage(name: "Babam", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Annem", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "bab", from: u) == ["Babam"])
    }

    @Test func turkishDottedAndDotlessI() {
        let u = [NameUsage(name: "İlknur", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Irmak", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "il", from: u) == ["İlknur"])
        #expect(PersonNameSuggester.suggestions(for: "ır", from: u) == ["Irmak"])
    }

    @Test func exactMatchIsNotSuggested() {
        let u = [NameUsage(name: "Babam", usedAt: date(2026, 1, 1))]
        #expect(PersonNameSuggester.suggestions(for: "babam", from: u).isEmpty)
    }

    @Test func latestFirstAndEmptyIgnored() {
        let u = [NameUsage(name: "Annem", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "  ", usedAt: date(2026, 3, 1)),
                 NameUsage(name: "Ablam", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "", from: u) == ["Ablam", "Annem"])
    }
}
```

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit --filter PersonNameSuggester`
Expected: FAIL (`PersonNameSuggester` not found).

- [ ] **Step 3: Implement `PersonNameSuggester`**

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): add PersonNameSuggester with Turkish case rules"
```

---

### Task 4: `PlannedNotification` and `NotificationText`

**Files:**
- Create: `Packages/IlacRaporKit/Sources/IlacRaporKit/Notifications/PlannedNotification.swift`
- Create: `Packages/IlacRaporKit/Sources/IlacRaporKit/Notifications/NotificationText.swift`
- Test: `Packages/IlacRaporKit/Tests/IlacRaporKitTests/NotificationTextTests.swift`

**Interfaces:**
- Consumes: `ReminderItem`, `ReminderItem.daysRemaining(now:calendar:)`.
- Produces:

```swift
public struct PlannedNotification: Sendable, Equatable {
    public enum Category: String, Sendable, CaseIterable {
        case reportReminder = "REPORT_REMINDER"
        case medReminder = "MED_REMINDER"
        case renewalDate = "RENEWAL_DATE"
        case backup = "BACKUP"
    }
    public let identifier: String
    public let fireDate: Date
    public let title: String
    public let body: String
    public let category: Category
    public let itemKind: ReminderItem.Kind?   // nil for the backup
    public let itemID: UUID?                  // nil for the backup
    public init(identifier: String, fireDate: Date, title: String, body: String,
                category: Category, itemKind: ReminderItem.Kind?, itemID: UUID?)
}

public struct NotificationContent: Sendable, Equatable {
    public let title: String
    public let body: String
    public let category: PlannedNotification.Category
}

public enum NotificationText {
    /// Text for `item` on `fireDate`. Days are calculated from `fireDate`, not from now.
    public static func content(for item: ReminderItem, fireDate: Date, calendar: Calendar) -> NotificationContent
    public static let backup: NotificationContent
}
```

Copy (spec 7.3, exact). `{N}` is a positive number. The person part is `"{person} için. "` only when `normalize(person)` is not empty.

| Case | Title | Body | Category |
|---|---|---|---|
| Report, N > 1 | `"{title} {N} gün sonra bitiyor"` | `"{person} için. Randevu almayı unutma."` | `.reportReminder` |
| Report, 1 | `"{title} yarın bitiyor"` | same | `.reportReminder` |
| Report, 0 | `"{title} bugün bitiyor"` | same | `.reportReminder` |
| Report, overdue | `"{title} süresi doldu"` | `"{N} gün önce bitti."` | `.reportReminder` |
| Report, handled | `"{title}: yeni bitiş tarihini gir"` | `"Rapor sisteme işlendiyse tarihi kaydet."` | `.renewalDate` |
| Medication, N > 1 | `"{name} ilacın {N} gün sonra bitiyor"` | `"Eczaneden yenisini almayı unutma."` | `.medReminder` |
| Medication, 1 | `"{name} ilacın yarın bitiyor"` | same | `.medReminder` |
| Medication, 0 | `"{name} ilacın bugün bitiyor"` | same | `.medReminder` |
| Medication, overdue | `"{name} ilacın bitti"` | `"{N} gün önce bitti."` | `.medReminder` |
| Backup | `"Hatırlatmalar devam etsin"` | `"Hatırlatmaların devam etmesi için uygulamayı bir kez aç."` | `.backup` |

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("NotificationText")
struct NotificationTextTests {
    let end = date(2026, 11, 5)

    private func text(_ item: ReminderItem, on d: Date) -> NotificationContent {
        NotificationText.content(for: item, fireDate: d, calendar: istanbul)
    }

    @Test func reportDaysUseFireDate() {
        let r = report(1, end: end)
        #expect(text(r, on: date(2026, 10, 28, 10)) ==
                NotificationContent(title: "Tansiyon raporu 8 gün sonra bitiyor",
                                    body: "Babam için. Randevu almayı unutma.", category: .reportReminder))
        #expect(text(r, on: date(2026, 11, 4, 10)).title == "Tansiyon raporu yarın bitiyor")
        #expect(text(r, on: date(2026, 11, 5, 10)).title == "Tansiyon raporu bugün bitiyor")
    }

    @Test func reportOverdue() {
        #expect(text(report(1, end: end), on: date(2026, 11, 8, 10)) ==
                NotificationContent(title: "Tansiyon raporu süresi doldu",
                                    body: "3 gün önce bitti.", category: .reportReminder))
    }

    @Test func handledReport() {
        let r = report(1, end: end, handledAt: date(2026, 10, 27))
        #expect(text(r, on: date(2026, 10, 30, 10)) ==
                NotificationContent(title: "Tansiyon raporu: yeni bitiş tarihini gir",
                                    body: "Rapor sisteme işlendiyse tarihi kaydet.", category: .renewalDate))
    }

    @Test func medicationCases() {
        let m = medication(2, end: end)
        #expect(text(m, on: date(2026, 11, 1, 10)) ==
                NotificationContent(title: "Beloc ilacın 4 gün sonra bitiyor",
                                    body: "Eczaneden yenisini almayı unutma.", category: .medReminder))
        #expect(text(m, on: date(2026, 11, 4, 10)).title == "Beloc ilacın yarın bitiyor")
        #expect(text(m, on: date(2026, 11, 5, 10)).title == "Beloc ilacın bugün bitiyor")
        #expect(text(m, on: date(2026, 11, 7, 10)) ==
                NotificationContent(title: "Beloc ilacın bitti", body: "2 gün önce bitti.", category: .medReminder))
    }

    @Test func emptyPersonHasNoPersonPart() {
        #expect(text(report(1, person: "", end: end), on: date(2026, 10, 28, 10)).body == "Randevu almayı unutma.")
    }

    @Test func whitespacePersonIsEmpty() {
        #expect(text(report(1, person: "   ", end: end), on: date(2026, 10, 28, 10)).body == "Randevu almayı unutma.")
    }

    @Test func backupText() {
        #expect(NotificationText.backup ==
                NotificationContent(title: "Hatırlatmalar devam etsin",
                                    body: "Hatırlatmaların devam etmesi için uygulamayı bir kez aç.", category: .backup))
    }
}
```

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit --filter NotificationText`
Expected: FAIL (`NotificationText` not found).

- [ ] **Step 3: Implement `PlannedNotification`, `NotificationContent` and `NotificationText`**

Use `PersonNameSuggester.normalize` for the person check. Add a memberwise `public init` to `NotificationContent` for the tests.

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): add notification text for all cases in spec 7.3"
```

---

### Task 5: Candidate notifications for one item

**Files:**
- Create: `Packages/IlacRaporKit/Sources/IlacRaporKit/Notifications/NotificationPlanner.swift`
- Test: `Packages/IlacRaporKit/Tests/IlacRaporKitTests/NotificationPlannerTests.swift`
- Modify: `TestSupport.swift` (add `let tenAM = PlannerSettings(notificationHour: 10, notificationMinute: 0)`)

**Interfaces:**
- Consumes: `ReminderItem`, `ReminderLogic.reminderStartDate(endDate:leadDays:calendar:)`, `NotificationText.content(for:fireDate:calendar:)`, `PlannedNotification`.
- Produces:

```swift
public struct PlannerSettings: Sendable, Equatable {
    public var notificationHour: Int
    public var notificationMinute: Int
    public init(notificationHour: Int, notificationMinute: Int)
}

public enum NotificationPlanner {
    public static let maxPending = 64
    public static let maxPerItem = 63
    public static let renewalIntervalDays = 3

    /// Internal. Tested with @testable import.
    static func candidates(for item: ReminderItem, now: Date,
                           settings: PlannerSettings, calendar: Calendar) -> [PlannedNotification]
}
```

Rules (spec 7.2, 7.5):
- **Fire time on a day:** `calendar.date(bySettingHour:minute:second: 0, of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)`.
- **A candidate is valid only if `fireDate > now`.**
- **Not handled:** start day = later of (reminder start date, start of today). Make one candidate each day from the start day. Skip the days whose fire time is not after `now`. Stop at `maxPerItem` candidates. Identifier: `"report-<UUID>-<yyyyMMdd>"` or `"med-<UUID>-<yyyyMMdd>"`.
- **Handled report:** days `startOfDay(handledAt) + 3k` for k = 1, 2, 3, … Skip the days whose fire time is not after `now`. Stop at `maxPerItem`. Identifier: `"renewal-<UUID>-<yyyyMMdd>"`.
- **Snooze:** if `snoozeUntil > now`, add one candidate at `snoozeUntil` with identifier `"snooze-<UUID>"`. The snooze counts toward `maxPerItem`: keep the snooze and drop the last daily candidate.
- `<UUID>` is `id.uuidString`. `yyyyMMdd` comes from `calendar.dateComponents([.year, .month, .day], from: fireDate)` with zero padding. Do not use `DateFormatter`.
- Text and category come from `NotificationText.content(for:fireDate:calendar:)`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("NotificationPlanner — candidates")
struct NotificationPlannerCandidateTests {
    let now = date(2026, 10, 27, 12)          // after 10:00
    let id1 = uuid(1).uuidString

    private func c(_ item: ReminderItem, now: Date? = nil, settings: PlannerSettings = tenAM,
                   cal: Calendar = istanbul) -> [PlannedNotification] {
        NotificationPlanner.candidates(for: item, now: now ?? self.now, settings: settings, calendar: cal)
    }

    @Test func inWindowStartsTomorrowWhenTimeIsPast() {
        let first = c(report(1, end: date(2026, 11, 5))).first!
        #expect(first.identifier == "report-\(id1)-20261028")
        #expect(first.fireDate == date(2026, 10, 28, 10))
        #expect(first.title == "Tansiyon raporu 8 gün sonra bitiyor")
        #expect(first.category == .reportReminder)
        #expect(first.itemKind == .report)
        #expect(first.itemID == uuid(1))
    }

    @Test func inWindowStartsTodayBeforeTime() {
        let first = c(report(1, end: date(2026, 11, 5)), now: date(2026, 10, 27, 9)).first!
        #expect(first.fireDate == date(2026, 10, 27, 10))
    }

    @Test func fireTimeEqualToNowIsSkipped() {
        let first = c(report(1, end: date(2026, 11, 5)), now: date(2026, 10, 27, 10)).first!
        #expect(first.fireDate == date(2026, 10, 28, 10))
    }

    @Test func normalItemStartsAtReminderStart() {
        let first = c(medication(1, end: date(2026, 12, 26))).first!
        #expect(first.identifier == "med-\(id1)-20261219")
        #expect(first.title == "Beloc ilacın 7 gün sonra bitiyor")
    }

    @Test func dailyAndOverdueContinueTo63() {
        let all = c(report(1, end: date(2026, 11, 5)))
        #expect(all.count == 63)
        #expect(all.last!.fireDate == date(2026, 12, 29, 10))
        #expect(all.last!.title == "Tansiyon raporu süresi doldu")
    }

    @Test func handledReportEveryThreeDays() {
        let all = c(report(1, end: date(2026, 10, 20), handledAt: date(2026, 10, 27, 12)))
        #expect(all.prefix(3).map(\.identifier) ==
                ["renewal-\(id1)-20261030", "renewal-\(id1)-20261102", "renewal-\(id1)-20261105"])
        #expect(all.allSatisfy { $0.category == .renewalDate })
        #expect(all.count == 63)
    }

    @Test func handledLongAgoSkipsPastDays() {
        let first = c(report(1, end: date(2026, 9, 1), handledAt: date(2026, 10, 1))).first!
        #expect(first.fireDate == date(2026, 10, 28, 10))
    }

    @Test func futureSnoozeIsAdded() {
        let all = c(report(1, end: date(2026, 11, 5), snooze: date(2026, 10, 27, 15)))
        let snooze = all.first { $0.identifier == "snooze-\(id1)" }!
        #expect(snooze.fireDate == date(2026, 10, 27, 15))
        #expect(snooze.title == "Tansiyon raporu 9 gün sonra bitiyor")
        #expect(all.count == 63)
    }

    @Test func pastSnoozeIsIgnored() {
        let all = c(report(1, end: date(2026, 11, 5), snooze: date(2026, 10, 27, 11)))
        #expect(!all.contains { $0.identifier.hasPrefix("snooze-") })
    }

    @Test func nonexistentLocalTimeStillPlansThatDay() {
        let berlin = calendar("Europe/Berlin")
        let all = c(report(1, end: date(2026, 4, 5, in: berlin)),
                    now: date(2026, 3, 20, 12, in: berlin),
                    settings: PlannerSettings(notificationHour: 2, notificationMinute: 30), cal: berlin)
        let dstDay = all.filter { $0.identifier.hasSuffix("-20260329") }
        #expect(dstDay.count == 1)
        #expect(berlin.component(.day, from: dstDay[0].fireDate) == 29)
    }
}
```

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit --filter NotificationPlanner`
Expected: FAIL (`PlannerSettings` not found).

- [ ] **Step 3: Implement `PlannerSettings` and `NotificationPlanner.candidates(for:now:settings:calendar:)`**

- [ ] **Step 4: Run the tests to make sure they pass**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): plan candidate notifications for one item"
```

---

### Task 6: The full plan with the 64 limit and the backup

**Files:**
- Modify: `Packages/IlacRaporKit/Sources/IlacRaporKit/Notifications/NotificationPlanner.swift`
- Test: `Packages/IlacRaporKit/Tests/IlacRaporKitTests/NotificationPlannerTests.swift` (new suite in the same file)

**Interfaces:**
- Consumes: `candidates(for:now:settings:calendar:)`, `NotificationText.backup`, `ReminderItem.state(now:calendar:)`, `ReminderState.sortPriority`.
- Produces:

```swift
extension NotificationPlanner {
    public static func plan(items: [ReminderItem], now: Date,
                            settings: PlannerSettings, calendar: Calendar) -> [PlannedNotification]
}
```

Rules (spec 7.4):
1. Collect the candidates of all items.
2. Sort by `fireDate` ascending. If equal, by the `sortPriority` of the item state **on the fire date**. If equal, by `identifier` ascending.
3. Keep the first `maxPending − 1` (63).
4. If at least one is kept, add the backup: identifier `"backup"`, fire time on the day after the day of the last kept notification, `itemKind` and `itemID` nil.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("NotificationPlanner — plan")
struct NotificationPlannerPlanTests {
    let now = date(2026, 10, 27, 12)

    private func p(_ items: [ReminderItem]) -> [PlannedNotification] {
        NotificationPlanner.plan(items: items, now: now, settings: tenAM, calendar: istanbul)
    }

    @Test func noItemsNoBackup() {
        #expect(p([]).isEmpty)
    }

    @Test func singleItemIs63PlusBackup() {
        let all = p([report(1, end: date(2026, 11, 5))])
        #expect(all.count == 64)
        #expect(all.last!.identifier == "backup")
        #expect(all.last!.fireDate == date(2026, 12, 30, 10))
        #expect(all.last!.category == .backup)
        #expect(all.last!.itemID == nil)
    }

    @Test func tenItemsNeverAbove64() {
        let items = (1...10).map { report($0, end: date(2026, 10, 20)) }
        let all = p(items)
        #expect(all.count == 64)
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.fireDate <= $1.fireDate })
        #expect(all.prefix(10).allSatisfy { $0.fireDate == date(2026, 10, 28, 10) })
    }

    @Test func seventyItemsKeepEarliest() {
        let items = (1...70).map { report($0, end: date(2026, 10, 20)) }
        let all = p(items)
        #expect(all.count == 64)
        #expect(all.prefix(63).allSatisfy { $0.fireDate == date(2026, 10, 28, 10) })
        #expect(all.last!.fireDate == date(2026, 10, 29, 10))
    }

    @Test func overdueComesFirstOnSameDate() {
        let reminding = medication(1, end: date(2026, 11, 1))      // reminding on 28 Oct
        let overdue = report(2, end: date(2026, 10, 20))           // overdue on 28 Oct
        let all = p([reminding, overdue])
        #expect(all[0].itemID == uuid(2))
        #expect(all[1].itemID == uuid(1))
    }

    @Test func samePrioritySortsByIdentifier() {
        let all = p([report(2, end: date(2026, 10, 20)), report(1, end: date(2026, 10, 20))])
        #expect(all[0].itemID == uuid(1))
        #expect(all[1].itemID == uuid(2))
    }

    @Test func snoozeStaysAfterReplan() {
        let all = p([report(1, end: date(2026, 11, 5), snooze: date(2026, 10, 27, 15))])
        #expect(all.first!.identifier == "snooze-\(uuid(1).uuidString)")
    }
}
```

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit --filter NotificationPlannerPlanTests`
Expected: FAIL (`plan` not found).

- [ ] **Step 3: Implement `NotificationPlanner.plan(items:now:settings:calendar:)`**

- [ ] **Step 4: Run all tests and the Domain rule check**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS, all suites.

Run: `grep -rnE "Date\(\)|Date\.now|\.now\b|Calendar\.current" Packages/IlacRaporKit/Sources || echo CLEAN`
Expected: `CLEAN`

- [ ] **Step 5: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): plan all notifications with 64 limit and backup"
```

---

## Spec coverage of this plan

| Spec section | Task |
|---|---|
| 5.1, 5.2 Domain layer, pure functions | 1 (rule check), 2–6 |
| 6.5 Days remaining, 6.6 States and sort priority | 1 (moved), 2 |
| 7.1–7.5 Planner, text, limit, identifiers | 4, 5, 6 |
| 7.6 Categories (raw values) | 4 |
| 10 Name suggestions | 3 |
| 14.1, 14.2 Unit tests (except `ReminderItem` mapping) | 1–6 |
| 14.7 CI | 1 |

Not in this plan: 6.1–6.4 SwiftData models and `AppSettings`, 7.7–7.8 trigger and fast mode, 8 actions, 9 screens, 11–13, 14.2 mapping, 14.3–14.6. These are in Plans 2 to 4.
