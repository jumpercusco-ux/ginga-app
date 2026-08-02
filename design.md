# design.md

Design system reference for Ginga App. Always use these tokens — never hardcode values.

## Colors

| Token | Hex | Usage |
|-------|-----|-------|
| brandGreen | #388E3C | CTAs, active icons, badges, borders |
| accentAmber | #FBC02D | Events, special highlights, roda badge |
| backgroundLight | #F5F7F5 | All screen backgrounds |
| backgroundDark | #1B1F1C | Splash, onboarding only |
| surfaceDark | #2A312A | Dark cards |
| accentGreenDark | #4CAF50 | Secondary green |
| cardLight | #EEF4EE | Cards, chips, secondary backgrounds |
| textPrimary | #1A1A1A | Titles, important text |
| textSecondary | #6B7B6B | Subtitles, descriptions |
| borderLight | #E0E8E0 | Dividers, card borders |

## Typography

- **Montserrat** — headers, buttons, labels, badges
  - w600 subtitles
  - w700 labels and buttons
  - w800 main titles
- **Nunito** — body text, descriptions, hints
  - regular body
  - w600 semi-bold descriptions

## Spacing (GingaSpacing)

| Token | Value |
|-------|-------|
| xs | 4px |
| sm | 8px |
| md | 16px |
| lg | 24px |
| xl | 32px |
| xxl | 48px |

Horizontal screen padding: 20px
Gap between sections: 20-28px
Gap between cards: 10-12px

## Border Radius (GingaRadius)

| Token | Value | Usage |
|-------|-------|-------|
| sm | 8px | Small icons, tags |
| md | 12px | Inputs, chips |
| lg | 16px | Main cards |
| xl | 24px | Large containers |
| full | 100px | Pill buttons, badges |

## Rules

- Always light mode — no dark mode for student screens
- Never use a green other than #388E3C
- Never hardcode colors, spacing or radius — use tokens
- Only Montserrat and Nunito — no other fonts
- All screens: fondo #F5F7F5, padding horizontal 20px

## Reusable Components

**StatusBanner** — top banner driven by user status
- nuevo: green #388E3C
- prueba: amber #FBC02D
- inactivo: red

**ClaseCard** — class card with hora, nivel, badge, button
- Available: green border, "Reservar" button
- Reserved: green light bg, "✓ Reservado"
- Locked: grey, disabled

**LeccionCard** — lesson card with 3 states
- Completada: green check, strikethrough text
- Disponible: green border, play button
- Bloqueada: grey, lock icon, opacity 0.6

**BottomNav** — 4 tabs fixed
- Home / A Roda / Biblioteca / Perfil
- Active: brandGreen
- Inactive: textSecondary

**Avatar** — circle with user initial
- Background: cardLight #EEF4EE
- Text: brandGreen, Montserrat w700

**Badge/Chip** — small colored label
- Green variant: bg #EEF4EE, text #388E3C
- Amber variant: bg #FBC02D22, text #BA7517
- Grey variant: bg borderLight, text textSecondary

## Assets

Located in `assets/images/`:
- `logo_ginga.png` — official green G logo (use in Login, Splash, Onboarding)
- `dani.jpg` — Prof. Daniel photo (workshop banner)
- `roda.jpg` — Roda de Sábado photo (news card)
- `moves.jpg` — movements photo (news card)

## Screen Inventory

| Screen | File | Status |
|--------|------|--------|
| Splash | splash_screen.dart | ✅ v1 |
| Onboarding | onboarding_screen.dart | 🔄 redesign v2 |
| Login | login_screen.dart | 🔄 redesign v2 |
| Crear Perfil | profile_creation_screen.dart | 🔄 redesign v2 |
| Home — 4 estados | home_screen.dart | 🔄 redesign v2 |
| Eventos | eventos_screen.dart | 🔄 redesign v2 |
| Detalle Evento | evento_detalle_screen.dart | 🔄 redesign v2 |
| Biblioteca | biblioteca_screen.dart | 🔄 redesign v2 |
| Tutorial Detalle | tutor_detail_screen.dart | 🔄 redesign v2 |
| Practicar Toque | practicar_toque_screen.dart | 🔄 redesign v2 |
| Perfil | progreso_screen.dart | 🔄 redesign v2 |
| Mi Progreso | mi_progreso_screen.dart | 🔄 redesign v2 |
| QR Scanner | qr_scanner_screen.dart | ✅ v1 |
| QR Generator | qr_generator_screen.dart | ✅ v1 |
| Vista Instructor | instructor_clase_screen.dart | ✅ v1 |
| Subir Comprobante | — | ⏳ pendiente v2 |
| Mis Reservas | — | ⏳ pendiente v2 |
| Editar Perfil | — | ⏳ pendiente v2 |