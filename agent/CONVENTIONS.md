# Code conventions

## Stack

Flutter 3.44 (stable) · Dart 3.12 · `flutter_riverpod` 3 · `go_router` 18 · `dio` 5. No code generation: models are hand-written with tolerant `fromJson`, and providers are declared directly. (`freezed` 3 and `riverpod_generator` 4 need different `analyzer` versions, so code-gen was dropped. Revisit when they align.)

## Layout

```
lib/
├── main.dart                 ProviderScope, prefs, 401 handler, retry off
├── app.dart                  MaterialApp.router, light/dark themes
├── core/
│   ├── config/env.dart       API_BASE_URL, FLAVOR via --dart-define
│   ├── design/               tokens, typography, theme, context.colors
│   ├── errors/               sealed AppFailure
│   ├── network/              dio + interceptor, Api helpers, Page parser, error mapper
│   ├── list/                 ListQuery (search + params) and PagedNotifier
│   ├── storage/              secure token store, shared prefs, theme + onboarding flags
│   ├── connectivity/         isOnlineProvider
│   ├── router/               routes, app_router (redirects + tab shell), shell_scaffold (tab bar)
│   ├── application/          cross-feature refresh tick for Home
│   ├── utils/                json readers, formatters, weight 2-of-3, debouncer
│   └── widgets/              every shared component (cards, rows, fields, sheets, states, scaffolds, module list)
└── features/<module>/
    ├── data/                 model(s) + repository + providers
    ├── domain/               (only when a model is shared, e.g. samples, auth)
    ├── application/          (only when there is real logic, e.g. auth, home)
    └── presentation/         screens
```

A feature may import another feature's `data/` (to invalidate its list or reuse a model) but never its `presentation/`, except for shared row widgets such as `SampleRow`.

## Adding a module

1. `features/x/data/x_repository.dart`: model with `fromJson` via `J`, a repository using `Api`, then
   ```dart
   final xQueryProvider = ListQueryProvider(ListQueryNotifier.new);
   final xListProvider = pagedProvider<X>(xQueryProvider, (ref, q, page) => ref.read(xRepositoryProvider).list(q, page: page));
   ```
2. List screen: `ModuleListScreen<X>` with `segments` (status param), `filters` (`DateFilter`, `ChoiceFilter`) and an `itemBuilder` returning `AppListRow` (or a card with `asCards: true`).
3. Form screen: `ConsumerStatefulWidget` + `with FormSubmit`, wrapped in `FormScaffold`, fields in `GroupedSection`s, errors from `err('api_field_name')`. After success: invalidate the list, `refreshSummaries(ref)`, toast, pop.
4. Detail screen: receives the model through go_router `extra` (the API has no single-record endpoints yet) and falls back to `MissingItemScreen`.
5. Routes: add names to `core/router/routes.dart` and entries in `app_router.dart`. Forms use `_top(...)` so they cover the tab bar.

## Style

- No hex values or magic paddings in features: use `context.colors`, `AppSpace`, `AppRadius`, `AppText`.
- Money as `Fmt.money` (₹, en_IN grouping), weights as `Fmt.kg`, dates shown with `Fmt.day` and sent with `Fmt.api`.
- User-facing copy: sentence case, short, no "successfully" or "please".
- Keep `flutter analyze` at zero issues.

## Commands

```bash
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=https://gold-sardine-283964.hostingersite.com/api/v1
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
