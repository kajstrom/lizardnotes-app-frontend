# CLAUDE.md

Guidance for Claude Code when working in this repository. Follow these rules exactly.

---

## Project overview

Flutter frontend for LizardNotes — a personal, Obsidian-inspired notes app targeting web, mobile (Android), and desktop from one codebase. Backend is `lizardnotes-app-backend` (Lambda + API Gateway); infrastructure is `lizardnotes-app-infra` (CDK, writes outputs to SSM). All three deploy independently via GitHub Actions.

Reference docs (read only when the task needs them, do not duplicate their content into code comments):

- `IMPLEMENTATION.md` — UI/UX source of truth; pairs with the HTML prototypes (`LizardNotes.html` desktop, `Mobile.html`, `Auth.html`)
- `PROJECT.md` — product overview
- `openapi.yaml` in `lizardnotes-app-backend` — source of truth for API request/response schemas

---

## Feedback loop — always work in this order

Run the cheapest check that can catch your mistake, immediately after making it. Do not batch verification to the end.

1. **After every code edit:** `flutter analyze` — must report **zero issues**. Fix warnings too, not just errors.
2. **After changing one file:** run its mirrored test file only:
   `flutter test test/<same/path/as/lib>_test.dart`
3. **Before saying a task is done:** `flutter test` (full suite) — must pass.
4. **Never** claim analyze/tests pass without having run them in this session and seen the output.

Rules that keep the loop short:

- Tests mirror `lib/` exactly: `lib/features/notes/widgets/note_tile.dart` ↔ `test/features/notes/widgets/note_tile_test.dart`. When you create a source file, create the mirrored test file. When you edit one, update the other.
- Write or update the test **before** the implementation when fixing a bug: first make the test reproduce the bug, then fix it.
- Prefer widget/unit tests over `flutter run` for verification. Only run the app when the change is visual and cannot be asserted in a test.
- Running the app locally requires AWS SSM config: use `scripts/run_local.sh` (web via Brave) — do not call `flutter run` directly for web, it will be missing the `--dart-define` values.
- A pre-commit hook (`.githooks/pre-commit`, installed via `scripts/setup_hooks.sh`) runs `flutter analyze` + `flutter test`. If a commit fails, fix the code — never bypass with `--no-verify`.

### Commands

```bash
flutter analyze                       # static analysis — run after every edit
flutter test test/path/to/x_test.dart # single test file — fastest test signal
flutter test                          # full suite — before completion/commit
flutter pub get                       # after editing pubspec.yaml
scripts/run_local.sh                  # run web app locally (fetches SSM config)
scripts/build_local.sh                # release web build with SSM config
```

CI (`.github/workflows/pr-check.yml`) runs `flutter analyze` and `flutter test --coverage` on PRs. Android APK builds on `master` (`android-build.yml`); web deploy is `deploy.yml`.

---

## Code map — where things go

Feature-first layout. New code goes in the feature it belongs to; create the standard subfolder if it is missing.

```
lib/
  main.dart, app.dart          # entry + root widget
  api/api_client.dart          # single HTTP client for the backend API
  config/app_config.dart       # compile-time config from --dart-define (AppConfig)
  router/app_router.dart       # all go_router routes — add routes here only
  theme/                       # design system: colour_tokens.dart, dimensions.dart,
                               #   text_styles.dart, app_theme.dart
  features/<feature>/
    models/                    # plain data classes, fromJson/toJson
    providers/                 # Riverpod state (see pattern below)
    screens/                   # route-level widgets
    services/                  # non-widget logic (e.g. notes/services/content_pipeline.dart)
    widgets/                   # feature widgets, one widget per file
```

Existing features: `auth`, `folders`, `notes`, `attachments`, `search`, `settings`, `shell`. Do not invent new top-level directories; if code doesn't fit an existing feature, ask or put it in the closest one.

Key packages already in use — reuse these, do not add alternatives:

| Concern | Package |
|---|---|
| State | `flutter_riverpod` (manual providers — **no codegen**, no `.g.dart`, no `@riverpod` annotations) |
| Routing | `go_router` |
| Editor | `flutter_quill` + `markdown_quill` (WYSIWYG; markdown is the storage format) |
| HTTP | `http` for API calls, `dio` for uploads with progress |
| Auth | `amazon_cognito_identity_dart_2` (SRP) |
| Test mocks | `mocktail` |

Adding any new dependency requires explicit user approval.

---

## Coding rules

These are enforced by review; violating them means the change is wrong even if tests pass.

1. **One widget/class per file**, file named in `snake_case` after the class. Small files beat clever files.
2. **Colours only via `LnColors`** (`lib/theme/colour_tokens.dart`). Never write `Color(0xFF...)` or hex values outside `theme/`. Same for spacing (`dimensions.dart`) and text styles (`text_styles.dart`) — check the theme files before defining new constants.
3. **State pattern** — copy the existing shape, e.g. `lib/features/notes/providers/note_provider.dart`:
   - immutable `XState` class with `const` constructor, `copyWith`, and a status enum (`idle/loading/error`)
   - `XNotifier extends Notifier<XState>` with methods that set state via `copyWith`
   - `final xProvider = NotifierProvider<XNotifier, XState>(XNotifier.new);`
   - Widgets read state with `ref.watch`, call methods with `ref.read(...).method()`. No business logic in widgets.
4. **All backend calls go through `ApiClient`** (`lib/api/api_client.dart`). Never construct URLs or attach auth headers in feature code.
5. **Config only via `AppConfig`** (`String.fromEnvironment`). Never read env vars elsewhere; never hardcode URLs, pool IDs, or bucket names.
6. **Comments** explain *why* (a constraint, a workaround, a spec reference), never *what* the next line does. No commented-out code. No "changed X to Y" narration.
7. **Match neighbouring code.** Before writing a new widget/provider/model, open one existing sibling in the same folder and follow its structure, naming, and import style.
8. **Keep diffs minimal.** Do not reformat, rename, or "improve" code outside the task. One task = one focused change.
9. Follow `flutter_lints` defaults (`analysis_options.yaml`); never add `// ignore:` without user approval.

---

## Domain constraints (do not violate)

### Auth — Cognito SRP only

- App Client allows only `ALLOW_USER_SRP_AUTH` + `ALLOW_REFRESH_TOKEN_AUTH`. **Never** call `InitiateAuth` with `USER_PASSWORD_AUTH` — it is rejected by Cognito.
- All API calls send `Authorization: Bearer <JWT>`.
- Flow paths: first login forces `NEW_PASSWORD_REQUIRED` → MFA setup (QR + OTP); subsequent logins are Login → MFA OTP; password reset via emailed code.

### Attachments never go through the API

1. `POST /notes/{noteId}/attachments` → backend returns presigned S3 **PUT** URL (15 min)
2. Client uploads the bytes directly to S3
3. Downloads: `GET .../attachments/{attachmentId}` → presigned S3 **GET** URL (60 min) → client fetches from S3

### Editor

WYSIWYG only — never expose raw markdown to the user. Markdown ↔ Quill Delta conversion lives in `lib/features/notes/services/content_pipeline.dart`; all conversions go through it.

### SPA routing

CloudFront rewrites 404s to `/index.html`; go_router owns all paths. Nothing to configure here — just don't rely on server-side routes.

---

## API route table

Schemas: `openapi.yaml` in `lizardnotes-app-backend`.

| Method | Path |
|---|---|
| GET/POST | `/folders` |
| PUT/DELETE | `/folders/{folderId}` |
| GET/POST | `/notes` |
| GET/PUT/DELETE | `/notes/{noteId}` |
| GET/POST | `/notes/{noteId}/attachments` |
| DELETE | `/notes/{noteId}/attachments/{attachmentId}` |
| GET | `/auth/me` |

---

## UI design

Source of truth: `IMPLEMENTATION.md` + HTML prototypes. Key decisions:

- **Web/Desktop:** three-column shell — sidebar (220px), note list (260px), editor (flex). 
- **Mobile:** navigation stack (folders → notes → editor), bottom nav (Folders / Search / Settings), context menus become bottom sheets.
- Dark theme, flat surfaces, no gradients. Every colour comes from `LnColors` — the token names match the design tokens (`--ln-bg` → `LnColors.lnBg`, `--ln-accent` → `LnColors.lnAccent`, etc.), so translate spec tokens to `LnColors` constants directly.

---

## Deployment / infra facts

- Web deploy: `flutter build web --release` → `aws s3 sync build/web/ s3://<bucket> --delete` → CloudFront invalidation. Bucket/distribution IDs come from SSM (`/lizardnotes/frontend/bucketName`, `/lizardnotes/frontend/distributionId`).
- Runtime config from SSM at build time: `/lizardnotes/apigateway/apiUrl`, `/lizardnotes/cognito/userPoolId`, `/lizardnotes/cognito/appClientId` — injected as `--dart-define` (see `scripts/`).
- Android builds need a real JDK 17 (`JAVA_HOME` must point to a JDK, not a JRE).
