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

## CI/CD

### Workflows

| Workflow | File | Trigger |
|---|---|---|
| PR Check | `.github/workflows/pr-check.yml` | Pull requests targeting master; push to master |
| Deploy | `.github/workflows/deploy.yml` | Push to master only |

`pr-check.yml` runs `flutter analyze` and `flutter test --coverage` with no AWS access — it is fully offline.

`deploy.yml` runs the same test suite first, then deploys only if tests pass (`needs: [test]`). A failed test prevents deployment.

### GitHub Actions variables

Set these as **repository variables** (Settings → Secrets and variables → Actions → Variables tab) — they are not secrets and do not need to be encrypted:

| Variable | Example | Where to find it |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | `arn:aws:iam::123456789012:role/lizardnotes-frontend-deploy` | IAM console → Roles, or the infra repo outputs |
| `AWS_REGION` | `eu-west-1` | The region where the CDK stack was deployed |

### Credentials

No AWS access keys are stored anywhere. The deploy workflow uses GitHub OIDC to assume a manually created IAM role (`AWS_DEPLOY_ROLE_ARN`). The role's trust policy is scoped to this repository.

### S3 cache-control strategy

All assets produced by `flutter build web` use content-hashed filenames (e.g. `main.dart.js?v=abc123`), so they are safe to cache indefinitely:

```
Cache-Control: public, max-age=31536000, immutable
```

`index.html` is the only file whose name never changes. It is uploaded separately after the sync with:

```
Cache-Control: no-cache, no-store, must-revalidate
```

This ensures browsers always fetch a fresh `index.html` on each visit, which in turn references the correct hashed assets. A CloudFront invalidation (`/*`) is created after every deploy to clear the CDN layer.

### Re-running a failed deployment

1. Open the repository on GitHub → Actions tab.
2. Select the failed **Deploy** workflow run.
3. Click **Re-run failed jobs** (top-right) → **Re-run jobs**.

Only the failed job (and its dependants) will re-run; passing jobs are not repeated.
