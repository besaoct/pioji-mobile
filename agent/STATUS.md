# Status — 7 Nov 2026

## Built

All screens in the spec exist and compile with zero analyzer issues:

- Splash, 3-page onboarding, sign in (with session-expired state), Terms and Privacy pages
- Tab shell with the gradient bottom bar (tablet: side rail)
- Home: 4 live counts, quick actions, a checklist driven by real counts, recent samples
- Samples: list (status segments, arrival filter), new and edit sample (2-of-3 weights, duplicate "save anyway"), detail with delete
- Batches: list, new batch (pick unbatched samples, 48 cap), auto-batch for a date, detail, edit (open/completed, notes), delete
- Offer lists: list (date/grade/type filters), new offer (override / re-offer on duplicates; up to 5 parties, each picked from buyers or typed), detail, edit (parties and packing date read-only), delete
- Offered today: day switcher, offer/sample tabs, single and multi-select buyer allocation
- Bid book: tabbed card list, new/edit lot, detail with one-tap status change and delete
- Courier: list, new entry (buyer address prefill, barcode scanner, photo, posting lists), detail, edit, delete
- Contracts: list, new contract with repeatable items and live totals, detail, edit, delete
- Sales register: list, new sale with live amount, detail, edit, delete
- Ex-factory: status summary tiles, list, CSV export + share, new bill (IGST / CGST+SGST with 5% fill), detail, edit, delete
- Write paths tested 5 Nov 2026 and re-tested 7 Nov 2026 (create, edit, delete for every module; details in `docs/API_DOCS.md` → Write tests)
- Every detail screen loads by ID (`GET /{module}/{id}`): it shows the list copy at once, refreshes from the API, and works from a deep link
- Grade pickers load `GET /grades`, falling back to a built-in list
- More and Settings (theme, version, legal), sign out
- App ID `com.gitcs.pioji` on iOS and Android; launcher icons (two-leaf mark, light/dark, Android adaptive + monochrome) and native splash

## Verified

On 31 Oct 2026, signed in as admin: every list, lookup and detail response was fetched and run through the app's parsers (`test/api_parsing_test.dart`, which needs `API_FIXTURES` pointing at saved responses). All 11 parser tests pass.

## Not verified

- The Android APK is built and signed on GitHub Actions, but has not been run on a device or emulator.
- On the simulator: sample create / edit / delete, batch edit + delete, and contract edit + delete. The other forms were tested against the API with the app's exact request bodies.
- The offer, sale and ex-factory edit screens (added 7 Nov 2026) were tested against the API with the app's exact request bodies, not yet in the simulator.

## API status

Re-checked against the staging server on 7 Nov 2026, signed in as admin, with marked TEST records that were deleted afterwards. 13 of the 22 issues from 5 Nov are fixed. Details and raw responses: `docs/API_DOCS.md` → Verified responses and Write tests.

### Working

| Area | Endpoints | Used in the app |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/logout`, `GET /auth/me` | Sign in, sign out |
| Lookups | `GET /buyers`, `/sellers`, `/gardens` (search), `/grades`, `/negotiators`, `/posting-lists`, `/courier-entries/services` (services and addresses) | All pickers; buyers also feed offer parties |
| Offer lists | list, detail, create (duplicate → 409 with the existing offer; `duplicate_action` override / reoffer / reject), edit, delete | ✅ (edit doesn't save parties or packing date) |
| Offered today | `GET /samples-offered-today`, single and bulk buyer allocation | ✅ |
| Samples | list (arrival date and search filters), detail, create (duplicate → 422, resend with `is_duplicate`), edit (all fields), delete (422 when buyers are allocated) | ✅ |
| Batches | list, detail, create (keeps `batch_date`), auto-batch for a date, edit (`status`, `remarks`), delete | ✅ |
| Bid book | list, detail, create, edit (full and status-only), delete | ✅ |
| Courier | list, detail, create (JSON or with photo, posting lists linked), buyer address prefill, edit, delete | ✅ |
| Contracts | list, detail, create, edit (items replaced; missing price → 422), delete | ✅ |
| Sales register | detail, create, edit, delete | ✅ (list can't load, see below) |
| Ex-factory | list with metrics, detail, create (reconciles on save), edit, delete, CSV export | ✅ |
| Errors | 401 on expired token, 404 for missing records and unknown paths, 409 duplicate offer, 422 with field errors | ✅ |

### Fixed since 5 Nov

Sale detail and edit, sample detail (and 404 for a missing id), sample edit, sample delete with buyers (422), contract item without a price (422), ex-factory `credit_days` edit, samples arrival date and search filters, batch date with `sample_ids`, courier posting lists, duplicate offer (409), sellers list format, plain `YYYY-MM-DD` dates. Offer edit now saves everything except parties and the packing date.

### Needs fixes from the API developer

1. `GET /sales-register` returns 500 ("Recursion detected"). The Sales register list can't load. **Top priority.**
2. `PUT /offer-lists/{id}` doesn't save `party_1`–`party_5` or `d_o_packing`. The app shows them read-only on edit.
3. `POST /offer-lists` saves only `party_1`–`party_5`; `party_6`–`party_10` are dropped. The app allows 5 (`_maxParties` in `offer_lists_screens.dart`).
4. `POST /ex-factory` with `"igst_amount": null` returns 500 (DB constraint); should default to 0. The app sends 0 for the unused GST type.
5. `PUT /sales-register/{id}` with more packages than the split allows returns 500; should be 422 with a `pkgs` error. The app turns this one into a field error.
6. `APP_DEBUG` is still on: 500s show SQL, 405s show the exception class and file path.
7. `GET /bid-book/{id}` of a deleted lot returns 200 with the deleted record (`deleted_at` set); should be 404.
8. Ex-factory: a bill matching a sale on mark and invoice with equal packages and kg is still flagged `qty_mismatch`.
9. Missing: create buyer and create seller (the web app has a quick-register). Then forms could accept new names, not only picks.
10. Optional: `GET /dashboard/summary` for Home counts.

### Will work without an app update once fixed

1, 4–8 and 10. The sales register list should load once 1 is fixed, but its response shape has never been seen, so it may need a small fix. Parties on edit and parties 6–10 (2, 3) and new buyers/sellers (9) need an app update.

## Not built yet (from the spec)

- Offline read cache (drift). Lists currently need a connection; the offline banner and write blocking are in place.
- Form drafts (autosave) and "Discard changes?" on back.
- Flavors (dev/staging/prod entry points), Sentry. (Android release CI is done: see the README.)
- Tests (unit, widget, golden, integration).
- Localisation files (`.arb`); strings are inline for now.
