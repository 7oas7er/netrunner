# Netrunner

Classic Netrunner card catalog (cards-only): browse the full set, generate random Runner/Corp starters and Limited / Proteus / Classic boosters. An **isolated app repo** following the solo+AI template ([Block Drop](https://github.com/7oas7er/block-drop)), with shared edge/obs in [`7oas7er/platform`](https://github.com/7oas7er/platform).

**Fundamental design:** apps do not depend on each other — only on platform. Architecture: [`docs/architecture.md`](docs/architecture.md).

The site is static HTML, CSS, and plain JavaScript under [`netrunner/`](netrunner/). How to run it locally: [`netrunner/README.md`](netrunner/README.md).

This repo previously ran on Play Framework / Scala (2017). It was rebuilt as a static catalog on the Block Drop template; auth, MySQL, and CodeDeploy are gone.

## Layout

| Path | Role |
|------|------|
| [`netrunner/`](netrunner/) | Static catalog (no framework, bundler, or package manager) |
| [`tests/`](tests/) | Node unit tests + Playwright e2e; gates deploy |
| [`scripts/csv-to-catalog-json.mjs`](scripts/csv-to-catalog-json.mjs) | Regenerate `catalog.json` from CSV |
| [`infra/terraform/aws/`](infra/terraform/aws/) | Site module + `envs/stg` / `envs/prod` + bootstrap |
| [`infra/terraform/cloudflare/`](infra/terraform/cloudflare/) | **DNS only** for Netrunner hosts (zone rulesets → platform `shared-edge`) |
| [`infra/terraform/grafana/`](infra/terraform/grafana/) | App synthetics, CloudWatch, dashboard, GitHub DS (Infinity + plugin → platform `shared-obs`) |
| [`.cursor/rules/`](.cursor/rules/) | Platform (`app-*`) + product (`netrunner-*`) Cursor rules |
| [`AGENTS.md`](AGENTS.md) | Definition of done for AI-assisted changes |
| [`docs/architecture.md`](docs/architecture.md) | App vs shared-platform ownership |
| [`docs/`](docs/) | ADRs, ops docs, first-apply checklist |
| [`SECURITY.md`](SECURITY.md) | Reporting + secret leak / rotation pointers |

## Environments and promotion

- Feature work → PR into **`staging`** → deploys **AWS stg** only.
- Promote to production by merging **`staging` → `main`** → deploys **AWS prod**.
- GitHub Environments `staging` / `production` / `terraform` hold distinct deploy/plan roles and resources.

| Env | Domain |
|-----|--------|
| stg | `netrunner-stg.7oas7er.com` |
| prod | `netrunner.7oas7er.com` |

## CI / CD

| Workflow | What it does |
|----------|----------------|
| [`.github/workflows/deploy-netrunner.yml`](.github/workflows/deploy-netrunner.yml) | Unit + Playwright; on push to `staging`/`main`, syncs `netrunner/` to S3, invalidates CloudFront, purges Cloudflare |
| [`.github/workflows/terraform-plan.yml`](.github/workflows/terraform-plan.yml) | `fmt` / Checkov / `validate` / **plan** (never applies) |
| [`.github/workflows/dependency-audit.yml`](.github/workflows/dependency-audit.yml) | `npm audit --audit-level=high` for `tests/` |
| [`.github/workflows/required-ci.yml`](.github/workflows/required-ci.yml) | Always-on PR check for branch rulesets |
| [`.github/workflows/codeql.yml`](.github/workflows/codeql.yml) | CodeQL SAST for `netrunner/` and Actions workflows |

## Terraform (local apply)

Apply stays on your machine. Typical profile:

```bash
export AWS_PROFILE=7oas7er
```

First-time wiring: [`docs/first-apply.md`](docs/first-apply.md).

Roots (separate state keys under `shared-netrunner-terraform-state-bucket`):

- `infra/terraform/aws/bootstrap`
- `infra/terraform/aws/envs/stg` and `envs/prod`
- `infra/terraform/cloudflare` (DNS)
- `infra/terraform/grafana` (app dashboards / synthetics / CW / GitHub DS)

Plus platform roots (separate repo): `shared-edge`, `shared-obs` — see [`7oas7er/platform`](https://github.com/7oas7er/platform).

Never commit `.tfstate`, `terraform.tfvars`, API tokens, or AWS keys.

## Local development

```bash
cd tests && npm run serve
```

Tests:

```bash
cd tests && npm ci && npx playwright install --with-deps chromium && npm test
```
