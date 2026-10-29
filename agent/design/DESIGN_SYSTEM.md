# Design system — palette 9 "Assam green iOS"

Approved by the user on 29 Oct 2026. Source of truth in code: `lib/core/design/tokens.dart`, `typography.dart`, `theme.dart`.

## Colours

| Token | Light | Dark | Use |
|---|---|---|---|
| background | `#F0F3F1` | `#0A0D0B` | Screen background |
| surface | `#FFFFFF` | `#181D1A` | Cards, grouped lists |
| surfaceRaised | `#FFFFFF` | `#222824` | Sheets, dialogs |
| fill | `#768079` @ 12% | `#3A423D` | Segmented track, search field |
| textPrimary | `#121815` | `#EEF3F0` | Titles, values |
| textSecondary | `#4F5853` | `#ABB5AF` | Body |
| textTertiary | `#6B756F` | `#87918B` | Labels, metadata |
| separator | `#E2E7E4` | `#28302C` | Hairlines inside a card only |
| accent | `#1F5A43` | `#4FB487` | Accent text and icons |
| accentFill | `#1F5A43` | `#237A57` | Primary buttons (white text passes AA) |
| accentTint | accent @ 8% | accent @ 14% | Selected tile / row |
| success | `#2E7D4F` | `#4CC27F` | Matched, received, delivered |
| warning | `#9A6200` | `#E5B040` | Mismatch, pending, unallocated |
| danger | `#B3261E` | `#FF6B60` | Errors, unregistered, sign out |
| barDeep | `#C9D3CD` | `#000000` | Bottom edge of the tab bar shadow |

## Shape and depth

- **Cards have no border.** They stand out by tone (surface on background) plus a two-layer shadow in light mode only (`0 1 2 @4%`, `0 6 16 @3.5%`). Dark mode: no shadow.
- **Smooth iOS corners** everywhere via `RoundedSuperellipseBorder`: control 11, card 14, sheet 20, tile 7–8.
- Rows inside one card are split by 0.5 px hairlines inset to the text edge (iOS Settings style).
- No blur, no frosted glass, no gradients except the tab bar.

## Typography

System font only (SF on iOS, Roboto on Android). No monospace, even for invoice and tracking numbers. Two working weights: 400 and 600 (500 for row titles). Large title 30, title 20, headline 17, body 16, callout 15, footnote 13, caption 12, tab label 11. Selected states change colour, never weight or size.

## Hard rules (user preferences)

1. No hover, focus ring, ripple or press effects on any control. Keep only selected, disabled, invalid, loading.
2. Text in rows never wraps: one line + ellipsis + long-press tooltip; short numbers may scale down.
3. Tab bar: 5 tabs (Samples, Offers, **Home in the centre, selected on launch**, Bids, More), all the same size. No top line, no blur. One gradient: transparent at the top of a 60 px fade, solid by the icons, deepening to `barDeep` at the bottom edge. Inactive icon tiles have no background.
4. Primary buttons are deep fills with white text in both themes; destructive buttons are deep red with white text.
5. Selected backgrounds are a subtle accent tint, never a heavy fill.
6. The logo is the two-leaf mark in the accent colour, never on a coloured tile. App icons sit on the neutral background (`#F0F3F1` light, `#0A0D0B` dark). Sources: `assets/icon/*.svg`.
7. Content fills the width; one 16 px screen gutter.
8. Touch targets ≥ 44 pt / 48 dp.
9. Copy: sentence case, verbs first, no "successfully", no "please", no exclamation marks.

## Mockups

`ui-reference/*.dc.html` are the approved screens (390×844), with `canvas.json` listing them. Read them as markup for layout, spacing and copy; they are reference designs, not code to port.
