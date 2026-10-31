# Tea Trading ERP — Flutter App Implementation Guide

| | |
|---|---|
| **Platform** | Flutter (latest stable), iOS + Android, phone and tablet |
| **API** | [API_DOCS.md](API_DOCS.md) — `https://gold-sardine-283964.hostingersite.com/api/v1` |
| **Design** | Palette 9 "Assam green iOS", borderless iOS cards, system font |
| **State** | Riverpod (code-gen) |
| **Routing** | go_router with a `StatefulShellRoute` tab shell |
| **Status** | Spec, ready to build |

---

## Contents

1. [Goals and principles](#1-goals-and-principles)
2. [Tech stack](#2-tech-stack)
3. [Architecture](#3-architecture)
4. [Project structure](#4-project-structure)
5. [Design system](#5-design-system)
6. [Shared components](#6-shared-components)
7. [Navigation and routing](#7-navigation-and-routing)
8. [Screens and UX](#8-screens-and-ux)
9. [Networking layer](#9-networking-layer)
10. [State management](#10-state-management)
11. [Data models](#11-data-models)
12. [Forms](#12-forms)
13. [Loading, empty, error and offline states](#13-loading-empty-error-and-offline-states)
14. [Security](#14-security)
15. [Accessibility and localisation](#15-accessibility-and-localisation)
16. [Testing](#16-testing)
17. [Environments, build and release](#17-environments-build-and-release)
18. [Backend requirements before launch](#18-backend-requirements-before-launch)
19. [Build order](#19-build-order)

---

## 1. Goals and principles

- **Field-first.** Staff use the app on the factory floor, in the tasting room and at the courier desk: fast entry, big tap targets, a barcode scanner for tracking numbers, and forms that survive interruptions.
- **One source of truth for style.** Every colour, radius, spacing and shadow comes from tokens in `core/design/`. No hex values or magic numbers in feature code.
- **Feature-first architecture.** Each business module is a self-contained folder with its own data, domain and presentation layers. Features never import each other's internals.
- **Production-ready from day one.** Light and dark mode both finished, every screen has loading, empty, error and offline states, every form has server-side validation mapped to fields, and duplicate submissions are impossible.
- **Real data only.** The home screen shows counts the API returns. No placeholder metrics ship.

---

## 2. Tech stack

Use the latest stable release of every package at the time of the first commit. Skip pre-releases.

| Concern | Package | Why |
|---|---|---|
| State | `flutter_riverpod` 3 (no generator) | `AsyncNotifier`, easy testing overrides |
| Routing | `go_router` | Declarative routes, redirects for auth, `StatefulShellRoute` for tabs, deep links |
| HTTP | `dio` | Interceptors, cancel tokens, multipart, downloads |
| Models | Hand-written immutable classes + sealed classes | Tolerant `fromJson` via `J` helpers; no code generation |
| Secure storage | `flutter_secure_storage` | Sanctum token in Keychain / Keystore |
| Preferences | `shared_preferences` | Theme choice, onboarding seen, last filters |
| Local cache | `drift` (SQLite), planned | Offline read cache for lists and master data (not built yet) |
| Connectivity | `connectivity_plus` | Offline banner, block writes when offline |
| Camera / files | `image_picker`, `mobile_scanner` | Courier photo, barcode scan for `tracking_number` |
| Files | `path_provider`, `share_plus`, `open_filex` | Save and share the ex-factory CSV |
| Formatting | `intl` | `en_IN` currency (₹) and number grouping (1,23,456) |
| Logging / crash | `logger`, `sentry_flutter` (or Firebase Crashlytics) | Release crash reports with PII scrubbing |
| Lints | `very_good_analysis` (or `flutter_lints`) | Strict analysis |
| Tests | `flutter_test`, `mocktail`, `integration_test`, `http_mock_adapter` | Unit, widget, golden, end-to-end |

> **As built (29 Oct 2026):** `freezed` 3 and `riverpod_generator` 4 need different `analyzer` versions, so the app uses plain Riverpod providers and hand-written models. The `@freezed` / `@riverpod` snippets below show intent; the real code is in `lib/` and described in `agent/CONVENTIONS.md`.

No icon font beyond the platform: use `CupertinoIcons` on both platforms for a consistent outline look.

---

## 3. Architecture

Feature-first with clean layers inside each feature.

```
presentation  ──>  application  ──>  domain  <──  data
 (widgets,          (Riverpod         (entities,    (DTOs, API
  screens)           controllers)      repo         clients, cache,
                                       interfaces)  repo impl)
```

| Layer | Contains | May depend on |
|---|---|---|
| `presentation` | Screens, widgets, form UI | `application`, `domain`, `core/design`, `core/widgets` |
| `application` | Riverpod notifiers / controllers, use-case logic (2-of-3 calc, duplicate flow) | `domain` |
| `domain` | Entities (freezed), repository interfaces, value objects, enums | nothing (pure Dart) |
| `data` | DTOs, API data sources, drift cache, repository implementations | `domain`, `core/network` |

Rules:

- A feature exposes only its routes and public providers through `feature_name.dart`. Other features never import `data/` or `presentation/` of another feature.
- Shared lookups (gardens, buyers, sellers, couriers, grades) live in the `masters` feature and are consumed through its public providers.
- `core/` holds cross-cutting code only: network, design, router, storage, errors, utilities, shared widgets.
- Repositories return `Result<T>` (success or `AppFailure`). Widgets never see `DioException`.

---

## 4. Project structure

```
lib/
├── main_dev.dart                 # flavor entry points
├── main_staging.dart
├── main_prod.dart
├── bootstrap.dart                # ProviderScope, error zones, Sentry init
├── app.dart                      # MaterialApp.router, themes, router
│
├── core/
│   ├── config/
│   │   └── env.dart              # baseUrl, flavor (from --dart-define)
│   ├── design/
│   │   ├── tokens.dart           # AppColors, AppSpace, AppRadius, AppShadow
│   │   ├── typography.dart       # AppText styles (system font)
│   │   ├── theme.dart            # ThemeData light/dark + extensions
│   │   └── theme_ext.dart        # context.colors, context.text helpers
│   ├── network/
│   │   ├── dio_provider.dart
│   │   ├── auth_interceptor.dart
│   │   ├── error_mapper.dart     # DioException -> AppFailure
│   │   ├── api_envelope.dart     # { success, message, data }
│   │   └── paginated.dart        # Page<T>
│   ├── errors/
│   │   ├── app_failure.dart      # sealed failures
│   │   └── result.dart
│   ├── storage/
│   │   ├── secure_store.dart
│   │   ├── prefs.dart
│   │   └── db/                   # drift database + tables for cache
│   ├── router/
│   │   ├── app_router.dart
│   │   ├── routes.dart           # route names and paths
│   │   └── shell_scaffold.dart   # bottom tab bar / tablet rail
│   ├── connectivity/
│   │   └── connectivity_provider.dart
│   ├── utils/
│   │   ├── formatters.dart       # ₹, kg, dates
│   │   ├── weight_calc.dart      # 2-of-3 rule
│   │   └── debouncer.dart
│   └── widgets/                  # shared components (section 6)
│
├── features/
│   ├── onboarding/
│   ├── auth/
│   ├── home/
│   ├── masters/                  # gardens, buyers, sellers, couriers, grades
│   ├── offer_lists/
│   ├── samples/
│   ├── batches/
│   ├── allocation/               # samples offered today
│   ├── bid_book/
│   ├── courier/
│   ├── contracts/
│   ├── sales_register/
│   ├── ex_factory/
│   └── settings/
│
└── l10n/
    └── app_en.arb
```

Every feature follows the same internal shape (example: `samples`):

```
features/samples/
├── samples.dart                          # public exports: routes, providers
├── domain/
│   ├── sample.dart                       # freezed entity
│   ├── sample_status.dart                # enum
│   ├── sample_filter.dart                # freezed filter object
│   └── samples_repository.dart           # abstract interface
├── data/
│   ├── sample_dto.dart                   # json_serializable
│   ├── samples_api.dart                  # Dio calls
│   ├── samples_cache.dart                # drift DAO
│   └── samples_repository_impl.dart
├── application/
│   ├── samples_list_controller.dart      # paginated AsyncNotifier
│   ├── sample_form_controller.dart       # create/edit, submit, 422 mapping
│   └── sample_filter_provider.dart
└── presentation/
    ├── samples_list_screen.dart
    ├── sample_detail_screen.dart
    ├── sample_form_screen.dart
    └── widgets/
        ├── sample_row.dart
        └── sample_filter_sheet.dart
```

---

## 5. Design system

Palette 9, "Assam green iOS". Leaf-tinted neutrals, a deep tea-green accent, and borderless cards in the iOS style.

### 5.1 Colour tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F0F3F1` | `#0A0D0B` | Screen background (grouped background) |
| `surface` | `#FFFFFF` | `#181D1A` | Cards, grouped lists, sheets |
| `surfaceRaised` | `#FFFFFF` | `#222824` | Sheets and dialogs above cards |
| `fill` | `#7680791F` | `#3A423D` | Segmented control track, search field |
| `textPrimary` | `#121815` | `#EEF3F0` | Titles, key values |
| `textSecondary` | `#4F5853` | `#ABB5AF` | Body |
| `textTertiary` | `#6B756F` | `#87918B` | Labels, metadata, placeholders |
| `separator` | `#E2E7E4` | `#28302C` | Hairlines between rows inside one card only |
| `accent` | `#1F5A43` | `#4FB487` | Accent text, icons, links, active tab icon |
| `accentFill` | `#1F5A43` | `#237A57` | Primary button and filled controls |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Text on `accentFill` |
| `accentTint` | `#1F5A43` @ 8% | `#4FB487` @ 14% | Selected tile behind the active tab icon, selected row |
| `success` | `#2E7D4F` | `#4CC27F` | Matched, delivered, approved |
| `warning` | `#9A6200` | `#E5B040` | Mismatch, pending, held |
| `danger` | `#B3261E` | `#FF6B60` | Error text, unregistered, expired |
| `dangerFill` | `#B3261E` | `#B3261E` | Destructive button background (light text) |

Contrast notes (WCAG AA, 4.5:1 for body text):

- White on `accentFill` is 7.9:1 in light mode and 5.3:1 in dark mode. The dark fill is `#237A57`, slightly deeper than the `#2F8A64` shown in the preview, because white on `#2F8A64` is only 4.3:1.
- `textTertiary` in light mode is `#6B756F` (4.8:1 on white). The preview used `#77817B`, which falls just short of AA.
- Status is never shown by colour alone: every status badge also carries a text label.

### 5.2 Typography

System font only: San Francisco on iOS, Roboto on Android. Do not set `fontFamily`. No monospace anywhere, including invoice numbers and tracking IDs.

| Style | Size / weight | Use |
|---|---|---|
| `largeTitle` | 30 / w600 | Top of each tab root screen (collapses on scroll) |
| `title` | 20 / w600 | Screen titles on pushed screens, sheet titles |
| `headline` | 17 / w600 | Card titles, primary row text |
| `body` | 16 / w400 | Body, input text |
| `callout` | 15 / w400 | Secondary row text |
| `footnote` | 13 / w400 | Metadata, helper and error text |
| `caption` | 12 / w500 | Section labels above grouped cards (sentence case) |
| `metric` | 24 / w600, tabular figures | Numbers in summary cards |

All styles scale with the system text size. Test at 200%.

Selected and active states change colour or background only. They never change weight or size.

### 5.3 Spacing, radius, shadow

```dart
abstract final class AppSpace {
  static const xxs = 2.0, xs = 4.0, sm = 8.0, md = 12.0,
      lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const screenH = 16.0;   // horizontal screen gutter
  static const rowMinH = 48.0;   // minimum tap target / list row
}

abstract final class AppRadius {
  static const control = 11.0;   // buttons, inputs, segmented control
  static const card = 14.0;      // cards and grouped lists
  static const sheet = 20.0;     // bottom sheets, dialogs
  static const tile = 7.0;       // icon tiles in tab bar and rows
}
```

- **Shape.** Use `RoundedSuperellipseBorder` (Flutter 3.32+) for every rounded surface to get the continuous iOS corner curve. Fall back to `RoundedRectangleBorder` only where an API requires a `BorderRadius`.
- **No borders on cards.** A card stands apart from the screen through surface tone (`surface` on `background`) plus a very light shadow in light mode. In dark mode there is no shadow; the tone step alone does the work.
- **Shadow (light mode only):**

```dart
abstract final class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x09000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const none = <BoxShadow>[];
}
```

- **Rows inside a card** are separated by a 0.5 px `separator` hairline inset to the text's left edge, iOS Settings style. No hairline above the first row or below the last.
- **No blur or frosted glass** anywhere. No gradients except the tab bar fade (5.5).

### 5.4 Theme setup

```dart
// core/design/theme.dart
ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? AppColors.light : AppColors.dark;
  final base = ThemeData(useMaterial3: true, brightness: b);

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    colorScheme: base.colorScheme.copyWith(
      primary: c.accentFill, onPrimary: c.onAccent,
      surface: c.surface, onSurface: c.textPrimary,
      error: c.danger, outline: c.separator,
    ),
    extensions: [c],                       // AppColors is a ThemeExtension

    // No interaction chrome: no ripple, hover, focus or highlight.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,

    filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
      shape: const WidgetStatePropertyAll(
          RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)))),
    )),
    // outlinedButtonTheme / textButtonTheme: same overlay + shape

    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _noBorder, enabledBorder: _noBorder,
      focusedBorder: _noBorder,             // same as enabled: no focus ring
      errorBorder: _noBorder, focusedErrorBorder: _noBorder,
      hintStyle: TextStyle(color: c.textTertiary),
      errorStyle: TextStyle(color: c.danger, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(color: c.separator, thickness: 0.5, space: 0.5),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

const _noBorder = OutlineInputBorder(
  borderSide: BorderSide.none,
  borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
);
```

Theme mode follows the system by default. Settings offers System / Light / Dark, saved in `shared_preferences`.

### 5.5 Bottom tab bar

- Five tabs. Home sits in the centre, is selected on launch, and is the same size as the other tabs (none raised).
- Each icon sits on a 28 px square tile (radius `tile`) inside a 48 px target, with equal padding all round. The active tile gets the `accentTint` background and the `accent` icon colour; inactive tiles get a solid `background` base so scrolling content never shows through them.
- Labels at 11 px. Active labels change colour only.
- No top border line, no blur, no frosted glass. The bar is one `LinearGradient` over a 142 px area (82 px bar plus a 60 px fade above it): transparent at the top edge and getting continuously deeper all the way to the bottom edge, like a shadow rising from below. Opacity ramps from 0 at the top to full right where the icons begin (42%), so the tall fade zone stays see-through while content edges never cut across the icons, and the colour shifts from the screen `background` to a deeper shade (light `#C9D3CD`, dark `#000000`) across the whole height, with no flat middle band. Both ramps follow the smootherstep curve `t*t*t*(t*(6t-15)+10)`, with 25 stops, so there is no hard upper line. Inactive icon tiles have no background of their own (the bar is already solid behind them), so no squares show.
- Respect the bottom safe-area inset. Add no extra padding beyond it.
- On tablets (shortest side ≥ 600) switch to a left `NavigationRail` with the same tiles and icon sizes.

---

## 6. Shared components

All live in `core/widgets/` and read only from tokens.

| Component | Notes |
|---|---|
| `AppScaffold` | Background colour, safe area, optional large title with a collapsing `SliverAppBar`, pull-to-refresh |
| `AppCard` | `surface` + superellipse `card` radius + `AppShadow.card` in light mode only. No border |
| `GroupedSection` | Caption label + `AppCard` holding rows with inset hairlines (iOS grouped list) |
| `AppListRow` | Leading tile, title, subtitle, trailing value or chevron. Min height 48. Text never wraps: titles and subtitles are one line with an ellipsis (`maxLines: 1`, `TextOverflow.ellipsis`), trailing actions never shrink, and a long-press shows the full text in a `Tooltip`. Short numeric values may scale down instead (`FittedBox(fit: BoxFit.scaleDown)`) |
| `MetricCard` | Caption + `metric` number. Tappable, opens the filtered list |
| `StatusBadge` | Tinted background (status colour @ 12%) + status-colour text. Always has a text label |
| `PrimaryButton` | `accentFill`, height 50, full width. Shows an inline spinner while loading and ignores taps (prevents double submit) |
| `SecondaryButton` | `fill` background, `accent` text. No border |
| `TextLinkButton` | `accent` text with a trailing chevron |
| `DestructiveButton` | `dangerFill` + white text |
| `AppTextField` | Label above the field, `surface` fill, no border, error text below, helper text, optional suffix (unit "kg", "₹") |
| `AppNumberField` | Decimal keyboard, locale-aware parsing, optional unit |
| `AppDateField` | Opens a Cupertino date picker in a sheet. Shows `17 Oct 2026`, sends `2026-10-17` |
| `AppPickerField` | Opens a searchable sheet for masters (garden, buyer, seller, courier, grade). Remembers recent choices |
| `AppMultiPicker` | Multi-select sheet (buyers, sample ids) with a selected count and a cap (48 samples) |
| `SegmentedTabs` | iOS segmented control on a `fill` track |
| `SearchField` | `fill` background, debounced 350 ms |
| `FilterChipsBar` | Active filters as removable chips + "Filters" button that opens a sheet |
| `AppBottomSheet` | Drag handle, `sheet` radius, keyboard-aware |
| `ConfirmDialog` | Cupertino-style. Large deletions require typing the item's name |
| `SkeletonList` / `SkeletonCard` | Shimmer-free pulsing blocks in the same layout as the real content (no layout shift) |
| `EmptyState` | Icon, headline, one-line body, one action |
| `ErrorState` | Message from `AppFailure` + Retry |
| `OfflineBanner` | Slim banner under the title when offline |
| `AppToast` | Short confirmations ("Sample saved") |
| `PaginatedListView` | Loads the next page 300 px before the end, shows a footer spinner, handles end of list |

---

## 7. Navigation and routing

### 7.1 Tab layout

| Tab | Icon | Root screen | Also reached from here |
|---|---|---|---|
| Samples | `lab_flask` | Samples list | Batches, unbatched samples |
| Offers | `doc_text` | Offer lists | Samples offered today (allocation) |
| **Home** (centre, default) | `house` | Dashboard | Shortcuts to every module |
| Bids | `hammer` | Bid book | — |
| More | `square_grid_2x2` | Module menu | Courier register, contracts, sales register, ex-factory, settings |

### 7.2 Route table

| Path | Name | Screen |
|---|---|---|
| `/splash` | `splash` | Splash (token check) |
| `/onboarding` | `onboarding` | Onboarding pages |
| `/login` | `login` | Sign in |
| `/home` | `home` | Dashboard |
| `/samples` | `samples` | Samples list |
| `/samples/new` | `sampleNew` | Create sample |
| `/samples/:id` | `sampleDetail` | Sample detail |
| `/samples/:id/edit` | `sampleEdit` | Edit sample |
| `/samples/batches` | `batches` | Batches list |
| `/samples/batches/new` | `batchNew` | Create batch (pick samples) |
| `/samples/batches/auto` | `batchAuto` | Auto-batch for a date |
| `/samples/batches/:id` | `batchDetail` | Batch detail |
| `/offers` | `offers` | Offer lists |
| `/offers/new` | `offerNew` | Create offer list |
| `/offers/:id` | `offerDetail` | Offer list detail |
| `/offers/:id/edit` | `offerEdit` | Edit offer list |
| `/offers/today` | `offeredToday` | Samples offered today grid |
| `/offers/today/allocate` | `allocate` | Allocate buyers (single or bulk) |
| `/bids` | `bids` | Bid book |
| `/bids/new` | `bidNew` | Create lot |
| `/bids/:id` | `bidDetail` | Lot detail |
| `/bids/:id/edit` | `bidEdit` | Edit lot |
| `/more` | `more` | Module menu |
| `/more/courier` | `courier` | Courier register |
| `/more/courier/new` | `courierNew` | Create courier entry |
| `/more/courier/:id` | `courierDetail` | Courier detail |
| `/more/contracts` | `contracts` | Contracts |
| `/more/contracts/new` | `contractNew` | Create contract |
| `/more/contracts/:id` | `contractDetail` | Contract detail |
| `/more/contracts/:id/edit` | `contractEdit` | Edit contract |
| `/more/sales` | `sales` | Sales register |
| `/more/sales/new` | `salesNew` | Create entry |
| `/more/sales/:id` | `salesDetail` | Entry detail |
| `/more/ex-factory` | `exFactory` | Ex-factory register |
| `/more/ex-factory/new` | `exFactoryNew` | Create bill |
| `/more/ex-factory/:id` | `exFactoryDetail` | Bill detail |
| `/more/settings` | `settings` | Settings |
| `/more/settings/legal/:doc` | `legal` | Terms of service / Privacy policy |

Forms (`/new`, `/edit`) push full-screen above the tab bar via `parentNavigatorKey: rootNavigatorKey`, so the tab bar is hidden while entering data. Pickers and filters open as bottom sheets, not routes.

### 7.3 Router

```dart
// core/router/app_router.dart
@riverpod
GoRouter appRouter(Ref ref) {
  final auth = ref.watch(authStateProvider);          // AsyncValue<AuthState>
  final seenOnboarding = ref.watch(onboardingSeenProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: ref.watch(authRefreshListenableProvider),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';

      final signedIn = auth.valueOrNull is Authenticated;
      final publicRoutes = {'/onboarding', '/login'};

      if (!signedIn) {
        if (!seenOnboarding) return loc == '/onboarding' ? null : '/onboarding';
        return publicRoutes.contains(loc) ? null : '/login';
      }
      if (loc == '/splash' || publicRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: samplesRoutes),   // index 0
          StatefulShellBranch(routes: offersRoutes),    // index 1
          StatefulShellBranch(routes: homeRoutes),      // index 2 (default)
          StatefulShellBranch(routes: bidsRoutes),      // index 3
          StatefulShellBranch(routes: moreRoutes),      // index 4
        ],
      ),
    ],
    errorBuilder: (_, state) => NotFoundScreen(path: state.uri.toString()),
  );
}
```

- Each feature exports its `List<RouteBase>` from `feature_name.dart`.
- Use typed paths: `context.goNamed(Routes.sampleDetail, pathParameters: {'id': '$id'})`.
- Tapping the active tab pops it to its root (`shell.goBranch(i, initialLocation: i == shell.currentIndex)`).
- A `401` anywhere clears the token, `authStateProvider` flips to signed-out, and the redirect sends the user to `/login`, keeping the attempted path in `?from=` so they return there after signing in.
- Android back button: pops within the tab, then returns to Home, then exits.
- Deep links: `teaerp://samples/123` and `https://<domain>/app/samples/123` map to the same routes.

---

## 8. Screens and UX

Every list screen has: large title, search, filter chips, pull-to-refresh, pagination, skeleton loading, empty state, error state, offline banner, and a primary "New …" button in the top bar.

Every detail screen has: a summary card, grouped sections of fields, a status badge, and Edit / Delete actions when the backend supports them (see 18).

Every form has: labelled fields grouped in cards, inline validation, server errors mapped to fields, a sticky Save button above the keyboard, a draft kept if the user leaves, and a "Discard changes?" prompt on back.

### 8.1 Splash

- The logo in the accent colour on `background`. No coloured tile behind it.
- Reads the token from secure storage. With a token: go to Home and validate it in the background (see 18). Without one: Onboarding the first time, Login after that.
- Native splash (`flutter_native_splash`) matches, so there's no flash.

### 8.2 Onboarding (first launch only)

Three swipeable pages and a Skip link. Content explains real capabilities only, with no invented statistics:

1. **Track every lot** — offer lists, samples and batches in one place.
2. **Allocate and bid faster** — assign buyers to today's samples and manage the bid book on the go.
3. **Close the loop** — courier, contracts, sales and ex-factory reconciliation.

Final page: "Get started" primary button → Login. Sets `onboarding_seen = true`.

### 8.3 Login

- Fields: Email (email keyboard, autofill hint `email`), Password (show/hide toggle, autofill hint `password`).
- `device_name` is sent automatically: platform + model from `device_info_plus` (e.g. `iOS_iPhone15,3`).
- Button: "Sign in", with a loading state that blocks a double submit.
- Errors: 422 → under each field; 401 → "That email and password don't match." above the button; offline → "You're offline. Connect to sign in."
- Links: "Forgot password?" opens the web admin reset page in the browser; Terms and Privacy at the bottom.
- Autofill works with the iOS and Android password managers (`AutofillGroup`).

### 8.4 Home (dashboard)

Large title "Today" with the date as a caption.

1. **Summary cards (2 × 2 grid)** — each number comes from the API (using `per_page=1` and reading the total from the pagination meta). Tapping a card opens the filtered list:
   - Samples received today → `/samples?arrival_date=today&status=received`
   - Unbatched samples → `/samples/batches` (count from `batches/unbatched-samples`)
   - Open bids → `/bids?tab=open`
   - Ex-factory mismatches → `/more/ex-factory?register_status=price_mismatch` + `qty_mismatch`
2. **Quick actions** (horizontal row of tiles): New sample, New offer, Allocate buyers, New courier entry, Scan tracking number.
3. **Today's checklist** — driven by real state, each line links to its fix:
   - "12 samples aren't in a batch yet" → Auto-batch
   - "5 lots offered today have no buyers" → Allocate
   - "3 bids are awaiting allocation" → Bid book, `awaiting_allocation` tab
   - "2 ex-factory bills are unregistered" → Ex-factory filter
   - Hidden when the count is zero. When every item is clear: "You're all caught up."
4. **Recent activity** — latest five items across samples, offers and bids (merged by date), each opening its detail.

Pull-to-refresh reloads all sections. Each section loads and fails independently.

### 8.5 Samples

**List** (`/samples`)
- Segmented control: All · Received · Pending evaluation · Evaluated · Assigned · Approved (maps to `status`).
- Search (`search`), filter sheet: arrival date.
- Row: garden + grade (headline), `invoice_prefix inv_no` · packages × weight (subtitle), total kg (trailing), status badge.
- Top bar: "Batches" link and "New" button.

**Create / edit** (`/samples/new`)
- Cards: *Lot* (arrival date = today by default, garden picker, grade picker, invoice prefix, invoice no), *Weight* (packages, weight per package, total kg with the 2-of-3 rule, section 12.2), *Details* (sample type, status, remarks).
- Duplicate invoice: if the server rejects as duplicate, show a sheet "This invoice already exists" with "Save anyway" (resend with `is_duplicate: true`) and "Cancel".
- After save: toast "Sample saved", go to the detail, refresh the list and Home.

**Detail** (`/samples/:id`): summary card (garden, grade, invoice, status), weight section, details section, batch it belongs to (link).

### 8.6 Batches

**List** (`/samples/batches`): segmented Open · Closed, date filter, search. Row: batch name, date, sample count "32 / 48" with a thin progress bar, status badge.

**Create** (`/samples/batches/new`): name (optional, "Generated automatically if empty"), date, status, notes, then "Add samples" → multi-picker loaded from `batches/unbatched-samples?date=` with a live counter and a hard cap at 48.

**Auto-batch** (`/samples/batches/auto`): pick a date, show "18 unbatched samples → 1 batch" as a preview, confirm → `POST /batches/create-for-date`, then show the batches created.

**Detail**: header, sample list, notes.

### 8.7 Offer lists

**List** (`/offers`): search, filter sheet (garden, grade, type, date from/to). Row: garden + grade, `inv_prefix inv_no` · pkgs × nett, price ₹ (trailing). Top bar: "Offered today" link and "New".

**Create / edit**: cards *Lot* (date, garden, grade, invoice prefix, invoice no, type), *Weight* (pkgs, nett, total kg via 2-of-3, gross weight, date of packing), *Price* (price, currency default INR, prompt days), *Parties* (party 1, party 2).

Duplicate handling: on a duplicate response show a sheet with three clear options matching `duplicate_action`:
- **Override** — replace the existing offer
- **Re-offer** — keep both, mark as re-offered
- **Cancel** — don't save (`reject`)

**Detail**: all fields grouped, allocated buyers (if any).

### 8.8 Samples offered today (allocation)

**Grid** (`/offers/today`)
- Date selector at the top (defaults to today, chevrons for previous/next day).
- Segmented: Offer lists · Samples, with counts from the response.
- Each item card: garden, grade, invoice, and the buyers already allocated as small chips.
- Selection mode: long-press or "Select" → checkboxes on cards → bottom action bar "Allocate buyers (n)".

**Allocate** (`/offers/today/allocate`): a sheet with a searchable buyer multi-picker from `available_buyers`. One item → `allocate-buyers`; several → `bulk-allocate-buyers`. Success toast "Buyers allocated to 3 lots", grid refreshes.

### 8.9 Bid book

**List** (`/bids`)
- Tabs (horizontal scrolling segmented): All · Open · Parked · Held · Awaiting allocation (maps to `tab`).
- Search, filter sheet (garden, grade, status).
- Row: garden + grade, invoice · packages · net kg, and on the right the negotiated price (or max bid) in ₹, status badge, buyer name or "Unallocated".

**Create / edit**: cards *Lot* (garden name, grade, invoice number, packages, net weight), *Pricing* (seller incoming, max bid, negotiated, pencil — side-by-side pairs on wide screens), *Assignment* (status, buyer optional, negotiator optional), *Remarks*. Edit uses `PUT /bid-book/{id}`.

**Detail**: price ladder card showing incoming → max bid → negotiated → pencil, plus quick status actions (Park, Hold, Close) that call `PUT` with only `status`.

### 8.10 Courier register

**List** (`/more/courier`): search, filter sheet (buyer, courier service, pickup day, date). Row: buyer or custom destination, courier name · tracking number, pickup date, weight.

**Create** (`/more/courier/new`)
- *Destination*: segmented Buyer · Custom. Buyer → buyer picker, then `buyer-address/{id}` prefills the address (editable) and shows phone / WhatsApp. Custom → saved address picker from `services`.
- *Courier*: service picker (from `services`) or manual courier name; tracking number field with a **scan button** (`mobile_scanner`). Live validation: letters and digits only. Scanned values are stripped of spaces and dashes.
- *Pickup*: date (pickup day is filled automatically from the date and stays editable), AUC / PVT switches, weight, description.
- *Attachments*: photo from camera or gallery, compressed to ≤ 2 MB before upload (the server allows 25 MB, but field networks are slow). Preview thumbnail with remove.
- *Posting lists*: multi-picker (needs an endpoint, see 18).
- Sends `multipart/form-data` when a photo is attached, JSON otherwise. Upload progress shows on the Save button.

### 8.11 Contracts

**List** (`/more/contracts`): segmented Draft · Active · Expired · Cancelled, search, filter sheet (seller, buyer, date range). Row: title, contract number · seller, validity "17 Oct – 17 Nov 2026", status badge. Contracts expiring within 7 days show a warning badge.

**Create / edit**
- *Parties*: seller (required), buyer.
- *Contract*: title, contract number ("Generated automatically if empty"), effective date, expiry date (the picker can't go before the effective date), prompt days, discount, status.
- *Items*: a repeatable list of cards (grade, price/kg, quantity kg, currency) with "Add item" and swipe to remove. A live total footer shows total quantity and value.
- *Terms*: multiline terms and conditions.

**Detail**: header, items table with totals, terms, and status actions.

### 8.12 Sales register

**List** (`/more/sales`): segmented Pending · Confirmed · Dispatched · Delivered, search, filter sheet (buyer, grade, date range). Row: mark + grade, buyer, invoice, quantity kg × rate, amount ₹.

**Create**: *Deal* (buyer, grade, rate/kg, deal date), *Lot* (mark, invoice prefix, invoice no, pkgs, quantity kg), *Dispatch* (CN number, CN date, transport), *Other* (discount, remarks). Live amount = quantity × rate − discount.

### 8.13 Ex-factory register

**List** (`/more/ex-factory`)
- Status summary strip at the top with counts: Matched · Price mismatch · Qty mismatch · Unregistered. Tapping one filters the list.
- Search, filter sheet (supplier, date range).
- Row: bill no / mark · invoice, supplier, total bill value ₹, reconciliation badge.
- Top bar: "Export" → downloads the CSV with the current filters, then opens the share sheet.

**Create**
- *Bill*: bill date, supplier, mark, invoice prefix, invoice no.
- *Quantity*: pkgs, nett (total kg).
- *Tax*: taxable value, GST type segmented IGST · CGST + SGST. IGST shows one amount field; CGST + SGST shows two. Suggested amounts at 5% can be filled with one tap and edited. Total bill value is computed live and stays editable.
- *Dispatch*: CN number, CN date, transport, credit days.
- After save, show the reconciliation result: "Matched with sales register" or "Price mismatch: sales ₹310.00/kg, bill ₹310.50/kg", with a link to the matching sales entry.

### 8.14 More

A grouped menu:
- *Registers*: Courier register, Contracts, Sales register, Ex-factory register
- *Account*: Settings

### 8.15 Settings

- *Account*: signed-in name and email (needs `/auth/me`), Sign out (confirm, then calls logout and clears local data).
- *Appearance*: System / Light / Dark.
- *Data*: Clear cached data, Last synced time.
- *About*: version and build, Terms of service, Privacy policy (must state what the app actually stores: token in secure storage, cached lists on the device, photos uploaded only when you attach them), Contact support.

### 8.16 System screens

- **Not found** — "This page doesn't exist." + Go home.
- **Session expired** — handled by the redirect; a toast on the login screen: "Your session expired. Sign in again."
- **Force update** — if the backend returns a minimum app version (optional), a blocking screen with an "Update" button that opens the store.

---

## 9. Networking layer

### 9.1 Dio

```dart
// core/network/dio_provider.dart
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,                      // .../api/v1
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 60),     // photo uploads
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.addAll([
    AuthInterceptor(ref),                         // adds Bearer, handles 401
    if (Env.isDev) LogInterceptor(requestBody: true, responseBody: true),
  ]);
  return dio;
}
```

Rules:

- Never send a body on GET (the host firewall returns 403). Filters go in `queryParameters`; drop null and empty values before sending.
- Format dates as `yyyy-MM-dd` in one helper.
- Multipart arrays use the `[]` suffix (`posting_list_ids[]`); booleans are sent as `1` / `0`.
- Every request in a screen gets a `CancelToken` tied to the provider's `ref.onDispose`.
- Retry GETs once on timeouts or connection errors. Never retry POST/PUT automatically.

### 9.2 Envelope and pagination

```dart
@freezed
class ApiEnvelope<T> with _$ApiEnvelope<T> {
  const factory ApiEnvelope({
    required bool success,
    String? message,
    T? data,
    Map<String, List<String>>? errors,
  }) = _ApiEnvelope<T>;
}

@freezed
class Page<T> with _$Page<T> {
  const factory Page({
    required List<T> items,
    required int currentPage,
    required int lastPage,
    required int total,
  }) = _Page<T>;
  const Page._();
  bool get hasMore => currentPage < lastPage;
}
```

The `Page` parser must handle Laravel's standard paginator shape (`data`, `current_page`, `last_page`, `total`, or `meta` / `links` if the backend uses API Resources). Confirm the exact shape once live responses are available and update [API_DOCS.md](API_DOCS.md).

### 9.3 Failures

```dart
@freezed
sealed class AppFailure with _$AppFailure {
  const factory AppFailure.offline() = Offline;
  const factory AppFailure.timeout() = Timeout;
  const factory AppFailure.unauthorized() = Unauthorized;               // 401
  const factory AppFailure.forbidden(String? message) = Forbidden;      // 403
  const factory AppFailure.notFound() = NotFound;                       // 404, or 200 + HTML body
  const factory AppFailure.validation(String message,
      Map<String, List<String>> fieldErrors) = Validation;               // 422
  const factory AppFailure.duplicate(String message) = Duplicate;       // duplicate invoice
  const factory AppFailure.server(int? status, String? message) = Server;
  const factory AppFailure.unknown(Object error) = Unknown;
}
```

`error_mapper.dart` also treats a `200` whose content type is `text/html` as `notFound`, because unknown API paths currently return the web 404 page with status 200.

User-facing messages (one place, `l10n`):

| Failure | Message |
|---|---|
| offline | You're offline. Check your connection and try again. |
| timeout | The server is taking too long. Try again. |
| forbidden | You don't have access to this. |
| notFound | We couldn't find that. It may have been removed. |
| server | Something went wrong on our side. Try again. |

### 9.4 Repository example

```dart
class SamplesRepositoryImpl implements SamplesRepository {
  SamplesRepositoryImpl(this._api, this._cache);
  final SamplesApi _api;
  final SamplesCache _cache;

  @override
  Future<Result<Page<Sample>>> list(SampleFilter f, {int page = 1}) =>
      guard(() async {
        final res = await _api.list(f.toQuery(), page: page);
        final mapped = res.map((dto) => dto.toEntity());
        if (page == 1) await _cache.replace(f.cacheKey, mapped.items);
        return mapped;
      }, fallback: () async => _cache.read(f.cacheKey));   // offline read
}
```

---

## 10. State management

Riverpod with code generation.

| Kind | Provider type | Example |
|---|---|---|
| Singletons | `@Riverpod(keepAlive: true)` | `dio`, `secureStore`, `appRouter`, `authState` |
| Repositories | `@Riverpod(keepAlive: true)` | `samplesRepository` |
| Master data | `@Riverpod(keepAlive: true)` `FutureProvider`, refreshed daily or by pull | `gardens`, `buyers`, `sellers`, `courierServices` |
| Filters | `@riverpod` `Notifier<Filter>` per list | `sampleFilter` |
| Paginated lists | `@riverpod` `AsyncNotifier<PagedState<T>>` watching the filter | `samplesList` |
| Detail | `@riverpod` family `FutureProvider` by id | `sampleDetail(id)` |
| Forms | `@riverpod` `Notifier<FormState>` (autoDispose) | `sampleForm` |

### 10.1 Auth

```dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.authenticated(User user) = Authenticated;
  const factory AuthState.signedOut() = SignedOut;
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<AuthState> build() async {
    final token = await ref.read(secureStoreProvider).readToken();
    if (token == null) return const AuthState.signedOut();
    final me = await ref.read(authRepositoryProvider).me();        // needs /auth/me
    return me.fold((u) => AuthState.authenticated(u),
                   (_) => const AuthState.signedOut());
  }

  Future<AppFailure?> signIn(String email, String password) async { ... }
  Future<void> signOut() async { ... }        // call logout, wipe token + cache
  void onUnauthorized() => state = const AsyncData(AuthState.signedOut());
}
```

### 10.2 Paginated list

```dart
@freezed
class PagedState<T> with _$PagedState<T> {
  const factory PagedState({
    @Default([]) List<T> items,
    @Default(1) int page,
    @Default(true) bool hasMore,
    @Default(false) bool loadingMore,
    AppFailure? loadMoreError,
    @Default(false) bool fromCache,
  }) = _PagedState<T>;
}

@riverpod
class SamplesList extends _$SamplesList {
  @override
  Future<PagedState<Sample>> build() async {
    final filter = ref.watch(sampleFilterProvider);       // refetch on change
    final res = await ref.read(samplesRepositoryProvider).list(filter);
    return res.fold(
      (p) => PagedState(items: p.items, hasMore: p.hasMore),
      (f) => throw f,
    );
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true, loadMoreError: null));
    final res = await ref.read(samplesRepositoryProvider)
        .list(ref.read(sampleFilterProvider), page: s.page + 1);
    state = AsyncData(res.fold(
      (p) => s.copyWith(items: [...s.items, ...p.items], page: s.page + 1,
                        hasMore: p.hasMore, loadingMore: false),
      (f) => s.copyWith(loadingMore: false, loadMoreError: f),
    ));
  }

  Future<void> refresh() async => ref.invalidateSelf();
}
```

### 10.3 Cross-feature refresh

After a create or update, invalidate what it affects. Keep this in one place per feature (`application/invalidation.dart`):

| Action | Invalidate |
|---|---|
| Sample created / edited | `samplesList`, `homeSummary`, `unbatchedSamples` |
| Batch created / auto-batched | `batchesList`, `unbatchedSamples`, `homeSummary` |
| Offer created | `offersList`, `offeredToday`, `homeSummary` |
| Buyers allocated | `offeredToday`, `homeSummary` |
| Bid created / updated | `bidsList`, `bidDetail(id)`, `homeSummary` |
| Sales entry created | `salesList`, `exFactoryList` (reconciliation may change) |
| Ex-factory bill created | `exFactoryList`, `homeSummary` |

---

## 11. Data models

Domain entities use proper Dart types. DTOs mirror the JSON exactly and map to entities.

```dart
enum SampleStatus {
  received, pendingEvaluation, evaluated, assignedToBuyers, approved;

  String get api => switch (this) {
    received => 'received',
    pendingEvaluation => 'pending_evaluation',
    evaluated => 'evaluated',
    assignedToBuyers => 'assigned_to_buyers',
    approved => 'approved',
  };
}

enum BidStatus {
  open('open'), parked('parked'), okBidHold('OK-BID HOLD'), closed('closed');
  const BidStatus(this.api);
  final String api;
}

enum RegisterStatus { matched, priceMismatch, qtyMismatch, unregistered }
enum GstType { igst, cgstSgst }
enum DuplicateAction { override, reoffer, reject }

@freezed
class Sample with _$Sample {
  const factory Sample({
    required int id,
    required DateTime arrivalDate,
    Garden? garden,
    String? grade,
    String? invoicePrefix,
    String? invoiceNo,
    int? packages,
    double? weight,
    double? totalKgs,
    String? sampleType,
    required SampleStatus status,
    String? remarks,
    int? batchId,
  }) = _Sample;
}
```

Money is stored as `Decimal` (package `decimal`) or as integer paise, never `double`, so totals like `271250.00 + 13562.50` never drift. Display with `NumberFormat.currency(locale: 'en_IN', symbol: '₹')`.

Unknown enum values from the server map to an `unknown` case and display the raw string, so a new backend status never crashes the app.

---

## 12. Forms

### 12.1 Behaviour

- Fields are grouped in `AppCard`s with captions. Labels sit above fields.
- Client validation mirrors the server (required fields, `expiry ≥ effective`, tracking number `^[A-Za-z0-9]+$`, ≤ 48 samples), but the server is the source of truth: 422 `errors` map onto fields by key, and any key without a field shows in a banner at the top of the form.
- The first invalid field scrolls into view and is focused.
- The Save button sits above the keyboard (`MediaQuery.viewInsets`). It shows a spinner and ignores taps while submitting.
- Entered values are always kept on error.
- Drafts: create forms autosave to `shared_preferences` every 2 s and offer "Continue your draft?" when reopened.
- Leaving with unsaved changes asks "Discard changes?".
- Keyboard: Next moves to the next field; Done on the last field submits.

### 12.2 2-of-3 weight rule

Used by offer lists (`pkgs`, `nett`, `ttl_kgs`) and samples (`packages`, `weight`, `total_kgs`).

```dart
// core/utils/weight_calc.dart
/// Fills the one field the user didn't touch from the other two.
/// Tracks the last two edited fields so the third is always derived.
class WeightCalc {
  final _order = <WeightField>[];

  WeightValues onEdit(WeightField f, WeightValues v) {
    _order..remove(f)..add(f);
    if (_order.length > 2) _order.removeAt(0);
    if (_order.length < 2) return v;
    final derived = WeightField.values.firstWhere((x) => !_order.contains(x));
    return switch (derived) {
      WeightField.total => v.copyWith(total: _mul(v.pkgs, v.nett)),
      WeightField.nett  => v.copyWith(nett: _div(v.total, v.pkgs)),
      WeightField.pkgs  => v.copyWith(pkgs: _div(v.total, v.nett)),
    };
  }
}
```

The derived field shows a small "Calculated" caption and stays editable.

### 12.3 Duplicate invoice flow

1. Submit without a duplicate flag.
2. If the server answers with a duplicate failure (confirm the exact status and message once live responses are available), open a sheet with the options for that module (offer list: Override / Re-offer / Cancel; sample: Save anyway / Cancel).
3. Resubmit with `duplicate_action` or `is_duplicate: true`.

---

## 13. Loading, empty, error and offline states

| State | List screens | Detail / form screens |
|---|---|---|
| First load | `SkeletonList` with the same row layout | Skeleton cards |
| Refreshing | Pull-to-refresh indicator, content stays | — |
| Loading more | Footer spinner | — |
| Load-more error | Footer "Couldn't load more. Retry" | — |
| Empty (no filters) | `EmptyState`: "Add your first sample" + New sample | — |
| Empty (with filters) | "No samples match these filters" + Clear filters | — |
| Error | `ErrorState` with message + Retry | Same |
| Offline with cache | Cached items + `OfflineBanner` "Showing saved data from 10:42" | Cached detail + banner |
| Offline, no cache | "You're offline" + Retry | Same |
| Submitting | — | Save button spinner, fields stay editable but submit is locked |
| Offline on submit | — | Save disabled, banner "Connect to save. Your entries are kept." |

Offline writes are not queued in v1, because duplicate-invoice handling needs the server's answer. Drafts preserve the user's work instead.

---

## 14. Security

- Token in `flutter_secure_storage` only (Keychain with `first_unlock_this_device`, EncryptedSharedPreferences on Android). Never in prefs, logs or crash reports.
- Sentry `beforeSend` strips `Authorization` headers, email, password and request bodies.
- HTTPS only. Android `network_security_config` disallows cleartext; iOS ATS stays on.
- Sign out wipes the token, the drift cache, drafts and the image cache.
- Release builds use `--obfuscate --split-debug-info`.
- Optional, for later: certificate pinning, and a biometric unlock on resume after 5 minutes in the background (`local_auth`).
- The backend must have `APP_DEBUG=false` before launch (see 18).

---

## 15. Accessibility and localisation

- Tap targets ≥ 48 × 48. Rows ≥ 48 high.
- Every icon-only button has a `Semantics` label / tooltip.
- Status badges carry text, never colour alone.
- Text scales to 200%. Row text stays on one line and truncates with an ellipsis; a long-press tooltip shows the full text, and the `Semantics` label always carries the full text for screen readers.
- Reduce motion: honour `MediaQuery.disableAnimations` (no page-slide, instant transitions).
- Screen-reader order matches visual order. Forms announce errors.
- Strings live in `l10n/app_en.arb` from day one (`flutter_localizations` + `gen-l10n`), so Hindi or Bengali can be added without code changes.
- Numbers and currency use `en_IN` (₹1,23,456.00). Dates display as `17 Oct 2026`.

Note: the design removes visible focus rings by choice. That's fine for touch, but keyboard users on tablets with hardware keyboards lose the indicator. If that matters later, add one subtle focus treatment in the shared field and button components.

---

## 16. Testing

| Level | What | Tools |
|---|---|---|
| Unit | `WeightCalc`, formatters, error mapper, DTO ↔ entity mapping, enum parsing with unknown values | `flutter_test` |
| Repository | Each repository against recorded JSON fixtures (success, 422, 401, HTML-200) | `http_mock_adapter` |
| Controller | List pagination, filter changes, form submit, duplicate flow, invalidation | `ProviderContainer` + overrides, `mocktail` |
| Widget | Every shared component in all states; each form's validation and error mapping | `flutter_test` |
| Golden | Shared components and key screens, light + dark, text scale 1.0 and 2.0 | `matchesGoldenFile` / `alchemist` |
| Integration | Login → create sample → auto-batch → allocate buyers → create bid → sign out, against staging | `integration_test` |

Coverage goal: 80% for `domain`, `application` and `data`; every shared widget has golden tests.

Fixtures live in `test/fixtures/` and are captured from the real API once admin login works.

---

## 17. Environments, build and release

### 17.1 Flavors

| Flavor | API base URL | App id suffix | App name |
|---|---|---|---|
| dev | staging or local | `.dev` | Tea ERP Dev |
| staging | staging host | `.staging` | Tea ERP Beta |
| prod | `https://gold-sardine-283964.hostingersite.com/api/v1` (or the final domain) | — | Tea ERP |

```bash
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
```

```dart
// core/config/env.dart
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const flavor = String.fromEnvironment('FLAVOR');
  static bool get isDev => flavor == 'dev';
}
```

No secrets in the repo. `env/*.json` files hold URLs only.

### 17.2 CI (GitHub Actions or Codemagic)

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs`
3. `dart format --set-exit-if-changed .`
4. `flutter analyze`
5. `flutter test --coverage`
6. Build the staging Android app bundle and iOS IPA, upload to Firebase App Distribution / TestFlight.
7. Tagged release → production build → Play Console internal track / App Store Connect.

### 17.3 App assets

- The logo is built from one vector source and exported to every size with `flutter_launcher_icons` and `flutter_native_splash`.
- App icon: the tea-leaf mark in `#1F5A43` on a neutral light background (`#F0F3F1`), with an adaptive Android icon and an iOS dark-mode variant on `#0A0D0B`. No coloured tile.

### 17.4 Versioning

`pubspec.yaml` `version: 1.0.0+1`. Semantic version for users; build number increments on every CI release.

---

## 18. Backend requirements before launch

Checked signed in as admin on 31 Oct 2026. Full results: `API_DOCS.md` → Verified responses.

### 18.1 Blockers and bugs

| # | Need | State |
|---|---|---|
| 1 | Admin accounts accepted by `POST /auth/login` | ✅ Fixed |
| 2 | `GET /auth/me` | ✅ Exists |
| 3 | `POST /auth/logout` | Exists (not called during testing) |
| 4 | **`GET /sales-register` returns 500** (it tries to insert a record and fails) | ❌ Sales register list unusable |
| 5 | **`GET /sales-register/{id}` and `GET /samples/{id}` return 500** | ❌ The app falls back to the list copy for these two detail screens |
| 6 | `APP_DEBUG=false` in production | ❌ Still on: errors return SQL and class names |
| 7 | JSON 404 for unknown `/api/v1/*` paths | ❌ Still 200 + HTML |

### 18.2 Master data (for pickers)

| Endpoint | State | Used by |
|---|---|---|
| `GET /gardens` | ✅ 2,183 records; the picker searches the server | Offer list, sample |
| `GET /buyers` | ✅ | Courier, sales, contracts, bid book |
| `GET /sellers` | ✅ (Laravel paginator shape) | Contracts, ex-factory |
| `GET /grades` | ✅ 219 records; loaded page by page | Every grade picker |
| `GET /negotiators` | ✅ | Bid book |
| `GET /posting-lists` | ✅ | Courier entry |

### 18.3 Detail, edit and delete

| Module | `GET /{id}` | `PUT /{id}` | `DELETE /{id}` |
|---|---|---|---|
| Offer lists | ✅ | ❌ | ❌ |
| Samples | ✅ | ✅ | ✅ |
| Batches | ✅ | ❌ | ❌ |
| Courier entries | ✅ | ❌ | ❌ |
| Bid book | ✅ | ✅ | ❌ |
| Contracts | ✅ | ❌ | ❌ |
| Sales register | ✅ | ❌ | ❌ |
| Ex-factory | ✅ | ❌ | ❌ |

The app uses every ✅: detail screens load by ID, samples can be edited and deleted, bid book lots can be edited. Still wanted: the ❌ routes (the server decides which records may be deleted, for example not a matched ex-factory bill), plus `POST /batches/{id}/samples` and `DELETE /batches/{id}/samples/{sampleId}` to change an existing batch.

### 18.4 Nice to have

- `GET /dashboard/summary` returning all Home counts in one call (instead of five).
- A consistent duplicate-invoice response (for example `409` with `{"success": false, "code": "duplicate_invoice", "existing_id": 123}`).
- A consistent `401` body with `success: false`.
- A minimum app version in a `GET /app/config` response, for force updates.

---

## 19. Build order

| Phase | Scope | Done when |
|---|---|---|
| 0. Foundation | Project, flavors, lints, CI, tokens, theme, shared components with goldens | Component gallery screen renders in light and dark |
| 1. Shell and auth | Splash, onboarding, login, router with redirects, tab shell, settings, sign out | Sign in, switch tabs, sign out, expired token returns to login |
| 2. Masters and network | Dio, error mapping, pagination, cache, master pickers | Pickers load, search and work offline from cache |
| 3. Samples and batches | List, filters, create/edit, 2-of-3, duplicate flow, batches, auto-batch | Full tasting-room flow works on a device |
| 4. Offers and allocation | Offer lists, duplicate actions, offered-today grid, single and bulk allocation | Allocation flow works end to end |
| 5. Bid book | List with tabs, create/edit, quick status actions | Bids can be created, parked, held and closed |
| 6. Registers | Courier (scanner, photo upload), contracts (items), sales, ex-factory (GST, export) | All four registers create and list correctly; CSV exports and shares |
| 7. Home | Summary, checklist, recent activity, quick actions | Every number matches the backend |
| 8. Hardening | Offline states, accessibility pass at 200% text, Sentry, integration tests, performance (list jank-free on a mid-range Android) | All tests green; release candidate on TestFlight and the Play internal track |

Each phase ends with a demo build on staging.
