# Status — 9 Nov 2026

## Built

All screens in the spec exist and compile with zero analyzer issues:

- Splash, 3-page onboarding, sign in (with session-expired state), Terms and Privacy pages
- Tab shell with the gradient bottom bar (tablet: side rail)
- Home: 4 live counts, quick actions, a checklist driven by real counts, recent samples
- Samples: list (status segments, arrival filter), new and edit sample (2-of-3 weights, duplicate "save anyway"), detail with delete
- Batches: list, new batch (pick unbatched samples, 48 cap), auto-batch for a date, detail, edit (open/completed, notes), delete
- Offer lists: list (date/grade/type filters), new offer (override / re-offer on duplicates; up to 10 parties, each picked from buyers or typed), detail, edit (packing date read-only), delete
- Offered today: day switcher, offer/sample tabs, single and multi-select buyer allocation
- Bid book: tabbed card list, new/edit lot, detail with one-tap status change and delete
- Courier: list, new entry (buyer address prefill, barcode scanner, photo, posting lists), detail, edit, delete
- Contracts: list, new contract with repeatable items and live totals, detail, edit, delete
- Sales register: list, new sale with live amount, detail, edit, delete
- Ex-factory: status summary tiles, list, CSV export + share, new bill (IGST / CGST+SGST with 5% fill), detail, edit, delete
- Buyer and seller pickers can add a new buyer or seller by name (`POST /buyers`, `POST /sellers`)
- Write paths tested 5 Nov 2026 and re-tested 7 and 9 Nov 2026 (create, edit, delete for every module; details in `docs/API_DOCS.md` → Write tests)
- Every detail screen loads by ID (`GET /{module}/{id}`): it shows the list copy at once, refreshes from the API, and works from a deep link
- Grade pickers load `GET /grades`, falling back to a built-in list
- More and Settings (theme, version, legal), sign out
- App ID `com.gitcs.pioji` on iOS and Android; launcher icons (two-leaf mark, light/dark, Android adaptive + monochrome) and native splash

## Verified

On 31 Oct 2026, signed in as admin: every list, lookup and detail response was fetched and run through the app's parsers (`test/api_parsing_test.dart`, which needs `API_FIXTURES` pointing at saved responses). All 11 parser tests pass.

## Not verified

- The Android APK is built and signed on GitHub Actions, but has not been run on a device or emulator.
- On the simulator: sample create / edit / delete, batch edit + delete, and contract edit + delete. The other forms were tested against the API with the app's exact request bodies.
- The offer, sale and ex-factory edit screens (7 Nov 2026), 10 parties and party edits, and new buyer / seller (9 Nov 2026) were tested against the API with the app's exact request bodies, not yet in the simulator.
- Creating a seller wasn't tried on the server: there is no `DELETE /sellers/{id}` to remove a test record. Buyer create was tested and deleted.

## API status

Re-checked against the staging server on 9 Nov 2026, signed in as admin, with marked TEST records that were deleted afterwards. Of the 22 issues found on 5 Nov, 19 are fixed and 3 remain. Details: `docs/API_DOCS.md` → Write tests and Re-tests.

### Working

| Area | Endpoints | Used in the app |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/logout`, `GET /auth/me` | Sign in, sign out |
| Lookups | `GET /buyers`, `/sellers`, `/gardens` (search), `/grades`, `/negotiators`, `/posting-lists`, `/courier-entries/services` (services and addresses) | All pickers; buyers also feed offer parties |
| Buyers, sellers | `POST /buyers` (`buyer_name`), `DELETE /buyers/{id}`, `POST /sellers` (`seller_name`) | "Add as a new buyer / seller" in the pickers |
| Offer lists | list, detail, create (10 parties; duplicate → 409 with the existing offer; `duplicate_action` override / reoffer / reject), edit (parties: null clears, a missing key keeps), delete | ✅ (edit doesn't save the packing date) |
| Offered today | `GET /samples-offered-today`, single and bulk buyer allocation | ✅ |
| Samples | list (arrival date and search filters), detail, create (duplicate → 422, resend with `is_duplicate`), edit (all fields), delete (422 when buyers are allocated) | ✅ |
| Batches | list, detail, create (keeps `batch_date`), auto-batch for a date, edit (`status`, `remarks`), delete | ✅ |
| Bid book | list, detail (404 once deleted), create, edit (full and status-only), delete | ✅ |
| Courier | list, detail, create (JSON or with photo, posting lists linked), buyer address prefill, edit, delete | ✅ |
| Contracts | list, detail, create, edit (items replaced; missing price → 422), delete | ✅ |
| Sales register | list (`sales_entries`), detail, create, edit, delete | ✅ |
| Ex-factory | list with metrics, detail, create (reconciles on save; matching sale → `matched`), edit, delete, CSV export | ✅ |
| Errors | 401 on expired token, 404 for missing records and unknown paths, 405 as plain JSON, 409 duplicate offer, 422 with field errors | ✅ |

### Needs fixes from the API developer

1. `PUT /offer-lists/{id}` doesn't save `d_o_packing` (date of packing). The app shows it read-only on edit.
2. `PUT /sales-register/{id}` with more packages than the split allows returns 500; should be 422 with a `pkgs` error. The app turns this one into a field error.
3. `GET /dashboard/summary` returns 500 (`Class "App\Models\Batch" not found`). Not used by the app yet; Home counts come from the lists.
4. Optional: `DELETE /sellers/{id}` (buyers have it).

### Will work without an app update once fixed

2. The packing date on edit (1) and dashboard counts on Home (3) need an app update.

## Not built yet (from the spec)

- Offline read cache (drift). Lists currently need a connection; the offline banner and write blocking are in place.
- Form drafts (autosave) and "Discard changes?" on back.
- Flavors (dev/staging/prod entry points), Sentry. (Android release CI is done: see the README.)
- Tests (unit, widget, golden, integration).
- Localisation files (`.arb`); strings are inline for now.
