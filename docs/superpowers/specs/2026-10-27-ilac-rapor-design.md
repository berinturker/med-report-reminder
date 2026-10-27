# IlacRapor — Design Specification

- **Date:** 27 October 2026
- **Status:** Approved design. Written to the ASD-STE100 rules.
- **Source:** `PLAN.md` (the first plan) and the brainstorming session of 27 October 2026.
- **Language of the app:** Turkish. All user text in this document is in Turkish.

---

## 1. Purpose

### 1.1 Problem

People with a chronic disease have medication reports ("ilaç raporu"). Each report has an end date. When a report ends, the medication becomes expensive or the pharmacy cannot give it. To renew a report, the person must get a doctor appointment, go to the doctor and wait until the system shows the new report. This process can take many weeks.

Also, each box of medication becomes empty. The person must get a new box from the pharmacy before this occurs.

### 1.2 Goal

The app reminds the user each day before a report ends and before a medication box becomes empty. The reminders continue until the user does the necessary action.

### 1.3 Users

- The first user is the father of the developer. He is more than 50 years old. He uses an iPhone. His skill with technology is medium.
- Later, the app is for all users in the App Store.

### 1.4 Success criterion

After the user enters a report or a medication, the user does not miss an end date. This is true also when the user does not open the app.

### 1.5 Release strategy

1. **v1:** Portfolio quality. The first user gets the app through TestFlight.
2. **App Store:** After v1 is stable. All decisions in this document are compatible with the App Store.

---

## 2. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | v1 is portfolio quality. The App Store release comes later. | The App Store process makes v1 slower. |
| D2 | All user text is general. The code contains no names such as "Babam". | App Store compatibility. |
| D3 | The app collects no data. It has no analytics and no third-party SDK. | Health data stays on the device. The App Store privacy label is "Data Not Collected". |
| D4 | The "Kimin için" field is free text with suggestions. | Simple model. A later migration to a `Person` model is possible. |
| D5 | There is one notification time for all items. The default is 10:00. | Easy for the user. Easy to calculate the 64-notification limit. |
| D6 | The user can archive an item ("Takibi durdur"). The user can also delete an item. | Archive is reversible. "Sil" is frightening for an older user. |
| D7 | The architecture is MV with pure services. The forms use small `@Observable` models. | `@Query` operates only in views. The difficult logic is in pure services. |
| D8 | A handled report gets a notification every 3 days. | Without this, the app is silent forever if the user forgets the new date. |
| D9 | The visual style is similar to Cal AI, Apple Health and Gentler Streak. | Large numbers, high contrast, cards. Color shows only the state. |

---

## 3. Scope

### 3.1 v1

- Add, edit, archive, restore and delete a report.
- Add, edit, archive, restore and delete a medication. A medication can have a report or no report.
- Home screen with the hero card, the upcoming strip and the lists.
- Daily local notifications.
- Notification buttons: "Yeniledim" or "Aldım", and "3 saat sonra".
- Renewal flow for a report. Pickup flow for a medication.
- Settings: notification time and default day counts.
- "Kimin için" field with name suggestions.
- Warning when the notification permission is off.
- Dynamic Type and VoiceOver support.
- Medical disclaimer and privacy policy link.

### 3.2 Later versions (not in v1)

- iCloud sync. The model is compatible now.
- Notification to a family member.
- Calendar export.
- Photo of a report or a medication box.
- Stock calculation from box count, tablet count and daily dose.
- Widget.
- Read the date from a report with the camera (Vision OCR).
- A `Person` model.
- One summary notification for many items on the same day.
- Background refresh with `BGAppRefreshTask`.
- English language.

### 3.3 Out of scope

- Backend, user accounts and login.
- e-Nabız and MHRS integration. These systems have no public API.
- Reminders to take a medication at a time of day. That is a different product.

---

## 4. Technical base

- **Platform:** iOS 17 and later. iPhone only.
- **UI:** SwiftUI.
- **Data:** SwiftData, local only.
- **Notifications:** `UserNotifications`, local only.
- **Text:** A String Catalog (`Localizable.xcstrings`). Thus, a new language is easy to add later.
- **Privacy manifest:** `PrivacyInfo.xcprivacy`. It declares no data collection. It declares the `UserDefaults` API with the reason code `CA92.1`.
- **Fonts:** SF Pro Rounded for numbers and headings. SF Pro for body text.

---

## 5. Architecture

### 5.1 Layers

The app has three layers:

- **Views** use the Domain layer.
- **Infrastructure** uses the Domain layer.
- **Domain** uses only Foundation. It does not use SwiftData, SwiftUI, UIKit or UserNotifications.

### 5.2 Domain layer

All functions in this layer are pure. A pure function always gives the same result for the same input. No function in this layer calls `Date()` or `Calendar.current`. Each function receives `now` and a `Calendar` as parameters.

| Component | Function |
|---|---|
| `ReminderLogic` | Calculates days, states, end dates and status text. |
| `ReminderItem` | A value type. It contains a copy of the data from one report or one medication. |
| `NotificationPlanner` | Receives a list of `ReminderItem` values, `now`, the settings and a `Calendar`. Gives a list of `PlannedNotification` values. |
| `PlannedNotification` | A value type: identifier, fire date, title, body, category and item reference. |
| `PersonNameSuggester` | Makes the person names uniform. Gives a list of name suggestions. |

### 5.3 Infrastructure layer

| Component | Function |
|---|---|
| `NotificationCenterProtocol` | A protocol for the necessary functions of `UNUserNotificationCenter`. The tests use a fake implementation. |
| `NotificationScheduler` | Removes all pending notifications. Then adds the planned notifications. In fast mode, it changes the fire dates (see 7.8). |
| `ReminderSync` | The single entry point for notifications (see 5.4). |
| `NotificationActionHandler` | Receives the notification button actions and changes the model (see section 8). |
| `NavigationRouter` | A small `@Observable` object. It keeps the screen to open after the user taps a notification. |
| `AppSettings` | Keeps the settings in `UserDefaults` (see 6.4). |

### 5.4 `ReminderSync`

`ReminderSync` does these steps:

1. Read all reports and medications that are not archived.
2. Change each one into a `ReminderItem`.
3. Send the list to `NotificationPlanner`.
4. Send the result to `NotificationScheduler`.

The app starts `ReminderSync` at these times:

- When the app starts.
- When the app comes to the foreground.
- After each save of data.
- After each notification action.
- After `UIApplication.significantTimeChangeNotification`. This notification occurs at midnight and when the time zone, the date or the clock changes.

**Rule:** No component adds or removes a notification directly. All changes go through `ReminderSync`.

### 5.5 Views

- Home
- Report detail, report form, renewal screen
- Medication form
- Settings
- Onboarding

Two forms use small `@Observable` models: `ReportFormModel` and `MedicationFormModel`. The views contain no decision logic. The decisions come from the Domain layer.

---

## 6. Data model

### 6.1 Rules for all models

- All fields have a default value.
- All relationships are optional.
- The models do not use `@Attribute(.unique)`.
- The app uses `VersionedSchema`. The first schema is `SchemaV1`.

The first three rules make the models compatible with CloudKit.

### 6.2 `Report`

| Field | Type | Default | Note |
|---|---|---|---|
| `id` | UUID | `UUID()` | The notification identifier uses it. |
| `title` | String | `""` | |
| `personName` | String | `""` | The app trims spaces before it saves. |
| `endDate` | Date | `Date()` | The user enters it directly. |
| `leadDays` | Int | 18 | The form uses the value from `AppSettings`. |
| `isHandled` | Bool | false | True after "Yeniledim". |
| `handledAt` | Date? | nil | |
| `snoozeUntil` | Date? | nil | Set by "3 saat sonra". |
| `isArchived` | Bool | false | |
| `notes` | String | `""` | |
| `createdAt` | Date | `Date()` | |
| `medications` | [Medication]? | `[]` | Delete rule: cascade. |

### 6.3 `Medication`

| Field | Type | Default | Note |
|---|---|---|---|
| `id` | UUID | `UUID()` | |
| `name` | String | `""` | |
| `dosageNote` | String | `""` | Information only. |
| `personName` | String | `""` | Used only when the medication has no report. |
| `lastPickupDate` | Date | `Date()` | The app keeps the start of the day. |
| `supplyDays` | Int | 30 | |
| `leadDays` | Int | 7 | The form uses the value from `AppSettings`. |
| `snoozeUntil` | Date? | nil | |
| `isArchived` | Bool | false | |
| `createdAt` | Date | `Date()` | |
| `report` | Report? | nil | |

`Medication` has no `isHandled` field. "Aldım" sets `lastPickupDate` to today. Thus, a new cycle starts immediately.

### 6.4 `AppSettings`

| Key | Type | Default |
|---|---|---|
| `notificationHour` | Int | 10 |
| `notificationMinute` | Int | 0 |
| `defaultReportLeadDays` | Int | 18 |
| `defaultMedicationLeadDays` | Int | 7 |
| `hasCompletedOnboarding` | Bool | false |
| `isFastModeOn` | Bool | false (debug builds only) |

### 6.5 Calculated values

These values are not saved:

- **Supply end date** = `lastPickupDate` + `supplyDays`.
- **Effective person name** of a medication = the `personName` of its report, or its own `personName` if it has no report.
- **Effective archive state** of a medication = true if `isArchived` is true, or if its report is archived. When the user restores a report, the linked medications come back. The app does not change the medication records.
- **Days remaining** = calendar days from the start of today to the start of the end date. 0 means "today". A negative value means "past".

### 6.6 `ReminderState`

| State | Condition | Color | Text |
|---|---|---|---|
| `handled` | `isHandled` is true | Gray | "Yeni tarih bekleniyor" |
| `overdue` | days remaining < 0 | Red | "N gün geçti" |
| `reminding` | 0 ≤ days remaining ≤ `leadDays` | Orange | "Bugün bitiyor", "Yarın bitiyor", "N gün kaldı" |
| `normal` | days remaining > `leadDays` | Green | "N gün kaldı" |

The app checks the conditions in this order. A negative `leadDays` operates as 0.

**Sort priority:** overdue, then reminding, then handled, then normal. Inside one state, the item with fewer days remaining comes first.

---

## 7. Notification planning

### 7.1 Input and output

- **Input:** the active `ReminderItem` values, `now`, the notification time and a `Calendar`.
- **Output:** a list of `PlannedNotification` values, sorted by fire date.

### 7.2 Rules for each item

1. **Normal or reminding item.** One notification each day at the notification time. The first day is the reminder start date (end date − `leadDays`). If the reminder start date is in the past, the first day is today. If the notification time for today is past, the first day is tomorrow.
2. **Overdue item.** The daily notifications continue without an end.
3. **Handled report.** No daily notifications. One notification every 3 days. The first one is 3 days after `handledAt`. The text is "Yeni bitiş tarihini gir".
4. **Snooze.** If `snoozeUntil` is after `now`, add one notification at `snoozeUntil`. The text is the same as the daily text for that day.

### 7.3 Text

The planner calculates the text for the **fire date**, not for `now`.

| Situation | Title | Body |
|---|---|---|
| Report, days remaining > 1 | "{title} {N} gün sonra bitiyor" | "{person} için. Randevu almayı unutma." |
| Report, 1 day | "{title} yarın bitiyor" | same |
| Report, 0 days | "{title} bugün bitiyor" | same |
| Report, overdue | "{title} süresi doldu" | "{N} gün önce bitti." |
| Report, handled | "{title}: yeni bitiş tarihini gir" | "Rapor sisteme işlendiyse tarihi kaydet." |
| Medication, days remaining > 1 | "{name} ilacın {N} gün sonra bitiyor" | "Eczaneden yenisini almayı unutma." |
| Medication, 1 day | "{name} ilacın yarın bitiyor" | same |
| Medication, 0 days | "{name} ilacın bugün bitiyor" | same |
| Medication, overdue | "{name} ilacın bitti" | "{N} gün önce bitti." |
| Backup | "Hatırlatmalar devam etsin" | "Hatırlatmaların devam etmesi için uygulamayı bir kez aç." |

If the person name is empty, the body does not show "{person} için."

### 7.4 The 64-notification limit

iOS keeps a maximum of 64 pending notifications for each app.

1. Make the candidate notifications for each item. Stop at 63 for each item.
2. Sort all candidates by fire date. If two candidates have the same fire date, sort them by the sort priority (6.6).
3. Keep the first 63 candidates.
4. Add one backup notification on the day after the last kept notification, at the notification time.

The total is never more than 64. If there are no candidates, there is no backup notification.

### 7.5 Identifiers

| Type | Identifier |
|---|---|
| Daily report notification | `report-<uuid>-<yyyyMMdd>` |
| Daily medication notification | `med-<uuid>-<yyyyMMdd>` |
| Handled report notification | `renewal-<uuid>-<yyyyMMdd>` |
| Snooze | `snooze-<uuid>` |
| Backup | `backup` |

`userInfo` contains the item type (`report` or `medication`) and the item `id`.

### 7.6 Categories

| Category | Used for |
|---|---|
| `REPORT_REMINDER` | Daily and snooze report notifications |
| `MED_REMINDER` | Daily and snooze medication notifications |
| `RENEWAL_DATE` | Handled report notifications |
| `BACKUP` | Backup notification |

### 7.7 Trigger

`NotificationScheduler` uses `UNCalendarNotificationTrigger` with year, month, day, hour and minute, and `repeats: false`. Thus, each notification fires at the local clock time.

### 7.8 Fast mode (debug builds only)

In fast mode, one day is equal to one minute. `NotificationScheduler` changes each fire date: fire date = `now` + (calendar days from today to the fire date) minutes. The planner does not change.

---

## 8. Notification actions

### 8.1 Setup

- The app makes one `ModelContainer` at launch. The SwiftUI scene and `AppDelegate` use the same container.
- `AppDelegate` sets the `UNUserNotificationCenter` delegate in `application(_:didFinishLaunchingWithOptions:)`. This step must occur before the launch is complete. If it does not occur, iOS does not send the action to a closed app.
- `AppDelegate` registers the categories from 7.6.

### 8.2 Buttons

| Category | Buttons | Tap on the notification |
|---|---|---|
| `REPORT_REMINDER` | "Yeniledim" · "3 saat sonra" | Opens the report detail. |
| `MED_REMINDER` | "Aldım" · "3 saat sonra" | Opens the report detail. If the medication has no report, opens the medication form. |
| `RENEWAL_DATE` | none | Opens the renewal screen. |
| `BACKUP` | none | Opens the app. |

The buttons do not use `.foreground`. Thus, the app does the action in the background. The buttons do not use `.authenticationRequired`. Thus, the user can do the action from the lock screen.

### 8.3 Steps for each action

`NotificationActionHandler` does these steps on the main actor:

1. Find the item with the `id` from `userInfo`. If the item does not exist, go to step 4.
2. Change the item:
   - **Yeniledim:** set `isHandled` to true and `handledAt` to `now`.
   - **Aldım:** set `lastPickupDate` to the start of today.
   - **3 saat sonra:** set `snoozeUntil` to `now` + 3 hours.
   - Each action except "3 saat sonra" also sets `snoozeUntil` to nil.
3. Save the context.
4. Start `ReminderSync`.
5. Call the completion handler.

### 8.4 Notification when the app is open

The delegate shows the notification as a banner with a sound and adds it to the list.

### 8.5 Renewal of a report

1. The user opens the renewal screen.
2. The screen shows a date picker. The default value is the old end date + 1 year. (29 February becomes 28 February.)
3. The user saves.
4. The app sets `endDate` to the new date, `isHandled` to false, `handledAt` to nil and `snoozeUntil` to nil.
5. The app starts `ReminderSync`.

---

## 9. Screens

### 9.1 Visual direction

- The page background is light gray. The cards are white with large rounded corners. In dark mode, the colors change to the system dark colors.
- Color shows only the state: green, orange, red and gray. All other elements are black, white or gray.
- The primary buttons are black with a pill shape. There is a maximum of one primary button on each screen.
- Numbers are large. Numbers and headings use SF Pro Rounded.
- Rings are only on the hero card and on the upcoming strip.

### 9.2 Onboarding

1. A short introduction (1 or 2 screens, large text).
2. A request for notification permission with the reason: "Rapor bitmeden haber verebilmemiz için".
3. Selection of the notification time.
4. The empty home screen with the button "İlk raporunu ekle".

### 9.3 Home

From top to bottom:

1. **Title bar:** "Hatırlatmalar" and a settings button.
2. **Permission banner:** only when the notification permission is off. Red. Button: "Ayarları aç".
3. **Upcoming strip:** a horizontal list of rings. It shows the items that are not archived, sorted by the sort priority (6.6). The maximum is 8 items. If there are no items, the strip is not shown. Each ring shows the days remaining. Under each ring: the name and a short state text. A tap opens the item.
4. **Hero card:** the first item in the sort order. It shows the person, the title, the days as a large number, a ring and one black action button ("Yeniledim", "Aldım" or "Tarihi gir"). If no item needs attention, the card shows the item with the nearest end date and no button.
5. **"Raporlar":** all reports that are not archived, as cards, sorted by end date.
6. **"Raporsuz ilaçlar":** all medications without a report that are not archived, as cards, sorted by supply end date.
7. **"Arşiv (N)":** closed by default. It shows the archived items.
8. **Floating "+" button:** at the bottom right. Black. It opens a menu: "Rapor ekle" or "İlaç ekle".

**Important rule:** The strip and the hero card are shortcuts. The lists contain all items. Important information is never only in the strip. Reason: older users often do not see horizontal scrolling.

The ring on the hero card shows how much of the reminder period is past. When the item is overdue, the ring is full and red.

### 9.4 Report detail

- Title and person.
- A large state card with the action button. For a handled report, the card shows "Yeni bitiş tarihini gir" and the button "Tarihi gir".
- Information: end date and notes.
- The linked medications, each with its state.
- Buttons: "İlaç ekle", "Düzenle", "Takibi durdur" (or "Takibi yeniden başlat").
- At the bottom: "Raporu sil" in red. It asks for confirmation. The confirmation text tells that the linked medications are also deleted.

### 9.5 Report form

Fields: "Rapor adı", "Kimin için" (with suggestions), "Bitiş tarihi" (date picker), "Kaç gün önce hatırlatılsın" (stepper), "Notlar".

If the end date is in the past, the form shows: "Bu rapor bitmiş görünüyor, yine de kaydedilsin mi?"

### 9.6 Medication form

Fields: "İlaç adı", "Doz notu", "Bağlı rapor" (picker, with the option "Yok"), "Kimin için" (only when "Bağlı rapor" is "Yok"), "Son alım tarihi" (default: today), "Kaç günlük" (quick buttons 30, 60, 90 and a stepper), "Kaç gün önce hatırlatılsın".

A live preview shows: "Tahmini bitiş: {date}".

For an existing medication, the form also has "Takibi durdur" and "İlacı sil".

### 9.7 Settings

- "Bildirim saati"
- "Rapor için varsayılan gün" and "İlaç için varsayılan gün"
- Notification permission state
- "Bu uygulama tıbbi tavsiye vermez, yalnızca hatırlatır."
- Link to the privacy policy (a GitHub Pages page)
- "Verilerin sadece bu telefonda."
- Debug builds only: "Hızlı mod"

---

## 10. Name suggestions

- The app trims spaces at the start and at the end of a name before it saves.
- The suggestions are the unique person names from all reports and medications.
- Two names are the same if they are equal when the app ignores letter case. The suggestion shows the most recent spelling.
- The field shows the suggestions that start with the text that the user types. The comparison ignores letter case and uses the Turkish locale ("i" and "İ").

---

## 11. Accessibility

- All text uses Dynamic Type. The test includes the largest size.
- Each touch area is a minimum of 44 × 44 pt.
- Each state has a text label, not only a color.
- Each card has one VoiceOver label. Example: "Tansiyon raporu, Babam, 12 gün kaldı, dikkat gerekiyor".
- The text uses no abbreviations and no technical words.
- Each delete operation asks for confirmation.

---

## 12. Input validation

| Field | Rule |
|---|---|
| Report title, medication name | Must not be empty after the app trims spaces. |
| `leadDays` | 0 to 90. |
| `supplyDays` | 1 to 365. |
| `endDate` in the past | The form shows a warning. The user can save. |

---

## 13. Error handling

| Condition | Response |
|---|---|
| The user does not give notification permission | The app operates. Home shows the permission banner. |
| The user removes the permission later | The app checks the permission each time it comes to the foreground. |
| The save operation fails | The app shows an alert. The form keeps the data. |
| The notification scheduling fails | The app writes the error to the log. The next `ReminderSync` tries again. |
| A notification action refers to a deleted item | The handler does no change and starts `ReminderSync`. |
| The time zone, the date or the clock changes | The app starts `ReminderSync`. |

---

## 14. Test strategy

### 14.1 General rules

- The project uses Swift Testing.
- The project uses TDD: a failed test first, then the minimum code, then improvement.
- The tests use a fixed date and a fixed time zone.

### 14.2 Unit tests

| Component | Test cases |
|---|---|
| `ReminderLogic` | Day count across midnight. Daylight saving time. 29 February. Year boundary. State boundaries. Negative `leadDays`. Status text. |
| `NotificationPlanner` | Never more than 64. Ten items in the reminder window. Same-date sort by priority. Text for the fire date. Backup on the day after the last kept notification. No backup when there are no candidates. Handled report every 3 days. Snooze in the future and in the past. Notification time already past today. Reminder start date in the past. Empty person name. |
| `PersonNameSuggester` | Trims spaces. Ignores letter case. Turkish "i" and "İ". Removes duplicates. |
| `ReminderItem` mapping | Medication of an archived report. Person name from the report. Archived items are not included. |

### 14.3 Integration tests

With an in-memory `ModelContainer` and a fake notification center:

- `NotificationActionHandler`: each action changes the correct fields and starts a sync. A deleted item causes no failure.
- `ReminderSync`: it removes all old notifications and adds the planned notifications.
- Delete of a report deletes its medications.

### 14.4 UI test

One XCUITest: add a report, see it on the home screen, delete it.

### 14.5 Manual tests on a real iPhone

Use fast mode. Do all items in this list:

- An end date of today.
- A report saved with an end date in the past.
- `leadDays` larger than the days remaining.
- Delete of a report with medications.
- Notification permission off.
- The app not opened for more than 63 notifications (the backup notification comes).
- "Aldım" from the lock screen when the app is closed.
- Ten items in the reminder window on the same day.
- A change of the notification time.
- The app open across midnight.
- A different device language and region (the date format follows the device).
- The largest Dynamic Type size on each screen.
- VoiceOver on the home screen and on the hero card.

### 14.6 Field test (TestFlight, 2 to 4 weeks)

The first user uses the app. Find the answers to these questions:

1. Does he understand the ring on the hero card? If not, remove the ring and keep the number.
2. Is 10:00 a good time?
3. Is 7 days enough for a medication?

### 14.7 Continuous integration

A GitHub Actions workflow runs all tests on each push, on a macOS runner.

---

## 15. Milestones

| # | Work | Complete when |
|---|---|---|
| 1 | Project setup, `SchemaV1`, models, `ReminderLogic`, `ReminderItem`, `PersonNameSuggester`, CI | All unit tests pass in CI. |
| 2 | `NotificationPlanner` | All planner tests pass. |
| 3 | Home, report form, report detail, archive | The user can add, edit, archive and delete a report. |
| 4 | Medication form, link to a report, medications without a report | The user can add and list medications. The preview is correct. |
| 5 | `NotificationScheduler`, `ReminderSync`, actions, renewal flow | Notifications come at the correct time on a real iPhone. The actions operate when the app is closed. |
| 6 | Onboarding, settings, permission handling, privacy manifest | The flow is clean also when the user refuses the permission. |
| 7 | Accessibility pass and manual tests (14.5) | All items in 14.5 are complete. |
| 8 | TestFlight field test | The answers to 14.6 are known. |

The planner comes before the UI because it contains the highest risk.

---

## 16. Changes to the current draft code

The draft code of 27 October 2026 needs these changes:

1. Remove `Medication.isHandled` and the related code.
2. Add `isArchived` and `snoozeUntil` to `Report` and `Medication`.
3. Put the models in `SchemaV1`.
4. Remove the default `Date()` and `Calendar.current` parameters from the functions that the Domain layer calls. The models can keep them for the views.

---

## 17. Items with a default value (no block for v1)

| Item | Default value | When to decide |
|---|---|---|
| App name | `IlacRapor` (working name) | Before the App Store release. |
| Medication `leadDays` | 7 | After the field test. |
| Ring on the hero card | Included | After the field test. |
