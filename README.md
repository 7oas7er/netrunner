# Netrunner

Classic Netrunner card catalog (cards-only): browse the full set, generate random Runner/Corp starters and Limited / Proteus / Classic boosters. An **isolated app repo** following the solo+AI template ([Block Drop](https://github.com/7oas7er/block-drop)), with shared edge/obs in [`7oas7er/platform`](https://github.com/7oas7er/platform).

**Fundamental design:** apps do not depend on each other — only on platform. The site is static HTML, CSS, and plain JavaScript under [`netrunner/`](netrunner/).

**Architecture:** [docs/architecture.md](docs/architecture.md) · **ADRs:** [docs/adr/](docs/adr/) · **Agents:** [AGENTS.md](AGENTS.md) · **Security floor:** [docs/github-branch-protection.md](docs/github-branch-protection.md) · **Secrets:** [SECURITY.md](SECURITY.md) · **Maintenance:** [docs/maintenance.md](docs/maintenance.md) · **Catalog:** [netrunner/README.md](netrunner/README.md) · **First apply:** [docs/first-apply.md](docs/first-apply.md)

This repo previously ran on Play Framework / Scala (2017). It was rebuilt as a static catalog on the Block Drop template; auth, MySQL, and CodeDeploy are gone.

## Layout

| Path | Role |
|------|------|
| [`netrunner/`](netrunner/) | Static catalog (no framework, bundler, or package manager) |
| [`tests/`](tests/) | Node unit tests + Playwright e2e; gates deploy |
| [`scripts/csv-to-catalog-json.mjs`](scripts/csv-to-catalog-json.mjs) | Regenerate `catalog.json` from CSV |
| [`infra/terraform/aws/`](infra/terraform/aws/) | Site module + `envs/stg` / `envs/prod` + bootstrap |
| [`infra/terraform/cloudflare/`](infra/terraform/cloudflare/) | **DNS only** for Netrunner hosts (zone rulesets → platform `shared-edge`) |
| [`infra/terraform/grafana/`](infra/terraform/grafana/) | App synthetics, CloudWatch, **prod+stg** dashboards, GitHub DS (Infinity + plugin → platform `shared-obs`) |
| [`.cursor/rules/`](.cursor/rules/) | Platform (`app-*`) + product (`netrunner-*`) Cursor rules — see [`.cursor/rules/README.md`](.cursor/rules/README.md) |
| [`.cursor/skills/`](.cursor/skills/) | Project skills (`new-app-from-template`, `gap-against-app-template`) |
| [`AGENTS.md`](AGENTS.md) | Definition of done for AI-assisted changes |
| [`docs/architecture.md`](docs/architecture.md) | App vs shared-platform ownership |
| [`docs/`](docs/) | ADRs, ops docs, first-apply checklist |
| [`docs/maintenance.md`](docs/maintenance.md) | Ongoing patch / Dependabot cadence |
| [`SECURITY.md`](SECURITY.md) | Reporting + secret leak / rotation pointers |

## Environments and promotion

- Feature work → PR into **`staging`** → deploys **AWS stg** only.
- Promote to production by merging **`staging` → `main`** → deploys **AWS prod**.
- GitHub Environments `staging` / `production` / `terraform` hold distinct deploy/plan roles and resources. Do not point staging and production at the same resources.

| Env | Domain |
|-----|--------|
| stg | `netrunner-stg.7oas7er.com` |
| prod | `netrunner.7oas7er.com` |

## CI / CD

| Workflow | What it does |
|----------|----------------|
| [`.github/workflows/deploy-netrunner.yml`](.github/workflows/deploy-netrunner.yml) | Unit + Playwright; on push to `staging`/`main`, syncs `netrunner/` to S3, invalidates CloudFront, purges Cloudflare (when site paths change) |
| [`.github/workflows/terraform-plan.yml`](.github/workflows/terraform-plan.yml) | `fmt` / **Checkov** / `validate` / **plan** for changed Terraform roots (OIDC read-only plan role). **Never applies.** |
| [`.github/workflows/dependency-audit.yml`](.github/workflows/dependency-audit.yml) | `npm audit --audit-level=high` for `tests/` when that lockfile changes |
| [`.github/workflows/required-ci.yml`](.github/workflows/required-ci.yml) | Always-on PR check (`Required CI`) for branch rulesets |
| [`.github/workflows/codeql.yml`](.github/workflows/codeql.yml) | CodeQL SAST for `netrunner/` and Actions workflows |

Deploy auth is GitHub OIDC → env-specific IAM roles (no long-lived AWS keys in GitHub). Dependabot opens weekly PRs to `staging` for Actions, Playwright, and **Terraform providers** (per root). Ongoing cadence: [`docs/maintenance.md`](docs/maintenance.md). Branch rules: [`docs/github-branch-protection.md`](docs/github-branch-protection.md). Checkov: [`docs/iac-policy.md`](docs/iac-policy.md). CodeQL: [`docs/codeql.md`](docs/codeql.md). Security headers: [`docs/security-headers.md`](docs/security-headers.md).

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

Plus platform roots (separate repo / state): `shared-edge`, `shared-obs` — see [`7oas7er/platform`](https://github.com/7oas7er/platform).

Never commit `.tfstate`, `terraform.tfvars`, API tokens, or AWS keys. Setup notes:

- [Architecture](docs/architecture.md)
- [Terraform plan CI](infra/terraform/docs/terraform-plan-ci.md)
- [Origin-verify secret rotation](infra/terraform/docs/origin-verify-secret-rotation.md)
- [AWS README](infra/terraform/aws/README.md)
- [Cloudflare README](infra/terraform/cloudflare/README.md)
- [Grafana README](infra/terraform/grafana/README.md)

## Observability

**Grafana Cloud Free** only: synthetics (stg + prod site checks), CloudWatch scrape, Cloudflare edge analytics (via GraphQL into Grafana), GitHub Actions panels. Do not add a second monitoring SaaS. Shared Infinity + GitHub plugin: platform `shared-obs`. Cloudflare remains DNS/edge (plus analytics pulled into Grafana)—not an APM product. Label: `project=netrunner`. Details: [`infra/terraform/grafana/README.md`](infra/terraform/grafana/README.md).

## Security principles

- Public traffic must arrive via **Cloudflare**; direct CloudFront (or other origin) URLs are rejected (origin-verify header gate).
- Secrets live in gitignored tfvars, GitHub Environment secrets, or env vars—not in git.
- Reporting and leak response: [`SECURITY.md`](SECURITY.md). Durable “why” for stack choices: [`docs/adr/`](docs/adr/).

## Local development

**Catalog:** serve the static site (required for `fetch` of `catalog.json`):

```bash
cd tests && npm run serve
```

Open http://127.0.0.1:4173 — see [`netrunner/README.md`](netrunner/README.md).

**Tests:**

```bash
cd tests
npm ci
npx playwright install --with-deps chromium
npm test
```

Details: [`tests/README.md`](tests/README.md).

**Pre-commit** (optional but recommended — catches `terraform fmt` and unit-test regressions before CI):

```bash
pipx install pre-commit   # or: brew install pre-commit
pre-commit install
pre-commit run --all-files
```

Config: [`.pre-commit-config.yaml`](.pre-commit-config.yaml). Hooks run `terraform fmt` under `infra/terraform/` and `npm run test:unit` when `tests/` or `netrunner/js/` change. Full `terraform validate` stays in CI (needs init/backends).

## Working with Cursor / agents

Follow [`AGENTS.md`](AGENTS.md) and rules under [`.cursor/rules/`](.cursor/rules/) (`app-*` platform + `netrunner-*` product). New app from this pattern: [`.cursor/skills/new-app-from-template/`](.cursor/skills/new-app-from-template/). Gap-analyze / migrate an existing repo: [`.cursor/skills/gap-against-app-template/`](.cursor/skills/gap-against-app-template/). Decisions: [`docs/adr/`](docs/adr/). Backlog: [`docs/template-readiness-backlog.md`](docs/template-readiness-backlog.md).
