# Follow-ups from final reviews

Items that the final reviews found and that were deferred. Each later plan checks this list.

## From Plan 1 and Plan 1b (Domain kit)

- A very old `handledAt` makes the renewal loop step through every 3-day interval since then; start near today.
- The planner builds text for all candidates before it keeps 63; sort tuples first, make text last.
- Name suggestions with the same `usedAt` have no stable order; add a name tie-break.
- `ReminderItem` title tie-break is not Turkish-aware ("Ç" sorts after "Z").
- Spec 7.2 rule 3 names the Turkish text instead of pointing to 7.3.

## From Plan 2 (app shell and notifications)

- The scheduler uses `Calendar.autoupdatingCurrent` and the sync uses `Calendar.current`; pass one calendar per sync.
- Old delivered notifications keep "Renewed" and "In 3 hours"; consider removing delivered notifications of handled items.
- When permission is denied, each sync logs 64 errors; check `authorizationStatus` first.

## From Plan 3 (screens)

- Notification tap routing (live item → detail, deleted item → Home) is covered only by unit tests; check it on a real iPhone.
- Overdue items show a negative day number ("-3") on the hero, detail and strip; consider showing the absolute number and letting the badge say "overdue".
- The report detail reads `now` once per render, so an open detail does not update its days at midnight.
- An archived report's detail still shows the "Renewed" button and the day count; consider "Tracking stopped" instead.
- Views still decide two sort orders (medication picker by title, linked medications by name) and they are not Turkish-aware.
- `notes` and `dosageNote` are saved untrimmed.
- "Stop tracking" in the medication form dismisses and drops unsaved draft edits.
- A pending notification destination closes any open sheet (a BACKUP tap drops an Add draft); a `.renewal` while the detail has its own sheet open cannot present a second sheet.
- Home with only archived items shows no empty-state button.
- The quick supply buttons (30/60/90) show no selected state.
- The forms show an 18/7 lead-day placeholder for one frame before the settings default applies.
- Test gaps: all-normal hero; fewer than 8 strip items; `ItemStore.markPickedUp` and medication archive/delete; list tie-breaks; `isValid` boundaries; `MedicationFormModel.suggestions`; `check-strings.py` does not walk `substitutions` and has no tests.
- `-uiTesting` still uses the real notification center; the UI test ends with a fixed 2-second wait.
- Not yet checked with content: English, the largest text size, dark mode (Plan 4 accessibility pass).
