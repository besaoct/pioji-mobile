# Status — 29 Oct 2026

## Built

All screens in the spec exist and compile with zero analyzer issues:

- Splash, 3-page onboarding, sign in (with session-expired state), Terms and Privacy pages
- Tab shell with the gradient bottom bar (tablet: side rail)
- Home: 4 live counts, quick actions, a checklist driven by real counts, recent samples
- Samples: list (status segments, arrival filter), new sample (2-of-3 weights, duplicate "save anyway"), detail
- Batches: list, new batch (pick unbatched samples, 48 cap), auto-batch for a date, detail
- Offer lists: list (date/grade/type filters), new offer (override / re-offer on duplicates), detail
- Offered today: day switcher, offer/sample tabs, single and multi-select buyer allocation
- Bid book: tabbed card list, new/edit lot, detail with one-tap status change
- Courier: list, new entry (buyer address prefill, barcode scanner, photo, posting lists), detail
- Contracts: list, new contract with repeatable items and live totals, detail
- Sales register: list, new sale with live amount, detail
- Ex-factory: status summary tiles, list, CSV export + share, new bill (IGST / CGST+SGST with 5% fill), detail
- More and Settings (theme, version, legal), sign out
- App ID `com.gitcs.pioji` on iOS and Android; launcher icons (two-leaf mark, light/dark, Android adaptive + monochrome) and native splash

## Not verified

- **Every API response shape.** The API rejects the admin login (401), so no authenticated call has been made. Models parse defensively, but field names may need adjusting once real responses are seen. Update `docs/API_DOCS.md` with real samples when login works.
- The app has not been run on a device or simulator by an agent; only `flutter analyze` and a simulator build were run.

## Blocked on the backend

See `docs/FLUTTER_IMPLEMENTATION.md` §18. In short:

1. `POST /auth/login` must accept admin accounts. **Nothing works until this is fixed.**
2. `GET /auth/me`, `POST /auth/logout`.
3. Lookup lists: `/gardens`, `/buyers`, `/sellers`, `/negotiators`, `/posting-lists`. Until they exist, pickers ask for a numeric ID (buyers fall back to the offered-today list).
4. `GET/PUT/DELETE /{module}/{id}`: detail screens use the list item; only bid book can be edited.
5. `APP_DEBUG=false`, JSON 404 for unknown API paths.

## Not built yet (from the spec)

- Offline read cache (drift). Lists currently need a connection; the offline banner and write blocking are in place.
- Form drafts (autosave) and "Discard changes?" on back.
- Flavors (dev/staging/prod entry points), Sentry, CI.
- Tests (unit, widget, golden, integration).
- Localisation files (`.arb`); strings are inline for now.
