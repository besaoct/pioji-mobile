# Agent handbook

Everything an agent (or a new developer) needs to build on this app. Read this file first, then the ones it points to.

| File | What it is | Read it when |
|---|---|---|
| [docs/API_DOCS.md](docs/API_DOCS.md) | Every backend endpoint: fields, examples, verified behaviour, backend issues | Touching any data layer or form |
| [docs/FLUTTER_IMPLEMENTATION.md](docs/FLUTTER_IMPLEMENTATION.md) | The product and technical spec: screens, UX, routing, state, errors, testing, release | Building or changing any screen |
| [design/DESIGN_SYSTEM.md](design/DESIGN_SYSTEM.md) | The approved look: palette 9 "Assam green iOS", type, spacing, the hard style rules | Any UI work |
| [design/ui-reference/](design/ui-reference/) | The approved screen mockups (HTML artboards) | Building a screen that has a mockup |
| [CONVENTIONS.md](CONVENTIONS.md) | How the code is organised and how to add a module | Before writing code |
| [STATUS.md](STATUS.md) | What is built, what is verified, what is blocked | Before planning work |

## Ground rules

1. **The design is approved. Don't restyle.** Colours, radii and shadows come only from `lib/core/design/tokens.dart`. If a change is needed, preview it to the user before writing code.
2. **Never invent API shapes.** Responses are not verified yet (see STATUS.md). Parse through `J` helpers in `lib/core/utils/json.dart`, which tolerate both flat and nested shapes.
3. **No GET bodies.** The host firewall returns 403. Filters go in query parameters (`Api.page` / `Api.getData` already do this).
4. **One shared list screen.** New lists use `ModuleListScreen` with a `pagedProvider`; don't hand-roll pagination.
5. **Every form uses the `FormSubmit` mixin** so double submits, 422 field errors, offline and duplicate invoices behave the same everywhere.
6. **Text never wraps in rows.** Use `OneLineText` (ellipsis + long-press tooltip) or `FitText` (scale down) for numbers.
7. **No hover, focus, ripple or press effects.** The theme turns them off; don't add them back.
8. Run `flutter analyze` before you finish. It must report no issues.
