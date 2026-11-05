# Status — 31 Oct 2026

## Built

All screens in the spec exist and compile with zero analyzer issues:

- Splash, 3-page onboarding, sign in (with session-expired state), Terms and Privacy pages
- Tab shell with the gradient bottom bar (tablet: side rail)
- Home: 4 live counts, quick actions, a checklist driven by real counts, recent samples
- Samples: list (status segments, arrival filter), new and edit sample (2-of-3 weights, duplicate "save anyway"), detail with delete
- Batches: list, new batch (pick unbatched samples, 48 cap), auto-batch for a date, detail, edit (open/completed, notes), delete
- Offer lists: list (date/grade/type filters), new offer (override / re-offer on duplicates), detail with delete
- Offered today: day switcher, offer/sample tabs, single and multi-select buyer allocation
- Bid book: tabbed card list, new/edit lot, detail with one-tap status change and delete
- Courier: list, new entry (buyer address prefill, barcode scanner, photo, posting lists), detail, edit, delete
- Contracts: list, new contract with repeatable items and live totals, detail, edit, delete
- Sales register: list, new sale with live amount, detail with delete
- Ex-factory: status summary tiles, list, CSV export + share, new bill (IGST / CGST+SGST with 5% fill), detail with delete
- Write paths tested 5 Nov 2026 (create, edit, delete for every module; details in `docs/API_DOCS.md` → Write tests)
- Every detail screen loads by ID (`GET /{module}/{id}`): it shows the list copy at once, refreshes from the API, and works from a deep link
- Grade pickers load `GET /grades`, falling back to a built-in list
- More and Settings (theme, version, legal), sign out
- App ID `com.gitcs.pioji` on iOS and Android; launcher icons (two-leaf mark, light/dark, Android adaptive + monochrome) and native splash

## Verified

On 31 Oct 2026, signed in as admin: every list, lookup and detail response was fetched and run through the app's parsers (`test/api_parsing_test.dart`, which needs `API_FIXTURES` pointing at saved responses). All 11 parser tests pass.

## Not verified

- Android has not been run.
- On the simulator: sample create / edit / delete, batch edit + delete, and contract edit + delete. The other forms were tested against the API with the app's exact request bodies.
- Edit screens exist only where the server saves edits (samples, batches, bid book, courier, contracts). Offer lists, sales and ex-factory get delete only until their edits save.

## Blocked on the backend

Details in `docs/API_DOCS.md` → Verified responses → Server bugs.

1. `GET /sales-register` returns 500 (it tries to insert a record during a GET). The sales register list can't load.
2. `GET /sales-register/{id}` and `GET /samples/{id}` return 500. Those detail screens show the list copy instead.
3. `PUT /contracts/{id}` with an item that has no price returns 500 ("Price per kg is required…") instead of 422. The app now checks this before saving.
4. `APP_DEBUG=false`, JSON 404 for unknown API paths.
5. Edits that report success but don't save: samples (all fields except remarks and arrival date), offer lists (price, prompt days), ex-factory (credit days). Sales register edit returns 500.
6. A duplicate offer invoice returns HTTP 200 with `success: false`; the app now treats that as a failure.
7. `GET /samples` ignores `arrival_date`, so Home shows the total sample count, not today's, and the Samples arrival filter has no effect.

## Not built yet (from the spec)

- Offline read cache (drift). Lists currently need a connection; the offline banner and write blocking are in place.
- Form drafts (autosave) and "Discard changes?" on back.
- Flavors (dev/staging/prod entry points), Sentry, CI.
- Tests (unit, widget, golden, integration).
- Localisation files (`.arb`); strings are inline for now.
