---
name: Neo-Brutalist Integrity Engine
colors:
  surface: '#fcf9f8'
  surface-dim: '#dcd9d9'
  surface-bright: '#fcf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f0edec'
  surface-container-high: '#ebe7e7'
  surface-container-highest: '#e5e2e1'
  on-surface: '#1c1b1b'
  on-surface-variant: '#4c4735'
  inverse-surface: '#313030'
  inverse-on-surface: '#f3f0ef'
  outline: '#7e7763'
  outline-variant: '#cfc6af'
  surface-tint: '#705d00'
  primary: '#705d00'
  on-primary: '#ffffff'
  primary-container: '#ffde59'
  on-primary-container: '#756100'
  inverse-primary: '#e4c542'
  secondary: '#b32053'
  on-secondary: '#ffffff'
  secondary-container: '#fe5b89'
  on-secondary-container: '#620027'
  tertiary: '#6d48b5'
  on-tertiary: '#ffffff'
  tertiary-container: '#e8d9ff'
  on-tertiary-container: '#714dba'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffe16e'
  primary-fixed-dim: '#e4c542'
  on-primary-fixed: '#221b00'
  on-primary-fixed-variant: '#544600'
  secondary-fixed: '#ffd9df'
  secondary-fixed-dim: '#ffb1c0'
  on-secondary-fixed: '#3f0017'
  on-secondary-fixed-variant: '#90003d'
  tertiary-fixed: '#eaddff'
  tertiary-fixed-dim: '#d2bbff'
  on-tertiary-fixed: '#25005a'
  on-tertiary-fixed-variant: '#542e9c'
  background: '#fcf9f8'
  on-background: '#1c1b1b'
  surface-variant: '#e5e2e1'
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: 0.02em
  headline-xl-mobile:
    fontFamily: Space Grotesk
    fontSize: 28px
    fontWeight: '800'
    lineHeight: 32px
    letterSpacing: 0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 28px
    letterSpacing: 0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 20px
    fontWeight: '800'
    lineHeight: 24px
    letterSpacing: 0.01em
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 16px
    fontWeight: '800'
    lineHeight: 20px
    letterSpacing: 0.01em
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 22px
  body-sm:
    fontFamily: Hanken Grotesk
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  code-lg:
    fontFamily: Space Mono
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 24px
  code-md:
    fontFamily: Space Mono
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 18px
  code-sm:
    fontFamily: Space Mono
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
  label-caps:
    fontFamily: Space Grotesk
    fontSize: 12px
    fontWeight: '800'
    lineHeight: 14px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style
This design system establishes a high-accountability, neo-brutalist aesthetic tailored for high-stakes online examinations. It rejects sanitized, corporate dashboard tropes in favor of an unmistakable, tactile language: raw structural lines, hyper-legible mechanical typography, and unyielding contrasts. 

The personality is authoritative, uncompromising, and punchy. It instills confidence in proctors while keeping students alert, clear-headed, and oriented. High-contrast hard shadows, thick structural frames, and vibrant flat fills ground the interface in physical reliability—treating digital integrity verification with the finality of physical print and physical security hardware.

## Colors
The palette leverages a warm cream base (`#FFF4E0`) to cut screen glare while avoiding the sterile coldness of clinical white. Pure structural definition is handled strictly by hard ink (`#0D0D0D`) used for all borders, drop shadows, and high-emphasis labels.

- **Primary (`#FFDE59`):** Vibrant yellow reserved for core focal actions, current active questions, and main navigation CTA anchors.
- **Secondary (`#FF5C8A`):** Bright hot pink for destructive confirmations, critical alert badges, and high-urgency triggers.
- **Tertiary / Accent (`#B28DFF`):** Lavender purple dedicated to proctoring controls, biometric status, and secondary functional grouping.
- **Surface (`#FFFFFF`):** High-clarity white for active cards, answer inputs, and modal canvases.
- **Status Accents:** `#5CA8FF` (Info / System), `#5CE08A` (Verification Success / Encrypted), `#FF4D4D` (Violation Warning / Termination), and `#D9D2C3` (Muted / Disabled / Inactive states).

## Typography
Typographic hierarchy is bifurcated into brutalist command elements and friction-free reading surfaces:

1. **Headlines (`Space Grotesk`):** Forced uppercase (`text-transform: uppercase`), weight 800. These anchors behave as physical signage across screen sections.
2. **Body Copy (`Hanken Grotesk`):** Clean, crisp grotesque delivering immediate readability for complex examination questions and long instructional prompts.
3. **Data & Verification Engine (`Space Mono`):** Reserved for technical truths—live exam timers, blockchain audit hashes, question ID indices, seated desk numbers, and seat authorization tokens.

## Layout & Spacing
The layout operates on a mobile-first 4-column dynamic grid, constrained to a maximum content width of 480px on handheld screens, with strict 16px (`1rem`) outer margins.

- **Stack Rhythm:** Cards and content blocks stack vertically with 12px or 16px gaps to account for the physical footprint of hard drop-shadows. 
- **Overflow & Collision:** Component spacing must budget an extra 6px on the right and bottom boundaries to accommodate raw offset shadows without triggering horizontal viewport clipping.
- **Header & Dock Anchors:** The sticky top proctor bar and bottom interaction bar use a rigid 3px bottom/top border and sit pinned to avoid layout recalculation during active input.

## Elevation & Depth
This design system avoids blurry elevation, ambient glows, diffusion, and skeuomorphic gradients entirely. Depth is mechanical and binary.

- **Base Elevation:** `box-shadow: 6px 6px 0px #0D0D0D`. Every primary surface, card, and floating badge extrudes at a fixed 45-degree angle downward-right.
- **Structural Stroke:** Every elevated element must be framed with a `3px solid #0D0D0D` stroke.
- **Active / Pressed State:** All interactive elevated components drop their shadow to `2px 2px 0px #0D0D0D` while simultaneously executing `transform: translate(4px, 4px)`. This physical "click down" mechanical response gives immediate feedback.
- **Static Overlay Depth:** Fixed modals and critical warnings employ an expanded `8px 8px 0px #0D0D0D` offset with an un-blurred `#0D0D0D` overlay at 60% opacity.

## Shapes
A unified radius of 12px (`0.75rem`) applies across all core surfaces: cards, modals, buttons, and input fields. This softened brutalist profile prevents corner pinching when hard 3px black borders meet the 6px offset drop shadow.

- **Badges & Chips:** Use a condensed radius of 8px or pill radius with identical 3px borders.
- **Sticker Tilt:** Key security indicators, question status flags, and badge counters apply an intentional `-2deg` or `+2deg` rotation (`transform: rotate(-2deg)`) to create a hand-placed inspection sticker aesthetic.

## Components

### Buttons
- **Primary:** Background `#FFDE59`, color `#0D0D0D`, border `3px solid #0D0D0D`, border-radius `12px`, shadow `6px 6px 0px #0D0D0D`, font `Space Grotesk` 800 uppercase.
- **Secondary / Action:** Background `#FF5C8A` or `#B28DFF`, identical border and shadow treatment.
- **Interaction:** On active/press, apply `transform: translate(4px, 4px)` and `box-shadow: 2px 2px 0px #0D0D0D`. Disabled buttons take `#D9D2C3` background, `#0D0D0D` border, and `0px 0px` flat shadow.

### Neo-Cards
- Background `#FFFFFF`, border `3px solid #0D0D0D`, radius `12px`, shadow `6px 6px 0px #0D0D0D`.
- Question and integrity cards feature an internal header strip bounded by a `3px solid #0D0D0D` bottom rule with contrasting background fills (`#FFF4E0` or `#FFDE59`).

### Badges & Sticker Flags
- Compact containers with `3px solid #0D0D0D`, 8px radius, and `3px 3px 0px #0D0D0D` shadow.
- High-priority indicators (e.g., "LIVE PROCTOR", "FLAGGED") feature a `-2deg` rotation, uppercase font, and bold letter spacing.

### Form Inputs & Radio / Checkbox Selectors
- **Input Fields:** `#FFFFFF` background, `3px solid #0D0D0D`, 12px radius, `Space Mono` text for codes/answers. Focused state transitions background to `#FFF4E0` with a sharp `4px 4px 0px #0D0D0D` shadow.
- **Option Selectors:** Radio buttons and checkboxes appear as standalone mini neo-cards (`#FFFFFF`, `3px solid #0D0D0D`, 12px radius). When selected, fill flips to `#FFDE59` with an internal checked block stamped in `#0D0D0D`.

### TimeZone & Currency Chips
- Compact modular metadata pills. Background `#FFFFFF` or `#D9D2C3`, framed with `2px solid #0D0D0D` or `3px solid #0D0D0D`, `Space Mono` 700 text, paired with micro-icons (e.g., UTC clock or currency symbol) separated by a vertical black hairline stroke.