# LizardNotes — Flutter Frontend

Flutter web/mobile/desktop frontend for LizardNotes, a personal Obsidian-inspired notes app.

## Prerequisites

- **Ubuntu** (scripts assume Ubuntu paths)
- **asdf** with Flutter installed via `.tool-versions` — run `asdf install` in the repo root
- **Brave browser** — apt (`/usr/bin/brave-browser`) or snap (`/snap/bin/brave`); the script detects both
- **AWS CLI** configured for the correct account and region with access to SSM Parameter Store

## Local development

Config values (API URL, Cognito IDs) are fetched from AWS SSM at runtime — see `.env.example` for the expected keys.

### Run locally (hot reload)

```bash
bash scripts/run_local.sh
```

This fetches SSM parameters, then launches the app in Brave with hot reload enabled.

### Build locally (production)

```bash
bash scripts/build_local.sh
```

Produces a release build in `build/web/`. Useful for testing the production bundle locally before deploying.

## Deployment

Deployment runs via GitHub Actions: build → sync to S3 → CloudFront invalidation. See `CLAUDE.md` for the full pipeline details.
