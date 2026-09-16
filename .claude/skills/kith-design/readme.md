# Kith Design System

Kith is a private, invite-only network for a few dozen friends: your own private blog with photos, plus a reader for your friends' blogs. There is no public timeline, no reposts, no likes and no algorithm — forty people who already know each other. The reference points are Feedbin, Bear and early Path, not Instagram or Facebook. Opening Kith should feel like opening a letter.

This design system exists so that anything built for Kith — a screen, a marketing page, a slide — comes out quiet, text-first and unmistakably the same product.

## Sources

There was no codebase, Figma file or existing product to read. Everything here was derived from a written brief supplied by the user on 16 September 2026, covering feel, type direction, constraints, the eight screens and the component sheet. Two consequences:

- **No logo or brand mark was provided, and none has been invented.** Wherever a mark would go, the word "Kith" is set in Literata 600.
- **No icon set was provided.** Lucide is substituted at 1.5px stroke. Flagged below under Iconography.

Implementation constraints from the brief, which shaped every decision here: Tailwind utilities plus Hotwire (Turbo Frames/Streams, small Stimulus controllers); no fonts beyond two Google Fonts; no complex animation and no gesture-driven UI; server-rendered, so every state is discrete and loading is Turbo's default rather than a skeleton. The token sheet deliberately stays inside Tailwind's default scales.

## In this repository

The system is implemented, not just documented. `app/assets/tailwind/application.css` holds `tokens/colors.css` verbatim plus a `@theme inline` block mapping the semantic tokens onto Tailwind colour names, and the shared classes below. The remaining token files restate Tailwind's own default scales, so they are reached through utilities rather than copied.

| Design system | In the app |
| --- | --- |
| `--bg` / `--bg-sunken` / `--surface` | `bg-paper` / `bg-sunken` / `bg-surface` |
| `--hairline` / `--hairline-strong` | `border-rule` / `border-rule-strong` |
| `--text-title` / `--text-body` / `--text-secondary` / `--text-meta` / `--text-faint` | `text-title` / `text-ink` / `text-quiet` / `text-meta` / `text-hush` |
| `--accent` and its steps | `text-accent`, `bg-accent`, `hover:bg-accent-hover`, `active:bg-accent-press`, `bg-accent-quiet` |
| `--shell-max` (672px column) | `max-w-2xl` |
| 2px / 4px / 6px radii | `rounded-xs` / `rounded-sm` / `rounded-md` |
| `--tap-min` | `min-h-tap` |
| `Button` primary / secondary / quiet | `.btn` / `.btn-quiet` / `.btn-plain`, with `.btn-sm` for desktop list rows |
| `Field` | `.field`, `.field-serif`, `.label`, `.hint`, `.error` |
| `RadioGroup` | `.choice`, `.choice-label`, `.choice-note`, `.radio` |
| `Avatar` | `.avatar` plus a size utility |
| `UnreadDot` | `.unread-dot` |
| `Pill` | `.pill` |
| `Comment` | `.comment-body` |
| post title / post body | `.post-title` / `.prose-kith` |
| micro-label | `.micro` |

Two deliberate deviations from the system's own sheets: the base stylesheet's global `a { border-bottom }` is not carried over (right for a specimen card, wrong for a nav bar — links are styled where they are used and in `.prose-kith`), and dark is applied by `prefers-color-scheme` with `[data-theme]` on `<html>` as an override, rather than only by a `.dark` class.

## Components

Ten primitives, plus two intentional additions.

- **`Button`** — primary / secondary / quiet, two sizes, disabled, full-width. The only button in the system.
- **`FollowButton`** — one control, five server states: Follow, Requested, Following, Follow back, Connected.
- **`Avatar`** — five fixed sizes (20 / 24 / 32 / 40 / 64) with initials fallback.
- **`UnreadDot`** — the 6px terracotta dot; fades in place so marking read never reflows text.
- **`Pill`** — the floating "N new" affordance. It is the only element in the system with a shadow.
- **`PhotoGrid`** — 1 / 2–4 / 5+ layouts, picked by count, with `+N` on the sixth tile.
- **`Comment`** — one flat comment, with the gated-profile-link rule baked into a `linked` prop.
- **`Field`** — every form control: input, textarea, select, plus a serif mode for the composer.
- **`RadioGroup`** — exclusive choice where each option carries its consequence in a sentence. Used by the audience selector and the discoverability setting.
- **`Annotation`** — terracotta leader line, used to document rules on kit screens. Documentation only.

Deliberately absent: Toast, Tabs, Modal, Tooltip, Switch, Badge, Card. Kith is server-rendered with discrete states and has nothing to put in them.

## Content fundamentals

**Register.** Plain, second person, present tense. Kith describes what will happen and stops. It never sells, congratulates, or apologises effusively.

**Person.** "You" for the reader, always. Kith itself is almost never the subject — prefer "This link works until 23 September" over "We'll keep this link active until 23 September". First-person plural appears only where the operator genuinely has to be the actor: "We don't email you about activity."

**Casing.** Sentence case everywhere: buttons ("Follow back", "Create an invite link"), headings, nav. The single exception is micro-labels — 12px Barlow, uppercase, +0.06em tracking: `DISPLAY NAME`, `AUDIENCE`, `PHOTOS`, `POSTS`, `3 COMMENTS`.

**Consequences, stated in full.** Any control that changes who can see someone's life carries a one-sentence explanation, every time it appears, never abbreviated and never hidden in a tooltip:

- "Anyone on the internet, and other servers can keep copies." (Public audience — verbatim, in the composer and anywhere else the option appears.)
- "The people you've accepted. They can comment." (Followers audience.)
- "Accepting lets someone read your followers-only posts. It doesn't make you follow them."
- "People you're connected to can find you. To everyone else your name isn't a link and your posts aren't listed."

**Numbers and time.** Relative and lowercase: "4h", "yesterday", "2d", then absolute dates in full on permalinks ("16 September 2026"). Counts are bare: "3 new", "3 comments", "Two invites left."

**Empty states are warm, not sad and not motivational.** "Nothing here yet. / Kith fills up one person at a time. Follow someone you already know, or send an invite to someone who isn't here."

**Never.** No emoji, anywhere. No exclamation marks. No "Oops!", no "Something went wrong", no "You're all set". No growth language — no audience, reach, engagement, followers-as-metric, streaks, or "people you may know". No hedging modals; declining a follow request just removes the row.

## Visual foundations

**Colour.** Warm neutrals and one accent. The light theme sits on paper (`--warm-50` #faf9f6), not white; `#ffffff` appears only on raised controls — inputs, the "N new" pill. Ink runs four levels deep (`--text-title` → `--text-body` → `--text-secondary` → `--text-meta`), with `--text-faint` for the few things allowed to recede. The dark theme is authored independently on a warm near-black (`--night-800` #171614) with its own accent step (`--clay-400` #e08a5f, 6.9:1 on the ground) — it is not a filter, an inversion, or a derived palette.

Terracotta (`--clay-500` #b3542f, 4.7:1 on paper) is permitted in exactly four places: the unread dot, the one primary action on a screen, links in prose, and the focus ring. Not headings, not rules, not backgrounds, not section labels. A list of three requests gets three outlined Accept buttons rather than three filled ones — filled accent in a repeated row breaks the rule about sparing use.

**Type.** Literata for everything read (post titles 24/32 semibold, bodies 18px at 1.7, excerpts 16px at 1.65, comments) and Barlow for everything operated (labels, buttons, meta, nav, form chrome). The split is functional, not decorative: if it is content, it is serif; if it is chrome, it is sans. Body measure is capped at 65ch, excerpts and comments at 52ch. The scale is Tailwind's default ramp, untouched. Post titles carry −0.005em to −0.01em tracking; nothing else is tracked except the uppercase micro-labels at +0.06em.

**Spacing and layout.** Tailwind's 0.25rem step, eleven values in use. 20px gutters at 390px, 32px at 1024px, 40px between reader posts, 2px between photos in a grid. At 1024 the layout is a 208px text side rail and a 672px reading column — no third column, no right sidebar, and the column does not centre on the viewport; it sits next to the rail so the eye lands in the same place at both breakpoints. The bottom nav on mobile and the top bar are the only fixed elements; the "N new" pill is sticky within the scroll area.

**Backgrounds.** Flat colour. No gradients, no textures, no patterns, no full-bleed hero imagery, no illustration. The only large visual element in the product is the user's own photography, which is why nothing else competes for it.

**Cards, borders, shadows.** There are no cards. Separation is whitespace first and a 1px hairline second (`--hairline` for in-content dividers, `--hairline-strong` for control borders). There is no shadow system: `--shadow-pill` is the single elevation in the product, and it exists only because the "N new" pill floats over moving text. Avatars use an inset hairline rather than a border so the circle never grows.

**Corner radii.** 2px on photo tiles inside a grid, 4px on buttons, inputs and the outer photo block, 6px on the composer tray, full round on avatars, pills and dots. Nothing is rounder than 6px except circles.

**Transparency and blur.** Essentially unused. No frosted bars, no backdrop blur, no translucent overlays — the one exception is the 55% ink scrim behind a `+N` count on a photo tile, and the same scrim behind the composer's per-photo remove button, where the control has to sit on an unknown image.

**Imagery.** No stock photography and no illustration ships with this system; the imagery is the members' own. Photo placeholders are flat warm tones (`#e9e2d6`–`#d3ccc0`) with the word PHOTO set in 12px uppercase Barlow. Photos are never circular, never captioned in chrome, never shadowed.

**Motion.** Colour and opacity only, 120ms on interactive feedback, 400ms on the unread dot fading out. No transforms, no bounce, no spring, no entrance animation, no skeletons — server-rendered states arrive whole, and Turbo's own loading behaviour is the loading state.

**Hover.** Controls warm rather than darken: secondary and quiet buttons take a `--surface-hover` tint and quiet buttons step their text up to full body ink. Primary buttons step the accent one stop darker (`--accent-hover`). `FollowButton` in the Following state swaps its label to "Unfollow" without changing colour. **Press** steps the accent one further stop (`--accent-press`); nothing scales, shrinks or lifts. **Focus** is a 2px accent outline at 2px offset, never removed.

**Tap targets.** 44px minimum (`--tap-min`) for every interactive element on mobile. The 32px small size exists for desktop list rows only.

## Iconography

Icons are chrome, not content. They appear in the top bar, the bottom nav, the side rail and the composer tray, and nowhere else: never inside prose, never as a list bullet, never coloured with the accent, never as a decorative device on an empty state.

- **Set:** Lucide. **This is a substitution** — the brief supplied no icon set, and Lucide's 1.5px open stroke is the closest match to the quiet, text-first register.
- **Spec:** 20px box, 1.5px stroke, `currentColor`, rounded caps. 16px for the rail's settings glyph and the invite-link glyph.
- **In use:** `square-pen` compose, `bell` notifications, `users` requests, `user-round` profile, `book-open` reader, `settings`, `arrow-left` back, `image-plus` add photo, `grip-vertical` reorder, `x` remove, `link` invite link, `check` accepted, `eye-off` invisible.
- **No emoji, ever** — not in UI, not in copy, not as a fallback glyph. No unicode characters pressed into service as icons either, with two exceptions inside the composer's photo tray (← →, for keyboard-accessible reorder) and the back affordance at 1024 ("← Back").
- **No icon font and no sprite sheet.** Lucide renders inline SVG so it inherits colour from the surrounding text.

## Type and colour rationale

*For the implementer who has to extend this.*

The type choice follows from the product being a reader, not a feed. Literata was designed for long-form screen reading — a large x-height, sturdy low-contrast strokes and generous spacing that hold up at 18px on a phone in bad light — and it is a Google Font, which the build constraints require. It carries everything a member wrote: titles, bodies, excerpts, comments, and the composer's own fields, so writing a post looks like the post it becomes. Barlow takes everything the member did not write: labels, buttons, timestamps, nav. That division is the rule to extend by — if you are adding something a person typed, it is Literata; if you are adding a control, it is Barlow. Both stay on Tailwind's default size ramp so new screens can't drift, and the 65ch measure is the hard constraint that keeps a 1024px layout from becoming a dashboard.

The colour choice follows from photographs being the only saturated thing on screen. A warm paper ground (#faf9f6 rather than #ffffff) sits closer to the temperature of skin, food and evening light than a cool grey would, so photos read as part of the page instead of pasted onto it; the same logic gives the dark theme a warm near-black rather than a blue-black. One accent, terracotta, is warm enough to belong to that family and saturated enough to be the only thing your eye finds when it scans — which is the whole job, since it means unread and it means the one action worth taking. It was checked for contrast in both themes (4.7:1 on paper, 6.9:1 at #e08a5f on the dark ground) so it can be used as text, not just as a dot. To extend: add ink levels or hairline steps within the warm ramp freely, but do not add a second hue. If something needs to be distinguished, distinguish it with whitespace, a hairline, or weight — a green "success" and a red "destructive" would make the unread dot mean nothing.
