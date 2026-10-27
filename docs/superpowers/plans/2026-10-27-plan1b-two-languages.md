# Plan 1b — Two Languages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Domain kit give English and Turkish text, and change all project text to English.

**Architecture:** A new `AppLanguage` enum goes into the Domain kit. Each function that makes user text receives the language as a parameter. Name matching does not depend on the language. The text tables are Swift code in the kit (spec D11). The app layer selects the language (Plan 2).

**Tech Stack:** Swift 6.1, Swift Package Manager, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-27-ilac-rapor-design.md` (sections 4, 5.2, 6.6, 7.3, 10, 14.2, 16; decisions D10, D11)

**Branch:** continue on `plan1-domain-kit`.

## Global Constraints

- All Global Constraints of Plan 1 apply.
- All code, comments, test names, suite names and documents are in English. Only the Turkish text table and Turkish test values contain Turkish.
- English and Turkish copy is copied exactly from spec 6.6 and 7.3.
- English uses singular for N = 1 and plural for N > 1. Turkish has no plural form.
- `Locale.preferredLanguages` and `Locale.current` are never used in `Sources/IlacRaporKit`.

## Review Focus

1. **A preferred language with a region or script** ("tr-TR", "tr", "TR-tr", "zh-Hant-TW"). Only a language code `tr` (any case) selects Turkish. Test: Task 1, `selectsTurkishOnlyForTr`.
2. **N = 1 in English overdue text.** "Ended 1 day ago.", not "1 days". Test: Task 2, `englishSingular`.
3. **A name in a different language from the phone** ("Irene" typed as "ir", "İlknur" typed as "il"). Expected: the suggestion appears on any phone. Test: Task 3, `dotlessAndDottedIAreTheSameLetter`.
4. **A Turkish name typed without Turkish letters** ("suk" for "Şükrü"). Expected: the suggestion appears. Test: Task 3, `diacriticsAreIgnored`.
5. **A plan where the language changes between two syncs.** The full re-plan uses the new language for all notifications. Test: Task 2, `planUsesSettingsLanguage`.

---

## File Structure

```
Packages/IlacRaporKit/Sources/IlacRaporKit/
├── AppLanguage.swift                       (Task 1, new)
├── StatusText.swift                        (Task 1, new; statusText moves out of ReminderLogic)
├── ReminderLogic.swift                     (Task 1, remove statusText)
├── PersonNameSuggester.swift               (Task 3, loose fold)
└── Notifications/
    ├── NotificationText.swift              (Task 2)
    └── NotificationPlanner.swift           (Task 2, PlannerSettings.language)
Packages/IlacRaporKit/Tests/IlacRaporKitTests/
├── AppLanguageTests.swift                  (Task 1, new)
├── StatusTextTests.swift                   (Task 1, new)
├── ReminderLogicTests.swift                (Task 1, English names, status tests removed)
├── NotificationTextTests.swift             (Task 2)
├── NotificationPlannerTests.swift          (Task 2)
├── PersonNameSuggesterTests.swift          (Task 3)
└── TestSupport.swift                       (Task 2)
IlacRapor/Models/*.swift, IlacRaporTests/ModelTests.swift   (Task 4, English comments and names)
KURULUM.md → SETUP.md                                       (Task 4)
```

---

### Task 1: `AppLanguage` and `StatusText`

**Files:**
- Create: `Sources/IlacRaporKit/AppLanguage.swift`, `Sources/IlacRaporKit/StatusText.swift`
- Modify: `Sources/IlacRaporKit/ReminderLogic.swift` (remove `statusText(daysRemaining:isHandled:)`)
- Create: `Tests/IlacRaporKitTests/AppLanguageTests.swift`, `Tests/IlacRaporKitTests/StatusTextTests.swift`
- Modify: `Tests/IlacRaporKitTests/ReminderLogicTests.swift` (remove the status text suite; change all suite and test display names to English)

**Interfaces:**
- Produces:

```swift
public enum AppLanguage: String, Sendable, CaseIterable {
    case en, tr
    /// `.tr` if the language code of the first entry is "tr" (any case), else `.en`.
    public static func current(preferredLanguages: [String]) -> AppLanguage
    /// Locale for case rules: "en_US" or "tr_TR".
    public var locale: Locale { get }
}

public enum StatusText {
    public static func text(daysRemaining: Int, isHandled: Bool, language: AppLanguage) -> String
}
```

- [ ] **Step 1: Write the failing tests**

```swift
@Suite("AppLanguage")
struct AppLanguageTests {
    @Test func selectsTurkishOnlyForTr() {
        #expect(AppLanguage.current(preferredLanguages: ["tr-TR", "en-US"]) == .tr)
        #expect(AppLanguage.current(preferredLanguages: ["tr"]) == .tr)
        #expect(AppLanguage.current(preferredLanguages: ["TR-tr"]) == .tr)
        #expect(AppLanguage.current(preferredLanguages: ["en-US", "tr-TR"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: ["de-DE"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: ["zh-Hant-TW"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: ["trv"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: []) == .en)
    }

    @Test func localeIdentifiers() {
        #expect(AppLanguage.en.locale.identifier == "en_US")
        #expect(AppLanguage.tr.locale.identifier == "tr_TR")
    }
}

@Suite("StatusText")
struct StatusTextTests {
    @Test(arguments: zip(
        [12, 2, 1, 0, -1, -3],
        ["12 days left", "2 days left", "Ends tomorrow", "Ends today", "1 day overdue", "3 days overdue"]))
    func english(days: Int, expected: String) {
        #expect(StatusText.text(daysRemaining: days, isHandled: false, language: .en) == expected)
    }

    @Test(arguments: zip(
        [12, 2, 1, 0, -1, -3],
        ["12 gün kaldı", "2 gün kaldı", "Yarın bitiyor", "Bugün bitiyor", "1 gün geçti", "3 gün geçti"]))
    func turkish(days: Int, expected: String) {
        #expect(StatusText.text(daysRemaining: days, isHandled: false, language: .tr) == expected)
    }

    @Test func handled() {
        #expect(StatusText.text(daysRemaining: -5, isHandled: true, language: .en) == "Waiting for new date")
        #expect(StatusText.text(daysRemaining: -5, isHandled: true, language: .tr) == "Yeni tarih bekleniyor")
    }
}
```

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit --filter "AppLanguage|StatusText"`
Expected: FAIL (`AppLanguage` not found).

- [ ] **Step 3: Implement `AppLanguage` and `StatusText`; remove `ReminderLogic.statusText` and its suite**

`current`: take the first entry, split at "-" or "_", compare the first part lowercased with "tr".

- [ ] **Step 4: Rename the suites in `ReminderLogicTests.swift` to English**

Use these display names: "Day count", "Reminder state", "Derived dates". Translate every test display name to English with the same meaning. Do not change any assertion.

- [ ] **Step 5: Run all tests**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): add AppLanguage and bilingual StatusText"
```

---

### Task 2: Bilingual `NotificationText` and planner language

**Files:**
- Modify: `Sources/IlacRaporKit/Notifications/NotificationText.swift`
- Modify: `Sources/IlacRaporKit/Notifications/NotificationPlanner.swift`
- Modify: `Tests/IlacRaporKitTests/NotificationTextTests.swift`, `NotificationPlannerTests.swift`, `TestSupport.swift`

**Interfaces:**
- Consumes: `AppLanguage` (Task 1).
- Produces (changed signatures):

```swift
public struct PlannerSettings: Sendable, Equatable {
    public var notificationHour: Int
    public var notificationMinute: Int
    public var language: AppLanguage
    public init(notificationHour: Int, notificationMinute: Int, language: AppLanguage)
}

public enum NotificationText {
    public static func content(for item: ReminderItem, fireDate: Date, calendar: Calendar,
                               language: AppLanguage) -> NotificationContent
    public static func backup(language: AppLanguage) -> NotificationContent
}
```

`NotificationPlanner` passes `settings.language` to `NotificationText`. `TestSupport.tenAM` becomes `PlannerSettings(notificationHour: 10, notificationMinute: 0, language: .tr)`, so all existing planner tests keep their Turkish values.

- [ ] **Step 1: Update the existing text tests and add the English tests**

In `NotificationTextTests`, the existing tests call `text(_:on:)`, which now passes `.tr`. Rename the suite to "NotificationText — Turkish". `backupText` uses `NotificationText.backup(language: .tr)`. Add:

```swift
@Suite("NotificationText — English")
struct NotificationTextEnglishTests {
    let end = date(2026, 11, 5)

    private func text(_ item: ReminderItem, on d: Date) -> NotificationContent {
        NotificationText.content(for: item, fireDate: d, calendar: istanbul, language: .en)
    }

    @Test func reportCases() {
        let r = report(1, title: "Blood pressure report", person: "Dad", end: end)
        #expect(text(r, on: date(2026, 10, 28, 10)) ==
                NotificationContent(title: "Blood pressure report ends in 8 days",
                                    body: "For Dad. Remember to book an appointment.", category: .reportReminder))
        #expect(text(r, on: date(2026, 11, 4, 10)).title == "Blood pressure report ends tomorrow")
        #expect(text(r, on: date(2026, 11, 5, 10)).title == "Blood pressure report ends today")
        #expect(text(r, on: date(2026, 11, 8, 10)) ==
                NotificationContent(title: "Blood pressure report: expired",
                                    body: "Ended 3 days ago.", category: .reportReminder))
    }

    @Test func englishSingular() {
        #expect(text(report(1, end: end), on: date(2026, 11, 6, 10)).body == "Ended 1 day ago.")
        #expect(text(medication(2, end: end), on: date(2026, 11, 6, 10)).body == "Ran out 1 day ago.")
    }

    @Test func handledReport() {
        let r = report(1, title: "Blood pressure report", end: end, handledAt: date(2026, 10, 27))
        #expect(text(r, on: date(2026, 10, 30, 10)) ==
                NotificationContent(title: "Blood pressure report: enter the new end date",
                                    body: "If the report is in the system, save the date.", category: .renewalDate))
    }

    @Test func medicationCases() {
        let m = medication(2, end: end)
        #expect(text(m, on: date(2026, 11, 1, 10)) ==
                NotificationContent(title: "Your Beloc runs out in 4 days",
                                    body: "Remember to get a new box from the pharmacy.", category: .medReminder))
        #expect(text(m, on: date(2026, 11, 4, 10)).title == "Your Beloc runs out tomorrow")
        #expect(text(m, on: date(2026, 11, 5, 10)).title == "Your Beloc runs out today")
        #expect(text(m, on: date(2026, 11, 7, 10)) ==
                NotificationContent(title: "Your Beloc has run out", body: "Ran out 2 days ago.", category: .medReminder))
    }

    @Test func emptyPersonHasNoPersonPart() {
        #expect(text(report(1, person: "  ", end: end), on: date(2026, 10, 28, 10)).body
                == "Remember to book an appointment.")
    }

    @Test func backupText() {
        #expect(NotificationText.backup(language: .en) ==
                NotificationContent(title: "Keep your reminders going",
                                    body: "Open the app once to keep your reminders going.", category: .backup))
    }
}
```

Add to `NotificationPlannerPlanTests`:

```swift
    @Test func planUsesSettingsLanguage() {
        var english = tenAM
        english.language = .en
        let item = report(1, title: "Blood pressure report", end: date(2026, 11, 5))
        let tr = NotificationPlanner.plan(items: [item], now: now, settings: tenAM, calendar: istanbul)
        let en = NotificationPlanner.plan(items: [item], now: now, settings: english, calendar: istanbul)
        #expect(tr.first!.title == "Blood pressure report 8 gün sonra bitiyor")
        #expect(en.first!.title == "Blood pressure report ends in 8 days")
        #expect(en.last!.title == "Keep your reminders going")
        #expect(tr.map(\.identifier) == en.map(\.identifier))
    }
```

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: FAIL (compile error: extra argument `language`).

- [ ] **Step 3: Implement the language parameter and the English table**

Keep the Turkish strings exactly as they are. The planner calls `NotificationText.backup(language: settings.language)`. Update `PlannerSettings` callers in the invalid-settings tests to pass `language: .tr`.

- [ ] **Step 4: Run all tests**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): add English notification text and planner language"
```

---

### Task 3: Loose name matching in `PersonNameSuggester`

**Files:**
- Modify: `Sources/IlacRaporKit/PersonNameSuggester.swift`
- Modify: `Tests/IlacRaporKitTests/PersonNameSuggesterTests.swift`

**Interfaces:**
- Signatures do not change. `suggestions(for:from:)` has no language parameter (spec 10).

Fold rule (spec 10), used for both the prefix match and the duplicate check:
`normalize(text).lowercased(with: Locale(identifier: "tr_TR"))`, then replace "ı" with "i", then `folding(options: .diacriticInsensitive, locale: Locale(identifier: "tr_TR"))`.
(Turkish lowercasing makes "I" → "ı" and "İ" → "i" as single letters; the replace step then makes all four the same.)

- [ ] **Step 1: Add the failing tests**

```swift
    @Test func dotlessAndDottedIAreTheSameLetter() {
        let u = [NameUsage(name: "Irene", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Irmak", usedAt: date(2026, 2, 1)),
                 NameUsage(name: "İlknur", usedAt: date(2026, 3, 1))]
        #expect(PersonNameSuggester.suggestions(for: "ir", from: u) == ["Irmak", "Irene"])
        #expect(PersonNameSuggester.suggestions(for: "ır", from: u) == ["Irmak", "Irene"])
        #expect(PersonNameSuggester.suggestions(for: "İl", from: u) == ["İlknur"])
    }

    @Test func diacriticsAreIgnored() {
        let u = [NameUsage(name: "Şükrü", usedAt: date(2026, 1, 1))]
        #expect(PersonNameSuggester.suggestions(for: "sukru", from: u) == ["Şükrü"])  // full loose match (changed in final review)
        #expect(PersonNameSuggester.suggestions(for: "suk", from: u) == ["Şükrü"])
    }

    @Test func looseDuplicatesMerge() {
        let u = [NameUsage(name: "Sule", usedAt: date(2026, 1, 1)),
                 NameUsage(name: "Şule", usedAt: date(2026, 2, 1))]
        #expect(PersonNameSuggester.suggestions(for: "", from: u) == ["Şule"])
    }
```

Keep all existing tests. Rename `turkishDottedAndDotlessI` to `turkishCaseRulesStillMatch`.

- [ ] **Step 2: Run the tests to make sure they fail**

Run: `swift test --package-path Packages/IlacRaporKit --filter PersonNameSuggester`
Expected: FAIL (`dotlessAndDottedIAreTheSameLetter` gets `["Irmak"]`).

- [ ] **Step 3: Implement the fold rule**

- [ ] **Step 4: Run all tests**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/IlacRaporKit
git commit -m "feat(kit): loose name matching for i/ı and diacritics"
```

---

### Task 4: English project text

**Files:**
- Modify: `IlacRapor/Models/Report.swift`, `IlacRapor/Models/Medication.swift` (comments only)
- Modify: `IlacRaporTests/ModelTests.swift` (suite and test display names, comments only)
- Move: `KURULUM.md` → `SETUP.md` (translate to English; keep the same steps)
- Modify: any other comment in `Packages/IlacRaporKit/Sources` that is in Turkish

- [ ] **Step 1: Translate**

Do not change any code, value or assertion. Turkish strings that are test values (for example "Babam", "Tansiyon raporu") stay.

- [ ] **Step 2: Check that no Turkish comment or name is left**

Run: `grep -rnP "[çğıöşüÇĞİÖŞÜ]" --include=*.swift --include=*.md IlacRapor IlacRaporTests Packages SETUP.md | grep -vE '"[^"]*[çğıöşüÇĞİÖŞÜ][^"]*"'`
Expected: no output (only lines with Turkish inside string literals are allowed).

- [ ] **Step 3: Run all tests**

Run: `swift test --package-path Packages/IlacRaporKit`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: change project text to English"
```

---

## Spec coverage of this plan

| Spec item | Task |
|---|---|
| D10, D11, 4 (language selection) | 1 |
| 6.6 status text, both languages | 1 |
| 7.3 text, both languages; planner language | 2 |
| 10 loose name matching | 3 |
| 14.2 new unit tests | 1, 2, 3 |
| 16.5 English project text | 4 |

Not in this plan: reading `Locale.preferredLanguages` in the app and the String Catalog for screens (Plans 2 and 3).
