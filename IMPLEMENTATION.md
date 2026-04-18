# LizardNotes — Implementation Guide

This document is the source of truth for implementing LizardNotes across Web, Mobile, and Desktop. It pairs with the interactive prototypes:

- `LizardNotes.html` — desktop app (three-column shell, editor, dialogs, search, attachment overlay)
- `Auth.html` — all seven auth screens
- `Mobile.html` — Android navigation stack (folder list, note list + bottom sheet, editor + keyboard)

---

## 1. Design principles

1. **Dark and minimal.** Obsidian-inspired dark theme. No gradients, no shadows except on modals and the Tweaks panel. Borders do the layering.
2. **Accent used sparingly.** Purple `--ln-accent` only on active rows, primary buttons, focused inputs, and active toolbar buttons. Never as a decorative fill on large surfaces.
3. **Adaptive layout.** Three persistent columns on desktop, linear navigation stack on mobile.
4. **Folders are central.** The folder tree is always accessible on desktop and is the root of the mobile nav stack.
5. **WYSIWYG editing.** No raw markdown is rendered to the user. Format is applied live; a floating toolbar appears on text selection (desktop) or is docked above the keyboard (mobile).

---

## 2. Design tokens

Defined in `styles.css` as CSS custom properties. **Never hardcode hex values in components.** Flutter implementation should mirror these as a `LizardTheme` data class.

### Surfaces
| Token | Value | Usage |
|---|---|---|
| `--ln-bg` | `#1a1a1a` | App background, editor |
| `--ln-surface` | `#222222` | Sidebar, note list, attachment bar, bottom nav |
| `--ln-surface2` | `#2a2a2a` | Inputs, cards, chips, modals |
| `--ln-surface3` | `#303030` | Hover states, code blocks, context menus |

### Borders
| Token | Value | Usage |
|---|---|---|
| `--ln-border` | `rgba(255,255,255,0.08)` | Subtle dividers between columns and sections |
| `--ln-border2` | `rgba(255,255,255,0.14)` | Default borders on chips, buttons, inputs |
| `--ln-border3` | `rgba(255,255,255,0.22)` | Emphasis borders, modal outlines, context menus |

### Text
| Token | Value | Usage |
|---|---|---|
| `--ln-text` | `#e8e6e1` | Primary text, titles, editable input values |
| `--ln-text2` | `#9a9790` | Body text, secondary labels, icon defaults |
| `--ln-text3` | `#5e5c58` | Hints, timestamps, mono-caption labels, placeholders |

### Accent
| Token | Value | Usage |
|---|---|---|
| `--ln-accent` | `#7c6fcd` | Primary button background, focus ring, active folder chevron tint |
| `--ln-accent2` | `#a89de0` | Active-state text (active folder name, selected note title) |
| `--ln-accent-bg` | `rgba(124,111,205,0.15)` | Active row backgrounds, info boxes, hovered search result |

### Semantic
| Token | Value | Usage |
|---|---|---|
| `--ln-danger` | `#c0524a` | Delete buttons, danger menu items, error text |
| `--ln-danger-bg` | `rgba(192,82,74,0.12)` | Delete confirmation warning box |
| `--ln-success` | `#4a9e6a` | Upload complete chip border, success info box, green tick |
| `--ln-amber` | `#b87c2a` | Temporary password warning, warning info box |

---

## 3. Typography

Two families only. Both are loaded from Google Fonts on the web target.

- **Inter** (400, 500, 600, 700) — all UI text and note body prose.
- **JetBrains Mono** (400, 500) — timestamps, filenames, breadcrumb paths, kbd hints, code blocks, meta labels, uppercase section labels.

### Type scale

| Role | Font | Size | Weight | Line-height | Letter-spacing |
|---|---|---|---|---|---|
| Note title (editor) | Inter | 32 px | 600 | 1.2 | -0.02em |
| Section header in note (h2) | Inter | 22 px | 600 | — | -0.015em |
| Sub-header (h3) | Inter | 17 px | 600 | — | -0.01em |
| Body prose | Inter | 15.5 px (comfortable) / 14 px (compact) | 400 | 1.65 / 1.55 | — |
| Sidebar folder row | Inter | 13 px | 400 | — | — |
| Note card title | Inter | 13 px | 500 | — | -0.005em |
| Note card preview | Inter | 12 px | 400 | 1.4 | — |
| Primary button | Inter | 12 px | 500 | — | — |
| Modal title | Inter | 16 px | 600 | — | -0.01em |
| Auth title | Inter | 22 px | 600 | — | -0.015em |
| Timestamp / meta | JetBrains Mono | 10–11 px | 400 | — | 0.02–0.04em |
| Section label (uppercase) | JetBrains Mono | 10 px | 400 | — | 0.08em |
| Code block | JetBrains Mono | 12.5 px | 400 | 1.6 | — |
| OTP digit | JetBrains Mono | 20 px | 500 | — | — |

### Usage notes

- Titles always use Inter with slight negative letter-spacing (`-0.01em` to `-0.02em`) for optical tightness.
- Mono is *never* used for prose; reserve for anything that reads as data (dates, file sizes, paths, code, labels).
- Uppercase mono section labels (`letter-spacing: 0.08em`) mark metadata regions (sidebar "Folders", note list "3 notes · sorted by modified", field labels in auth).

---

## 4. Spacing, radii, density

### Density modes

Two modes, exposed via a user-visible tweak and persisted to `localStorage` under `ln:density`. Swap the tokens below at the `:root` level; all components inherit.

| Token | Comfortable | Compact |
|---|---|---|
| `--ln-row-pad-y` | 6 px | 3 px |
| `--ln-row-pad-x` | 10 px | 8 px |
| `--ln-row-gap` | 2 px | 1 px |
| `--ln-sidebar-w` | 240 px | 220 px |
| `--ln-notelist-w` | 280 px | 260 px |
| `--ln-editor-pad` | 48 px | 32 px |
| `--ln-body-font-size` | 15.5 px | 14 px |
| `--ln-body-line-height` | 1.65 | 1.55 |
| `--ln-chip-pad-y` | 5 px | 3 px |
| `--ln-chip-pad-x` | 10 px | 8 px |

### Radii

- **4 px** — kbd hints, small form pills, code inline background
- **5 px** — chips, note cards, segmented controls, menu items
- **6 px** — inputs, buttons, info boxes, sidebar search, note cards hover border
- **7 px** — context menus
- **8 px** — dropzones, QR code wrapper
- **10 px** — modals, Tweaks panel
- **12 px** — auth card, Android screen inner radius
- **30 px / 38 px** — Android screen / device bezel radius

### Editor layout

- Body column capped at **760 px** max-width, centered.
- Horizontal padding `var(--ln-editor-pad)` (48 / 32 by density).
- Top padding 40 px, bottom 140 px (accounts for attachment bar + trailing whitespace).

---

## 5. Desktop layout

```
┌─────────────┬──────────────────┬────────────────────────────┐
│ Sidebar     │  Note list       │  Editor                    │
│ 240 px      │  280 px          │  flex: 1                   │
│             │  (hides to 0     │                            │
│ Brand       │  via toggle)     │  Topbar: breadcrumb        │
│ ⌘K search   │                  │  Title input (32 / 600)    │
│ Folder tree │  Folder name     │  Meta row (mono)           │
│             │  Sort row        │  WYSIWYG body              │
│ [New note]  │  Note cards      │  Attachment bar (pinned)   │
│ [+ folder]  │                  │                            │
└─────────────┴──────────────────┴────────────────────────────┘
```

- Sidebar, note list, and editor use `display: grid` with `grid-template-columns: var(--ln-sidebar-w) var(--ln-notelist-w) 1fr`. Animate the middle column to `0` when hidden (transition on `grid-template-columns`, 180 ms ease).
- Columns are separated by a single `1 px solid var(--ln-border)` right border on sidebar and note list.
- `⌘K` (or `Ctrl+K`) from anywhere opens the search modal.

---

## 6. Component inventory

Each component maps to the React component in the prototype and the corresponding Flutter widget. Implementation details below each.

### 6.1 Sidebar / FolderTree

**React:** `Sidebar` + `FolderNode` (`components.jsx`)
**Flutter:** `Sidebar` stateful widget containing a `ListView` of `FolderTreeTile`.

- Header: `🦎` mark (28 px, rounded 7 px, `--ln-surface2` bg, `1 px solid --ln-accent`), brand name "LizardNotes" + mono subtitle for user email.
- Search pill: full-width, opens search modal on click. Shows magnifier icon, placeholder "Search notes…", kbd `⌘K` on the right.
- Section label "Folders" — mono 10 px uppercase `--ln-text3`.
- Tree: nested folders indented 14 px per depth level.
  - Each row: 14 px chevron → 14 px folder icon → name → `···` more (opacity 0; opacity 1 on `:hover`).
  - Hover: `background: --ln-surface3`, `color: --ln-text`.
  - Active (`data-active="true"`): `background: --ln-accent-bg`, text and icon become `--ln-accent2`.
  - Right-click or `···` click opens context menu.
  - Double-click activates inline rename.
  - Chevron rotates 90° via `transform` when expanded.
- Footer: primary `New note` button (flex:1) + ghost-style `+ folder` icon button.

### 6.2 FolderTreeTile (row)

- 13 px font, `--ln-text2` default color.
- `padding-inline: var(--ln-row-pad-x)`, `padding-block: var(--ln-row-pad-y)`.
- Rename mode replaces the label with an `<input>` styled with `--ln-surface3` bg and `1 px solid --ln-accent`, auto-focused and fully selected on entry. Enter commits, Escape cancels. Blur commits.

### 6.3 NoteList panel

**React:** `NoteList`
**Flutter:** `NoteListPanel` with `NoteTile` children.

- Panel head (14 px padding): folder name (13 px / 600) + note count (mono 10 px) + `+` icon button.
- Sort chip below: mono 10 px uppercase. Hardcoded to "Sort: modified ↓" in v1.
- Note cards: 10 × 12 px padding, 6 px radius, 1 px transparent border.
  - Title (13 px / 500), preview (12 px, 2-line clamp), date (mono 10 px).
  - Hover: `--ln-surface3` bg.
  - Active: `--ln-accent-bg` bg, accent-tint border (`rgba(124,111,205,0.28)`), title becomes `--ln-accent2`.
- Empty state: centered `--ln-text3` at 40 px top padding: "This folder is empty. Create your first note."

### 6.4 Editor

**React:** `Editor` + `renderBlock`
**Flutter:** `WysiwygEditor` screen.

- **Topbar** (44 px tall, 1 px bottom border):
  - Left: panel-toggle icon button (hides/shows note list).
  - Center: breadcrumb in mono 11 px — `Work / Projects / Atlas migration / Kickoff notes`. Last two segments use `--ln-text2`.
  - Right: `···` icon button (note actions).
- **Title input:** full-width borderless input, 32 px / 600, placeholder "Untitled". Autosaves to note on change (debounce in real impl; prototype is immediate).
- **Meta row:** mono 11 px — "Modified 2h ago · 4 paragraphs · 2 attachments".
- **Body:** renders blocks. In production this is a CodeMirror / ProseMirror-style WYSIWYG surface; the prototype renders typed block records.
- **Floating format toolbar:**
  - Appears on non-empty text selection inside `.ln-body`.
  - Position: above the selection (`rect.top - 44 px`, centered on selection).
  - Clears on note switch or scroll.
  - Buttons: B, I, H1, H2, H3, bulleted list, code, link. Active button uses `--ln-accent-bg` + `--ln-accent2`.

### 6.5 Body blocks

Block types rendered inside `.ln-body` (all share `var(--ln-body-font-size)` / `var(--ln-body-line-height)` prose defaults):

| Block | Rendering |
|---|---|
| `h1` | Hidden in body — the editable title input already shows it. |
| `h2` | 22 px / 600, -0.015em, 32 px top / 12 px bottom margin |
| `h3` | 17 px / 600, -0.01em, 24 px top / 8 px bottom margin |
| `p` | Default body prose, 0 top / 14 px bottom margin |
| `ul` / `ol` | 22 px left padding; markers tinted `--ln-text3`; 5 px bottom margin per item |
| `quote` | 2 px left border (`--ln-border3`), 16 px left padding, italic, `--ln-text2` |
| `code` (inline) | Mono 0.88em, `--ln-surface2` bg, 1 px border, 3 px radius |
| `pre`/code block | `--ln-surface3` bg, 1 px border, 6 px radius, 14 × 16 px padding; language tag above is uppercased mono 10 px |
| `image` | 1 px border, 6 px radius. Striped placeholder canvas (16:9, repeating-linear-gradient in `--ln-surface2` tones) with uppercase-mono caption strip below |
| `meta` | Single-line mono 11 px, rendered directly under the title |

### 6.6 AttachmentBar + AttachmentChip

**React:** `AttachmentBar`
**Flutter:** `AttachmentBar` pinned to the bottom of editor via `Scaffold.bottomSheet` or a `SafeArea` bar above the keyboard.

- Pinned, `--ln-surface` bg, 10 × 16 px padding, horizontal scroll, 50 px min-height.
- First element: uppercase-mono label "Attachments".
- Chip (mono 12 px, 5 × 10 px padding, `--ln-surface2` bg, 1 px `--ln-border2`, 5 px radius):
  - **Idle:** neutral — icon: paperclip. Clicking opens chip context menu (Download, Copy link, Remove).
  - **Uploading:** border `--ln-accent`, text `--ln-accent2`. A 2 px progress bar slices across the bottom inside the chip.
  - **Complete:** border `rgba(74,158,106,0.55)`, text `--ln-success`, `✓` prefix.
- `+ attach file` trigger: dashed border, `--ln-text2`. Opens the upload overlay.

### 6.7 UploadOverlay (drop zone + progress)

**React:** `UploadOverlay`
**Flutter:** `UploadSheet` using a `showDialog` with a custom body.

- Modal card, `--ln-surface2`, 18 px padding, 10 px radius.
- Dropzone: dashed 2 px `--ln-border2` border, 8 px radius, 28 × 20 px padding.
  - Idle copy: "Drag and drop or browse" + sub: "Up to 25 MB each · PDF, PNG, JPG, MD, XLSX".
  - Drag-over: border `--ln-accent`, bg `--ln-accent-bg`, title text becomes `--ln-accent2`, copy swaps to "Drop to attach".
- Upload list rows:
  - 28 px square file-type swatch (ext code in mono uppercase inside).
  - Filename (12.5 px), sub-meta mono 10 px.
  - Uploading: 100 px thin progress bar on the right, filled with `--ln-accent`; "{size} · {pct}%".
  - Complete: green tick + "{size} · uploaded".
  - Failed: red sub-text "failed — {reason}" + "Retry" button.
- Presigned URL expiry: **PUT 15 min, GET 60 min** (backend contract).

### 6.8 ContextMenu

**React:** `ContextMenu`
**Flutter:** Popup menu (desktop) or bottom sheet (mobile — see §8.4).

- Position: fixed at `{x, y}` with viewport clamp (max left: `innerWidth - 200`, max top: `innerHeight - 220`).
- `--ln-surface3` bg, 1 px `--ln-border3`, 7 px radius, 4 px padding, box-shadow `0 10px 30px rgba(0,0,0,0.45)`.
- Items: 6 × 10 px padding, 10 px gap icon-to-label, 12.5 px font.
- Hover: `--ln-accent-bg` bg, `--ln-accent2` text.
- Danger variant: `--ln-danger` text; on hover `--ln-danger-bg` bg, text stays `--ln-danger`.
- Separated by a 1 px `--ln-border2` divider (4 px vertical margin).

**Folder menu items:** Rename, New subfolder, New note here, Move to…, ───, Delete folder… (danger).
**Note menu items:** Rename, Move to folder…, Copy link, ───, Delete (danger).

Rename and shortcut hints are shown as mono 10 px on the right of the item.

### 6.9 MoveDialog

- Modal card, 560 px max width, 20 px padding.
- Title: `Move folder` / `Move note`.
- Description: `Choose a new location for <strong>{target name}</strong>.`
- Body: scrollable tree of selectable rows (max-height 280 px, `--ln-surface` bg, 1 px border, 6 px radius, 8 px padding).
- Row states:
  - default → hover `--ln-surface3`
  - selected → `--ln-accent-bg` + `--ln-accent2`
  - disabled → 55% opacity, cursor not-allowed
- Disabled rules:
  - Folder move: the folder itself, any descendant, and the current parent are disabled.
  - Note move: only the current parent folder is disabled.
- Footer: ghost `Cancel`, primary `Move here` (disabled until a destination is selected).

### 6.10 DeleteConfirmDialog

- Modal card, 460 px.
- Title: `Delete "{name}"?`
- Warning box: `--ln-danger-bg`, `1 px solid rgba(192,82,74,0.35)`, 10 × 12 px padding, triangle-warning icon in `--ln-danger`.
- Folder body copy: `This folder contains <strong>N note(s)</strong> and <strong>M subfolder(s)</strong>. All will be permanently deleted.` Always show the count — never silently delete.
- Note body copy: `This note will be permanently deleted. This action cannot be undone.`
- Footer: ghost `Cancel`, danger `Delete all` (folder) / `Delete note` (note).

### 6.11 SearchModal

**React:** `SearchModal`
**Flutter:** Desktop-only floating dialog (`⌘K`), mobile uses the search tab screen.

- Opens centered on a dimmed overlay (`rgba(0,0,0,0.55)`), 620 px × up to 78 vh.
- Input row: magnifier + borderless 15 px input + `ESC` kbd hint.
- Filter row: chips — `All`, `Notes`, `Attachments`, `This folder`. Active chip uses `--ln-accent-bg`.
- Results: grouped with uppercase-mono section labels ("Recent" when query is empty, otherwise "Notes" and "Attachments").
  - Each result: title with highlighted match span (`--ln-accent2`, 600) + snippet around the match + mono path ("Work / Projects / Atlas migration").
- Keyboard: ↑/↓ moves cursor, ↵ opens, Esc dismisses. Cursor resets on query or filter change.
- Footer hint bar: `↑↓ navigate    ↵ open    Esc dismiss` in mono 10 px.

### 6.12 Tweaks panel

- Floating bottom-right panel, 14 × 16 px padding, 10 px radius.
- Shown only when the "Tweaks" host toggle is on.
- Contains the density segmented control. Default `comfortable`; persists to `localStorage.ln:density` and mirrors as `document.documentElement[data-density]`.

### 6.13 Tweaks host protocol

The desktop app integrates with the host's Tweaks toolbar:

1. Register a `message` listener for `{type: '__activate_edit_mode'}` and `{type: '__deactivate_edit_mode'}`.
2. Post `{type: '__edit_mode_available'}` to `window.parent` after the listener is live.
3. On any tweak change, apply live and post `{type: '__edit_mode_set_keys', edits: { density: 'compact' }}`.
4. Default JSON block wrapped in `/*EDITMODE-BEGIN*/ … /*EDITMODE-END*/` in the HTML.

---

## 7. Auth flow

### 7.1 Flow paths

- **First login:** Login → Set new password (forced) → MFA setup step 1 (QR) → MFA setup step 2 (verify) → App.
- **Subsequent logins:** Login → MFA code → App.
- **Password reset:** Login → Forgot password → Enter code + new password → Login.

### 7.2 Shared auth chrome

- `.ln-auth-page`: full viewport, centered, `--ln-bg`.
- `.ln-auth-card`: 400 px max width, `--ln-surface` bg, 12 px radius, 36 × 32 px padding, 1 px `--ln-border`.
- Brand mark: 52 px rounded-12 square, `--ln-surface2` bg, `1 px solid --ln-accent`, 🦎 emoji at 26 px. MFA screens swap the emoji for a lock icon (`--ln-accent2`, `--ln-border3` outline instead of accent).
- Title (22 px / 600 / -0.015em, centered) + subtitle (13 px `--ln-text2`, centered, max 320 px).
- Fields: uppercase-mono 10 px label above each input. Inputs are `--ln-surface2` bg, 1 px `--ln-border2`, 6 px radius, 10 × 12 px padding, 14 px text. Focus → border `--ln-accent`.
- Primary button: full-width, `--ln-accent`, 11 × 16 px padding, 6 px radius.
- Secondary link: centered, 12.5 px, `--ln-text2`, `--ln-accent2` on hover.

### 7.3 Info boxes

- Amber (temporary-password warning): `rgba(184,124,42,0.12)` bg, `1 px rgba(184,124,42,0.4)` border, triangle-warning icon `--ln-amber`.
- Green (reset code sent): `rgba(74,158,106,0.1)` bg, `1 px rgba(74,158,106,0.35)`, checkmark icon `--ln-success`.
- Neutral (MFA context): `--ln-surface2` bg, 1 px `--ln-border`.

### 7.4 OTP input

6 individual 42 × 50 px boxes, 8 px gap, mono 20 px / 500, centered. Auto-advance on digit entry; backspace on empty moves back. Focused or filled box: border `--ln-accent`; filled value: text `--ln-accent2`.

### 7.5 Stepper

Two-dot progress indicator for MFA setup. Dots: 18 px, `--ln-surface2` bg, 1 px border. Active dot: `--ln-accent-bg` bg, `1 px --ln-accent`, text `--ln-accent2`. Connected by a 28 px 1 px line.

### 7.6 QR code

180 × 180 px, white background, 10 px padding, 8 px radius. Real impl uses the `AssociateSoftwareToken` response and `qr_flutter`. The prototype shows a stylized pattern.

### 7.7 Cognito contract

- Uses SRP (`ALLOW_USER_SRP_AUTH`) — handled by `amazon_cognito_identity_dart_2`.
- `NEW_PASSWORD_REQUIRED` → show Set-new-password screen.
- `SOFTWARE_TOKEN_MFA` → show MFA code screen.
- `AssociateSoftwareToken` → MFA setup step 1. `VerifySoftwareToken` → step 2.
- Password reset: `ForgotPassword` sends code; `ConfirmForgotPassword` submits code + new password.
- Password policy shown as hint: min 8 chars, one number, one symbol.

---

## 8. Mobile (Android)

Target framework: Flutter. Use `resizeToAvoidBottomInset: true` so the format toolbar docks above the keyboard automatically.

### 8.1 Navigation stack

`FolderList → NoteList → Editor`, each pushed via `Navigator.push`. Back button is labeled with the parent screen ("‹ Projects", "‹ Atlas"). Bottom nav bar (Folders / Search / Settings) is only visible on root-level screens (`FolderList` and `SearchScreen` and `SettingsScreen`), not the editor.

### 8.2 Screen: folder list

- Topbar: "LizardNotes" (14 px / 600) left-aligned, search and `···` icons right.
- List rows: 14 × 16 px padding, 1 px bottom border. Folder icon 18 px, name 14 px / 500, mono sub "{subfolders} subfolders · {notes} notes", `›` chevron right.
- FAB (52 px, accent, bottom-right, 16 px from edges, 72 px from bottom nav) creates a new note in the current context.

### 8.3 Screen: note list

- Topbar: back button "‹ {parent}", centered folder name, `···` right.
- Meta strip below topbar: mono 10 px uppercase, "{N} notes · sorted by modified", 1 px bottom border.
- Note rows: 12 × 16 px padding, title 14 px / 500, preview 12 px (2-line clamp), date mono 10 px.
- FAB stays (new note in this folder).

### 8.4 Bottom sheet (replaces desktop context menu)

- Uses `showModalBottomSheet`.
- `--ln-surface2` bg, top corners 16 px radius, 8 / 6 / 18 px padding.
- Drag handle: 40 × 4 px rounded, `--ln-border3`, 6 / 10 px margins.
- Item: 12 × 14 px padding, 14 px font, 14 px gap icon-label, 6 px radius. Hover / press → `--ln-surface3`.
- Danger item: text `--ln-danger`.
- Folder sheet items match the desktop folder context menu; note sheet items match the desktop note context menu.

### 8.5 Screen: editor (mobile)

- Topbar: back "‹ {folder}", note title (12 px / 500, `--ln-text2`, centered, truncated), `···` right.
- Body: 16 × 18 px padding. Title 22 px / 600 / -0.015em. Meta row mono 10 px. Prose reuses desktop block styles at 14 px.
- Attachment bar: horizontal scroll above the format toolbar. Chips at 11 px mono. `+ attach` dashed.
- Format toolbar: 6 × 10 px padding, 1 px top border, `--ln-surface2` bg. Horizontal scroll. B, I, H1, H2, H3, list, link. Docked directly above keyboard.
- Keyboard: `resizeToAvoidBottomInset` pushes the toolbar up; no explicit spacer needed.

### 8.6 Screen: search (mobile tab)

- Dedicated tab — always one tap away from the bottom nav.
- Input row directly below the status bar, 10 × 12 px padding, `--ln-surface2` bg, 1 px border, 7 px radius.
- Results list reuses desktop search result rows minus the kbd footer.

---

## 9. Component ↔ Flutter widget map

| Prototype / Design concept | Flutter widget |
|---|---|
| Sidebar, FolderNode | `Sidebar`, `FolderTreeTile` |
| NoteList, note card | `NoteListPanel`, `NoteTile` |
| Editor shell | `WysiwygEditor` |
| FormatToolbar | `FormatToolbar` (floating desktop / docked mobile) |
| AttachmentBar + chip | `AttachmentBar`, `AttachmentChip` |
| UploadOverlay + progress rows | `DropZoneOverlay`, `UploadProgressItem` |
| SearchModal (desktop) | `SearchModal` (shown via `showDialog`) |
| Search tab (mobile) | `SearchScreen` |
| ContextMenu (desktop) | `ContextMenu` (popup) |
| Bottom sheet (mobile) | `showModalBottomSheet` with `FolderActionsSheet` / `NoteActionsSheet` |
| MoveDialog | `MoveDialog` |
| DeleteConfirmDialog | `DeleteConfirmDialog` |
| OtpRow | `OtpInputRow` |
| QR block | `QrCodeDisplay` |
| Amber / green / neutral info box | `AuthInfoBox` |

---

## 10. Platform-specific notes

### 10.1 Web (first target)

- Full three-column layout. `⌘K` / `Ctrl+K` opens search modal.
- Drag-and-drop file upload via the drop-zone overlay.
- Right-click context menus on folder and note rows.
- Respect `prefers-color-scheme` only to the extent of *always being dark* (the app has no light mode in v1).

### 10.2 Mobile (second target)

- Flutter app. Linear navigation stack replaces the sidebar.
- Bottom nav: Folders / Search / Settings.
- Format toolbar docked above the system keyboard via `resizeToAvoidBottomInset`.
- `showModalBottomSheet` replaces popovers everywhere.
- File upload via system file picker; drag-and-drop is not applicable.

### 10.3 Desktop app (third target)

- Same layout as web.
- Native drag-and-drop from Finder/Explorer into the drop zone.
- Keyboard shortcuts consistent with web: `⌘K` / `Ctrl+K`, `F2` rename, `Esc` dismiss modals, `↑/↓/↵` in search results.

---

## 11. Acceptance checklist

- [ ] All colors reference tokens; no hardcoded hexes outside the token layer.
- [ ] Density tweak switches all metrics described in §4 without reflow jank.
- [ ] `⌘K` opens the search modal from anywhere; Esc dismisses.
- [ ] Drag-over on the drop zone swaps copy and accent-tint background.
- [ ] Delete modal always surfaces the content count.
- [ ] Move dialog disables target folder, its descendants, and the current parent.
- [ ] First login forces Set-password → MFA-setup 1 → MFA-setup 2.
- [ ] Floating format toolbar positions above a non-empty selection and clears on scroll or note switch.
- [ ] Mobile format toolbar stays directly above the system keyboard at all keyboard heights.
- [ ] Active folder and active note states use `--ln-accent-bg` + `--ln-accent2` consistently; no other accents creep into passive UI.
