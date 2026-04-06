# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project overview

Flutter frontend for LizardNotes — a personal, Obsidian-inspired notes app targeting web, mobile, and desktop from a single codebase. The backend is a separate repo (`lizardnotes-app-backend`); infrastructure is a third repo (`lizardnotes-app-infra`). All three deploy independently via GitHub Actions.

---

## Build and development commands

> The Flutter project has not been initialized yet. Once `pubspec.yaml` exists, the standard commands will be:

```bash
flutter pub get               # install dependencies
flutter run -d chrome         # run on web (first target)
flutter build web --release   # production web build → build/web/
flutter test                  # run all tests
flutter test test/path_to_test.dart  # run a single test file
flutter analyze               # lint / static analysis
```

### Deployment pipeline (GitHub Actions)

```bash
# Read SSM params → build → sync → invalidate CloudFront
flutter build web --release
aws s3 sync build/web/ s3://<bucketName> --delete
aws cloudfront create-invalidation --distribution-id <distributionId> --paths "/*"
```

Bucket name and distribution ID come from SSM:
- `/lizardnotes/frontend/bucketName`
- `/lizardnotes/frontend/distributionId`

---

## Architecture

### Three-repo structure

| Repo | Contents |
|---|---|
| `lizardnotes-app-frontend` | This repo — Flutter app |
| `lizardnotes-app-backend` | Lambda (TypeScript/Node.js) + API Gateway HTTP API |
| `lizardnotes-app-infra` | AWS CDK — provisions all resources, writes outputs to SSM |

The infra repo must be deployed before the backend or frontend.

### Auth — Cognito SRP

The Cognito App Client only allows `ALLOW_USER_SRP_AUTH` and `ALLOW_REFRESH_TOKEN_AUTH`. Plain `USER_PASSWORD_AUTH` is disabled.

- Use the `amazon_cognito_identity_dart_2` package (or Amplify Flutter `Auth`) — both implement SRP natively.
- Do **not** call `InitiateAuth` with `AuthFlow: USER_PASSWORD_AUTH` — it will be rejected.
- The SDK handles the multi-step SRP handshake automatically.
- All API calls pass the Cognito JWT as `Authorization: Bearer <token>`.

Cognito config is read from SSM at build time:
- `/lizardnotes/cognito/userPoolId`
- `/lizardnotes/cognito/appClientId`
- `/lizardnotes/apigateway/apiUrl`

### Auth flow paths

- **First login:** Login → Set new password (forced by Cognito `NEW_PASSWORD_REQUIRED`) → MFA setup: scan QR → MFA setup: verify OTP → App
- **Subsequent logins:** Login → MFA OTP → App
- **Password reset:** Login → Forgot password → Enter email code + new password → Login

### Attachment upload pattern

Attachments are **never** sent through the API:

1. Client calls `POST /notes/{noteId}/attachments`
2. Backend creates DynamoDB record and returns a presigned S3 **PUT** URL (15-minute expiry)
3. Client uploads directly to S3 using the presigned URL

Downloads: client calls `GET /notes/{noteId}/attachments/{attachmentId}` → backend returns presigned S3 **GET** URL (60-minute expiry) → client fetches from S3.

### SPA routing

CloudFront rewrites all 404s to `200 /index.html`. Flutter's client-side router handles all paths — this is already configured in the infra repo.

---

## UI design

Design spec lives in `DESIGNS.md`. Key decisions:

### Layout

- **Web/Desktop:** Three-column layout — sidebar (220px), note list (260px), editor (flex: 1). Sidebar always visible.
- **Mobile:** Linear navigation stack (folder list → note list → editor). Bottom nav bar with Folders / Search / Settings tabs. Context menus become bottom sheets (`showModalBottomSheet`).

### Design system

Dark theme, flat surfaces, no gradients. All colours must use the token system — never hardcode hex values.

| Token | Value | Usage |
|---|---|---|
| `--ln-bg` | `#1a1a1a` | App background |
| `--ln-surface` | `#222222` | Sidebar, panels |
| `--ln-surface2` | `#2a2a2a` | Cards, inputs |
| `--ln-surface3` | `#303030` | Hover states, code blocks |
| `--ln-border` | `rgba(255,255,255,0.08)` | Subtle dividers |
| `--ln-border2` | `rgba(255,255,255,0.14)` | Default borders |
| `--ln-border3` | `rgba(255,255,255,0.22)` | Emphasis borders, modals |
| `--ln-text` | `#e8e6e1` | Primary text |
| `--ln-text2` | `#9a9790` | Secondary text |
| `--ln-text3` | `#5e5c58` | Muted / hints |
| `--ln-accent` | `#7c6fcd` | Active states, primary buttons, progress bars |
| `--ln-accent2` | `#a89de0` | Accent labels |
| `--ln-accent-bg` | `rgba(124,111,205,0.15)` | Active rows, info boxes |
| `--ln-danger` | `#c0524a` | Destructive actions |
| `--ln-danger-bg` | `rgba(192,82,74,0.12)` | Danger tinted backgrounds |
| `--ln-success` | `#4a9e6a` | Upload complete |
| `--ln-amber` | `#b87c2a` | Warnings (e.g. temporary password notice) |

### Editor

WYSIWYG only — no raw markdown input. Floating format toolbar appears on text selection (desktop) or is docked above the keyboard (mobile). Format toolbar buttons: B, I, H1, H2, H3, list, code, link.

### Key widgets to implement

`FolderTreeTile`, `NoteTile`, `WysiwygEditor`, `FormatToolbar`, `AttachmentBar`, `AttachmentChip` (idle/uploading/complete states), `UploadProgressItem`, `DropZoneOverlay`, `SearchModal` (desktop `⌘K`), `SearchScreen` (mobile tab), `ContextMenu`, `BottomSheet`, `MoveDialog`, `DeleteConfirmDialog`, `OtpInputRow` (6 boxes, auto-advance), `QrCodeDisplay`, `AuthInfoBox` (amber/green variants).

---

## API reference

The `openapi.yaml` in `lizardnotes-app-backend` is the source of truth for all request/response schemas. Use it to generate the Dart HTTP client.

### Route table

| Method | Path | Description |
|---|---|---|
| `GET` | `/folders` | List folders |
| `POST` | `/folders` | Create folder |
| `PUT` | `/folders/{folderId}` | Update folder |
| `DELETE` | `/folders/{folderId}` | Delete folder |
| `GET` | `/notes` | List notes |
| `POST` | `/notes` | Create note |
| `GET` | `/notes/{noteId}` | Get note |
| `PUT` | `/notes/{noteId}` | Update note |
| `DELETE` | `/notes/{noteId}` | Delete note |
| `GET` | `/notes/{noteId}/attachments` | List attachments |
| `POST` | `/notes/{noteId}/attachments` | Upload attachment (returns presigned URL) |
| `DELETE` | `/notes/{noteId}/attachments/{attachmentId}` | Delete attachment |
| `GET` | `/auth/me` | Current user info |
