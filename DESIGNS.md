# LizardNotes — UI Design Reference

This document captures all UI design decisions made during the design phase. It is the source of truth for visual implementation across all platforms.

---

## Design principles

- **Dark and minimal** — Obsidian-inspired dark theme throughout. No gradients, no decorative effects, flat surfaces only.
- **Adaptive layout** — three-column on desktop, stacked navigation on mobile. The sidebar is always visible when screen space allows; on mobile it becomes a navigation stack.
- **Folders are central** — the folder tree is the primary navigation structure, always accessible. Note lists open when a folder is selected.
- **WYSIWYG editing** — no raw markdown input. The editor renders formatting as the user types. A floating format toolbar appears on text selection (desktop) or is docked above the keyboard (mobile).

---

## Colour tokens

All colours are defined as CSS custom properties / Flutter theme tokens. Never hardcode hex values in components.

| Token | Value | Usage |
|---|---|---|
| `--ln-bg` | `#1a1a1a` | App background |
| `--ln-surface` | `#222222` | Sidebar, panels |
| `--ln-surface2` | `#2a2a2a` | Cards, inputs, secondary surfaces |
| `--ln-surface3` | `#303030` | Hover states, code blocks |
| `--ln-border` | `rgba(255,255,255,0.08)` | Subtle dividers |
| `--ln-border2` | `rgba(255,255,255,0.14)` | Default borders |
| `--ln-border3` | `rgba(255,255,255,0.22)` | Emphasis borders, modals |
| `--ln-text` | `#e8e6e1` | Primary text |
| `--ln-text2` | `#9a9790` | Secondary / body text |
| `--ln-text3` | `#5e5c58` | Muted / hints / timestamps |
| `--ln-accent` | `#7c6fcd` | Active states, progress bars, primary buttons |
| `--ln-accent2` | `#a89de0` | Accent text, active labels |
| `--ln-accent-bg` | `rgba(124,111,205,0.15)` | Tinted backgrounds (active rows, info boxes) |
| `--ln-danger` | `#c0524a` | Destructive actions |
| `--ln-danger-bg` | `rgba(192,82,74,0.12)` | Danger tinted backgrounds |
| `--ln-success` | `#4a9e6a` | Upload complete, success states |
| `--ln-amber` | `#b87c2a` | Warning states (e.g. temporary password) |

---

## Desktop layout

Three persistent columns side by side.

```
┌─────────────┬──────────────────┬────────────────────────────┐
│  Sidebar    │   Note list      │         Editor             │
│  220px      │   260px          │         flex: 1            │
│             │   (opens when    │                            │
│  Folder     │   folder is      │   Title (editable)         │
│  tree       │   selected)      │   WYSIWYG body             │
│             │                  │   Attachment bar (bottom)  │
│  + Note     │                  │                            │
│  + Folder   │                  │                            │
└─────────────┴──────────────────┴────────────────────────────┘
```

**Sidebar** contains the folder tree, a search bar at the top, and "New note" + "New folder" buttons pinned to the bottom. The `···` icon appears on hover over any folder row and opens the context menu.

**Note list panel** opens when the user clicks a folder. It shows note title, first-line preview, and last-modified date. Sorted by most recently modified. The panel is hidden (zero-width) when no folder is selected.

**Editor** occupies the remaining space. The top bar shows a breadcrumb path and the note title as an editable field. A floating format toolbar appears on text selection. The attachment bar is pinned to the bottom edge.

### Search

Opened by `⌘K` from anywhere. Renders as a centred floating modal over a dimmed overlay. Contains a text input, filter chips (All / Notes / Attachments / This folder), grouped results with highlighted match terms and content snippets, and a keyboard hint bar at the bottom (`↑↓` navigate, `↵` open, `Esc` dismiss).

---

## Mobile layout

Linear navigation stack — no persistent sidebar. Bottom navigation bar with three tabs: Folders, Search, Settings.

### Screen stack

```
Folder list  →  Note list  →  Editor
(root)          (folder)      (note)
```

Back navigation at each level returns to the previous screen. The breadcrumb is represented by the back button label (e.g. "‹ Projects").

### Screen: folder list

Top bar shows "LizardNotes" title with search and settings icons. Each folder row shows folder icon, name, child count summary, and a `›` chevron. A FAB (`+`) in the bottom-right creates a new note in the current context.

### Screen: note list

Top bar shows back button (labelled with parent folder name), folder name centred, and `···` for folder actions. Note rows show title, first-line preview, and relative date. FAB creates a new note in this folder.

### Screen: editor

Top bar shows back button (labelled with folder name), note title centred, and `···` for note actions. The WYSIWYG editor fills the scrollable body. The attachment bar sits above the format toolbar, scrolls horizontally when overflowing. The format toolbar is docked directly above the system keyboard (`resizeToAvoidBottomInset` in Flutter handles this automatically).

### Bottom sheet

The `···` action on mobile opens a bottom sheet (`showModalBottomSheet`) rather than a popover. Contains the same actions as the desktop context menu: Rename, Move to folder, Copy link, and Delete (destructive, red).

### Search tab

Search is a dedicated bottom navigation tab — always one tap away. The search input is at the top of the screen with results listed below. Matches highlight the search term in both title and content snippet.

---

## Folder management

### Folder tree row

Each row shows a collapse/expand chevron, folder icon, folder name, and a `···` icon that appears on hover (desktop) or long-press (mobile). Double-clicking the folder name (desktop) enters inline rename mode.

### Context menu actions

Opened by right-click or `···` hover icon. Options: Rename, New subfolder, New note here, Move to…, Delete folder…. Delete is styled in danger red and separated by a divider.

### Inline rename

Clicking Rename replaces the folder name text with an editable input field, focused and selected, styled with an accent border. Enter confirms, Escape cancels.

### Move dialog

A modal showing the full folder tree. The folder being moved (and its children) are not selectable as destinations. The currently selected destination is highlighted with accent tint. Footer buttons: Cancel and "Move here" (primary, accent).

### Delete confirmation

A modal showing the number of notes and subfolders that will be permanently deleted (e.g. "This folder contains 3 notes and 1 subfolder"). Footer buttons: Cancel and "Delete all" (danger red). Always surfaces the content count — never silently deletes.

---

## Attachment upload

### Attachment bar

Pinned to the bottom of the editor on all platforms. Shows existing attachments as chips. Each chip shows filename and can be clicked to open its context menu (Download, Copy link, Remove). An "+ attach file" button (dashed border) opens the upload overlay.

### Chip states

| State | Appearance |
|---|---|
| Idle | Neutral border, muted text |
| Uploading | Accent border, inline mini progress bar |
| Complete | Success green border and text, `✓` prefix |

### Drop zone overlay

Opens as an overlay when "+ attach file" is clicked. Two states: idle (dashed border, "Drag and drop or browse") and drag-over (accent border and background tint, "Drop to attach"). A "Browse files" button opens the system file picker.

### Upload progress list

Appears below the drop zone. Each file shows its own row: file type icon, filename, file size, and status. Status states: uploading with percentage and progress bar, complete with green tick, failed with red error text and a Retry button. Failed uploads also show the reason inline (e.g. "file too large").

### Chip context menu (existing attachments)

Click a chip to open: Download, Copy link (presigned S3 GET URL), Remove (destructive).

**Presigned URL expiry:** upload (PUT) 15 minutes, download (GET) 60 minutes — per backend contract.

---

## Auth screens

No self-signup. Admin creates accounts via Cognito. Users receive a temporary password by email.

### Auth flow paths

**First login:**
Login → Set new password (forced) → MFA setup: scan QR → MFA setup: verify code → App

**Subsequent logins:**
Login → MFA code → App

**Password reset:**
Login → Forgot password → Enter email code + new password → Login

### Screen: login

Email and password fields. "Sign in" primary button. "Forgot password?" text link below. The SRP challenge/response (`ALLOW_USER_SRP_AUTH`) is handled invisibly by the `amazon_cognito_identity_dart_2` Flutter package — the user sees a standard email/password form.

### Screen: set new password

Triggered automatically when Cognito returns `NEW_PASSWORD_REQUIRED`. An amber warning box explains the temporary password situation. Fields: new password (with hint showing Cognito policy: min. 8 chars, one number, one symbol) and confirm password. No cancel — the user must complete this step to proceed.

### Screen: MFA setup — scan (step 1 of 2)

A 2-step progress indicator. Instruction text, QR code (sourced from `AssociateSoftwareToken`), and a "Can't scan? Enter setup key manually" fallback link for users on desktop password managers. "Next" advances to verification.

### Screen: MFA setup — verify (step 2 of 2)

Six individual OTP digit input boxes (auto-advance on digit entry). "Confirm setup" calls `VerifySoftwareToken`. On success, MFA is permanently enabled on the account. "Back" returns to the QR screen.

### Screen: MFA code (every login)

Shown after every correct password entry when Cognito returns `SOFTWARE_TOKEN_MFA`. Neutral info box prompts user to open their authenticator app. Six OTP digit boxes. "Verify" submits. "Use a different account" link for edge cases.

### Screen: forgot password

Single email field. "Send reset code" calls Cognito `ForgotPassword`. "Back to sign in" link.

### Screen: enter code + new password

Green success info box confirms code was sent to the user's email. Three fields: code from email, new password, confirm password. "Reset password" calls `ConfirmForgotPassword` with all three values in a single submission. "Resend code" link for expired codes.

### Auth visual identity

All auth screens share the same app icon mark (lizard emoji in a rounded rectangle with accent border) centred at the top, followed by a screen title and optional subtitle. MFA screens use a lock icon mark instead. No decorative backgrounds — same dark surface as the rest of the app.

---

## Component inventory (Flutter widgets to implement)

| Component | Screen(s) | Notes |
|---|---|---|
| `FolderTreeTile` | Sidebar | Chevron, icon, name, hover `···` |
| `NoteTile` | Note list panel, mobile note list | Title, preview, date |
| `WysiwygEditor` | Editor | WYSIWYG, floating toolbar on selection |
| `FormatToolbar` | Editor (desktop floating / mobile docked) | B, I, H1, H2, H3, list, code, link |
| `AttachmentBar` | Editor bottom | Horizontal scroll, chips, add button |
| `AttachmentChip` | Attachment bar | Idle / uploading / complete states |
| `UploadProgressItem` | Upload overlay | File icon, name, size, progress/status |
| `DropZoneOverlay` | Upload overlay | Idle / drag-over states |
| `SearchModal` | Desktop global (`⌘K`) | Input, filters, grouped results |
| `SearchScreen` | Mobile search tab | Full screen, results list |
| `ContextMenu` | Folder tree, note list (desktop) | Right-click / `···` |
| `BottomSheet` | Mobile `···` | Folder and note actions |
| `MoveDialog` | Folder and note management | Full tree, destination picker |
| `DeleteConfirmDialog` | Folder and note management | Content count summary |
| `OtpInputRow` | MFA screens | 6 boxes, auto-advance |
| `QrCodeDisplay` | MFA setup | From `AssociateSoftwareToken` response |
| `AuthInfoBox` | Auth screens | Amber (warning) / green (success) variants |

---

## Platform-specific notes

### Web (first target)

Full three-column desktop layout. `⌘K` for search. Drag-and-drop file upload via the drop zone overlay. Right-click context menus on folder and note rows.

### Mobile (second target)

Linear navigation stack replaces the sidebar. Bottom navigation bar (Folders / Search / Settings). Format toolbar docked above the system keyboard. Bottom sheets replace context menus. File upload via system file picker (drag-and-drop not applicable).

### Desktop app (third target)

Same as web layout. Native drag-and-drop from Finder/Explorer to the drop zone overlay. Keyboard shortcuts consistent with web.