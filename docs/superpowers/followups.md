# Follow-ups from final reviews

Items that the final reviews found and that were deferred. Each later plan checks this list.

## From Plan 1 and Plan 1b (Domain kit)

- A very old `handledAt` makes the renewal loop step through every 3-day interval since then; start near today.
- The planner builds text for all candidates before it keeps 63; sort tuples first, make text last.
- Name suggestions with the same `usedAt` have no stable order; add a name tie-break.
- `ReminderItem` title tie-break is not Turkish-aware ("Ç" sorts after "Z").
- Spec 7.2 rule 3 names the Turkish text instead of pointing to 7.3.

## From Plan 2 (app shell and notifications)

- **Plan 3 must do:** a tap on a notification for a deleted item routes to that id; screens fall back to Home when the id does not exist.
- The scheduler uses `Calendar.autoupdatingCurrent` and the sync uses `Calendar.current`; pass one calendar per sync.
- The hosted test app creates `AppEnvironment.shared` (on-disk store, real notification center); skip it under XCTest.
- Old delivered notifications keep "Renewed" and "In 3 hours"; consider removing delivered notifications of handled items.
- The significant-time-change observer is on a view; use `applicationSignificantTimeChange(_:)`.
- When permission is denied, each sync logs 64 errors; check `authorizationStatus` first.
- `ModelConfiguration()` defaults `cloudKitDatabase` to `.automatic`; set `.none` until iCloud sync is a decision.
