# Status — 30 Oct 2026

## Built

All screens in the spec exist and compile with zero analyzer issues:

- Splash, 3-page onboarding, sign in (with session-expired state), Terms and Privacy pages
- Tab shell with the gradient bottom bar (tablet: side rail)
- Home: 4 live counts, quick actions, a checklist driven by real counts, recent samples
- Samples: list (status segments, arrival filter), new and edit sample (2-of-3 weights, duplicate "save anyway"), detail with delete
- Batches: list, new batch (pick unbatched samples, 48 cap), auto-batch for a date, detail
- Offer lists: list (date/grade/type filters), new offer (override / re-offer on duplicates), detail
- Offered today: day switcher, offer/sample tabs, single and multi-select buyer allocation
- Bid book: tabbed card list, new/edit lot, detail with one-tap status change
- Courier: list, new entry (buyer address prefill, barcode scanner, photo, posting lists), detail
- Contracts: list, new contract with repeatable items and live totals, detail
- Sales register: list, new sale with live amount, detail
- Ex-factory: status summary tiles, list, CSV export + share, new bill (IGST / CGST+SGST with 5% fill), detail
- Every detail screen loads by ID (`GET /{module}/{id}`): it shows the list copy at once, refreshes from the API, and works from a deep link
- Grade pickers load `GET /grades`, falling back to a built-in list
- More and Settings (theme, version, legal), sign out
- App ID `com.gitcs.pioji` on iOS and Android; launcher icons (two-leaf mark, light/dark, Android adaptive + monochrome) and native splash

## Not verified

- **Every API response shape.** The API rejects the admin login (401), so no authenticated call has been made. Models parse defensively, but field names may need adjusting once real responses are seen. Update `docs/API_DOCS.md` with real samples when login works.
- The app has not been run on a device or simulator by an agent; only `flutter analyze` and a simulator build were run.

## Blocked on the backend

Route check on 30 Oct 2026. Details in `docs/API_DOCS.md` (status table) and `docs/FLUTTER_IMPLEMENTATION.md` §18.

1. `POST /auth/login` must accept admin accounts. **Still 401. Nothing works until this is fixed.**
2. `GET /auth/me` is missing. The app keeps a saved session until any request returns 401.
3. `GET /negotiators` and `GET /posting-lists` are missing. The negotiator picker asks for an ID; posting lists say they aren't available. (`/gardens`, `/buyers`, `/sellers`, `/grades` and `/auth/logout` exist.)
4. Edit (`PUT`) is missing for offer lists, batches, courier, contracts, sales and ex-factory; delete is missing for everything except samples. Only samples (edit + delete) and bid book (edit) have those actions in the app.
5. `APP_DEBUG=false`, JSON 404 for unknown API paths.

## Not built yet (from the spec)

- Offline read cache (drift). Lists currently need a connection; the offline banner and write blocking are in place.
- Form drafts (autosave) and "Discard changes?" on back.
- Flavors (dev/staging/prod entry points), Sentry, CI.
- Tests (unit, widget, golden, integration).
- Localisation files (`.arb`); strings are inline for now.
