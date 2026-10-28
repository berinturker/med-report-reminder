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
