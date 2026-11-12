# Status — 12 Nov 2026

## Built

All screens in the spec exist and compile with zero analyzer issues:

- Splash, 3-page onboarding, sign in (with session-expired state), Terms and Privacy pages
- Tab shell with the gradient bottom bar (tablet: side rail)
- Own look on both platforms (12 Nov 2026): no Cupertino, custom SVG icons, Inter, compact 56 px top bar, custom dialog / sheet / calendar / switch / spinner / pull-to-refresh
- Home: samples today (with the total), unbatched, open bids, ex-factory mismatches, an all-time sales card (value, kg, pending approval), quick actions, a checklist driven by real counts (now including sales waiting for approval), recent samples. Most counts come from one `GET /dashboard/summary` call
- Samples: list (status segments, arrival and mark filters, grouped by arrival date → mark → invoice, latest / earliest first), new and edit sample (2-of-3 weights, duplicate "save anyway"), detail with delete
- Batches: list, new batch (pick unbatched samples, 48 cap), auto-batch for a date, detail, edit (open/completed, notes), delete
- Offer lists: list (date/grade/type/mark filters, grouped by date → mark → invoice), new offer (override / re-offer on duplicates; up to 10 parties, each picked from buyers or typed), detail, edit, delete
- Offered today: day switcher, offer/sample tabs, single and multi-select buyer allocation
- Bid book: tabbed list grouped by mark, one line per lot (grade · invoice, ask, max bid, status), new/edit lot, detail with one-tap status change and delete
- Courier: list, new entry (buyer address prefill, barcode scanner, photo, posting lists), detail, edit, delete
- Contracts: list (cover row: date range and buyer; number on the detail), new contract with repeatable items and live totals, detail, edit, delete
- Sales register: list (pending / approved / rejected), new sale with live amount, detail, edit, delete. A sale split between buyers shows its total packages, kg and value
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
- Buyer and seller create were tested on the server and the TEST records deleted.
- The dashboard-driven Home and split sale totals (9 Nov 2026) were checked by parsing live responses with the app's models, not yet in the simulator.
- 12 Nov 2026 rebuild: every tab, list, detail, form, dialog, calendar, switch and picker checked in the iOS simulator (light and dark). Android only through the CI build.

## API status

Re-checked against the staging server on 9 Nov 2026, signed in as admin, with marked TEST records that were deleted afterwards. All 22 issues found on 5 Nov are fixed. Details: `docs/API_DOCS.md` → Write tests and Re-tests.

### Working

| Area | Endpoints | Used in the app |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/logout`, `GET /auth/me` | Sign in, sign out |
| Lookups | `GET /buyers`, `/sellers`, `/gardens` (search), `/grades`, `/negotiators`, `/posting-lists`, `/courier-entries/services` (services and addresses) | All pickers; buyers also feed offer parties |
| Buyers, sellers | `POST /buyers` (`buyer_name`), `DELETE /buyers/{id}`, `POST /sellers` (`seller_name`), `DELETE /sellers/{id}` | "Add as a new buyer / seller" in the pickers |
| Offer lists | list, detail, create (10 parties; duplicate → 409 with the existing offer; `duplicate_action` override / reoffer / reject), edit (packing date; parties: null clears, a missing key keeps), delete | ✅ |
| Offered today | `GET /samples-offered-today`, single and bulk buyer allocation | ✅ |
| Samples | list (arrival date and search filters), detail, create (duplicate → 422, resend with `is_duplicate`), edit (all fields), delete (422 when buyers are allocated) | ✅ |
| Batches | list, detail, create (keeps `batch_date`), auto-batch for a date, edit (`status`, `remarks`), delete | ✅ |
| Bid book | list, detail (404 once deleted), create, edit (full and status-only), delete | ✅ |
| Courier | list, detail, create (JSON or with photo, posting lists linked), buyer address prefill, edit, delete | ✅ |
| Contracts | list, detail, create, edit (items replaced; missing price → 422), delete | ✅ |
| Sales register | list (`sales_entries`), detail, create, edit (too many packages → 422 on `pkgs`), delete | ✅ |
| Ex-factory | list with metrics, detail, create (reconciles on save; matching sale → `matched`), edit, delete, CSV export | ✅ |
| Dashboard | `GET /dashboard/summary` (counts per module) | Home tiles, sales card and the sales / ex-factory checklist items |
| Errors | 401 on expired token, 404 for missing records and unknown paths, 405 as plain JSON, 409 duplicate offer, 422 with field errors | ✅ |

### Needs fixes from the API developer

The 5 Nov issues are all fixed (9 Nov 2026). New requests from the client's feedback, checked on staging 12 Nov 2026 (full spec in the shared doc "Pioji – Backend requests from client feedback"):

| # | Priority | Request |
|---|---|---|
| 1 | 1 | `sort_by` + `sort_dir` on every list (all sort params are ignored today) |
| 2 | 1 | `garden_id` filter on samples, offers, bids, sales (`mark=` is ignored; only `search` matches) |
| 3 | 1 | `GET /posting-lists?buyer_id=` (lists have no buyer link) |
| 4 | 1 | `GET /gardens/{id}/grades` and fill `type_configs` (1 of the first 200 gardens has it) |
| 5 | 1 | Permission to lock the arrival date to today, enforced on save, listed in `/auth/me` |
| 6 | 2 | User and role endpoints (`/users`, `/roles` are 404) |
| 7 | 2 | Sample fields: billing company ("for whom"), original / standard, outgoing party |
| 8 | 2 | `POST` / `PATCH /bid-book/bulk` (today `GET /bid-book/bulk` → 500) |
| 9 | 3 | Tasting save, park / unpark, tasting report |
| 10 | 3 | Permissions for who creates offers and allocates buyers |

Also: admin's role shows as `supervisor`; `GET /sales-register/{id}` lacks the list's split fields; the dashboard's sales total counts split records.

## Not built yet (from the spec)

- Offline read cache (drift). Lists currently need a connection; the offline banner and write blocking are in place.
- Form drafts (autosave) and "Discard changes?" on back.
- Flavors (dev/staging/prod entry points), Sentry. (Android release CI is done: see the README.)
- Tests (unit, widget, golden, integration).
- Localisation files (`.arb`); strings are inline for now.
