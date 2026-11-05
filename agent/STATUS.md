# Status — 5 Nov 2026

## Built

All screens in the spec exist and compile with zero analyzer issues:

- Splash, 3-page onboarding, sign in (with session-expired state), Terms and Privacy pages
- Tab shell with the gradient bottom bar (tablet: side rail)
- Home: 4 live counts, quick actions, a checklist driven by real counts, recent samples
- Samples: list (status segments, arrival filter), new and edit sample (2-of-3 weights, duplicate "save anyway"), detail with delete
- Batches: list, new batch (pick unbatched samples, 48 cap), auto-batch for a date, detail, edit (open/completed, notes), delete
- Offer lists: list (date/grade/type filters), new offer (override / re-offer on duplicates; up to 5 parties, each picked from buyers or typed), detail with delete
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

- The Android APK is built and signed on GitHub Actions, but has not been run on a device or emulator.
- On the simulator: sample create / edit / delete, batch edit + delete, and contract edit + delete. The other forms were tested against the API with the app's exact request bodies.
- Edit screens exist only where the server saves edits (samples, batches, bid book, courier, contracts). Offer lists, sales and ex-factory get delete only until their edits save.

## API status

Checked against the staging server on 5 Nov 2026, signed in as admin, with marked TEST records that were deleted afterwards. Details and raw responses: `docs/API_DOCS.md` → Verified responses and Write tests.

### Working

| Area | Endpoints | Used in the app |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/logout`, `GET /auth/me` | Sign in, sign out |
| Lookups | `GET /buyers`, `/sellers`, `/gardens` (search), `/grades`, `/negotiators`, `/posting-lists`, `/courier-entries/services` (services and addresses) | All pickers; buyers also feed offer parties |
| Offer lists | list, detail, create (with `duplicate_action` override / reoffer / reject), delete | ✅ |
| Offered today | `GET /samples-offered-today`, single and bulk buyer allocation | ✅ |
| Samples | list, create (duplicate → 422, resend with `is_duplicate`), delete | ✅ |
| Batches | list, detail, create, auto-batch for a date, edit (`status`, `remarks`), delete | ✅ |
| Bid book | list, detail, create, edit (full and status-only), delete | ✅ |
| Courier | list, detail, create (JSON or with photo), buyer address prefill, edit, delete | ✅ |
| Contracts | list, detail, create, edit (items replaced), delete | ✅ |
| Sales register | create, delete | ✅ (list can't load, see below) |
| Ex-factory | list with metrics, detail, create (reconciles on save), delete, CSV export | ✅ |
| Errors | 401 on expired token, 422 with field errors, JSON 404 for unknown paths | ✅ |

### Needs fixes from the API developer

**Broken (500)**

1. `GET /sales-register` returns 500 (it inserts a record during a GET). The Sales register list can't load.
2. `GET /sales-register/{id}` returns 500.
3. `GET /samples/{id}` returns 500, and a missing id gives 500 instead of 404. The app shows the list's copy instead.
4. `PUT /sales-register/{id}` returns 500 (`garden` relation).
5. `DELETE /samples/{id}` returns 500 when the sample has buyers allocated; should be 422.
6. `PUT /contracts/{id}` with an item without a price returns 500; should be 422. The app checks this before saving.
7. `POST /ex-factory` CGST+SGST bill with `"igst_amount": null` returns 500 (DB constraint). The app leaves nulls out.
8. 500 responses show SQL and stack traces: set `APP_DEBUG=false`.

**Edit says "updated successfully" but doesn't save**

9. `PUT /samples/{id}`: only `remarks` and `arrival_date` save.
10. `PUT /offer-lists/{id}`: price, prompt days and parties don't save.
11. `PUT /ex-factory/{id}`: `credit_days` doesn't save.

**Inputs ignored**

12. `GET /samples` ignores `arrival_date` (Home shows the total, not today's count) and `search`.
13. `POST /batches` with `sample_ids` ignores `batch_date` (dated today).
14. `POST /courier-entries`: `posting_list_ids` are accepted but not linked.
15. `POST /offer-lists`: only `party_1`–`party_5` save; `party_6`–`party_10` exist on the record but are dropped. The app allows 5 (`_maxParties` in `offer_lists_screens.dart`).

**Consistency (not urgent)**

16. Duplicate offer invoice returns HTTP 200 with `success: false` and `data: null`. Keep the override / reoffer / reject flow, but return 409 (or 422 like samples) with the existing offer's details.
17. `GET /sellers` uses Laravel's paginator (`data.data`); other lists use a named key plus `data.pagination`.
18. Date-only fields come back as UTC timestamps (31 Dec → `2026-12-30T18:30:00Z`); plain `YYYY-MM-DD` would be safer.
19. A deleted bid book lot's `GET` returns 200 with `data: null` instead of 404.
20. Ex-factory: a bill matching a sale on mark and invoice with equal packages and kg was still flagged `qty_mismatch`.

**Missing APIs that would help**

21. Create buyer and create seller (the web app has a quick-register). Then forms could accept new names, not only picks.
22. `GET /dashboard/summary` for Home counts (optional).

**Order:** 1–5 and 9–12 first; they block app screens.

### Will work without an app update once fixed

3, 5–9, 12–14 and 16–18. The app already sends the right values and reads both old and new formats. Sales register (1, 2) should also work, but its response shape has never been seen, so it may need a small fix. Edit screens for offers, sales and ex-factory (4, 10, 11) and parties 6–10 (15) need an app update.

## Not built yet (from the spec)

- Offline read cache (drift). Lists currently need a connection; the offline banner and write blocking are in place.
- Form drafts (autosave) and "Discard changes?" on back.
- Flavors (dev/staging/prod entry points), Sentry. (Android release CI is done: see the README.)
- Tests (unit, widget, golden, integration).
- Localisation files (`.arb`); strings are inline for now.
