# Terraform plan in CI

Workflow: [`.github/workflows/terraform-plan.yml`](../../../.github/workflows/terraform-plan.yml).

Runs only when `infra/terraform/**` or this workflow file change (GitHub `paths:` filter). Separate from site deploy.

Within a run, **validate/plan are scoped per root** (`dorny/paths-filter`): e.g. a Cloudflare-only PR does not plan Grafana. `workflow_dispatch` and edits to the workflow file still exercise every root.

| Job | What |
|-----|------|
| Detect changes | Builds per-root matrices |
| Format | `terraform fmt -check -recursive` (if any infra path matched) |
| IaC policy (Checkov) | Scans `infra/terraform` with [`../.checkov.yaml`](../.checkov.yaml); see [`docs/iac-policy.md`](../../../docs/iac-policy.md) |
| Validate | `init -backend=false` + `validate` for **changed** roots only |
| Plan AWS / Cloudflare / Grafana | Same scoping; OIDC plan role + provider tokens |

Apply stays local (or a future apply workflow). Plan exit code **2** (changes) is treated as success; only errors fail the job.

**Plan Grafana** uses `-parallelism=1`, retries up to 5 times on Grafana API timeouts (`context deadline exceeded` / client timeouts — go-openapi default is 30s), then falls back to `-refresh=false` so Free-tier stalls do not hard-block PRs. Concurrency cancel-in-progress drops superseded merge plans. Wire `GRAFANA_GITHUB_TOKEN` (below) so CI does not plan to destroy the GitHub data source.

## One-time setup

### 1. Apply the plan role (stg)

```bash
export AWS_PROFILE=7oas7er
cd infra/terraform/aws/envs/stg
terraform init -reconfigure   # backends no longer pin profile=
terraform apply               # creates shared terraform-plan role
```

Note the output `github_terraform_plan_role_arn`.

### 2. GitHub Environment `terraform`

> **CI symptom if skipped:** plan jobs fail at `Configure AWS credentials` with
> `Could not load credentials from any providers` because `role-to-assume` is empty.
> Deploy Environments (`staging` / `production`) being populated does **not** configure this one.

Create Environment **terraform** (Settings → Environments). No deploy branch restriction required for plan-only.

**Variables**

| Name | Value |
|------|--------|
| `AWS_TERRAFORM_PLAN_ROLE_ARN` | `github_terraform_plan_role_arn` output |
| `STG_SITE_CERTIFICATE_ARN` | staging ACM cert ARN |
| `PROD_SITE_CERTIFICATE_ARN` | production ACM cert ARN (or omit if prod variable default is enough) |
| `STG_CLOUDFRONT_DOMAIN_NAME` | stg `distribution_domain_name` |
| `PROD_CLOUDFRONT_DOMAIN_NAME` | prod `distribution_domain_name` |
| `GRAFANA_STACK_SLUG` | Grafana Cloud stack slug |

**Secrets**

| Name | Value |
|------|--------|
| `STG_ORIGIN_VERIFY_SECRET` | same as stg `origin_verify_secret` / Cloudflare stg |
| `PROD_ORIGIN_VERIFY_SECRET` | same as prod / Cloudflare prod |
| `CLOUDFLARE_API_TOKEN` | token with the same scopes as local Cloudflare Terraform |
| `GRAFANA_CLOUD_ACCESS_POLICY_TOKEN` | stacks:read (+ SA write if plan needs it) |
| `GRAFANA_CLOUD_PROVIDER_ACCESS_TOKEN` | integration-management scopes |
| `GRAFANA_SM_ACCESS_TOKEN` | Synthetic Monitoring token |
| `GRAFANA_GITHUB_TOKEN` | Fine-grained PAT (Actions + Metadata read on `7oas7er/netrunner`). Same value as local `github_access_token`. Name is `GRAFANA_GITHUB_*` because Actions forbids secrets starting with `GITHUB_`. Without it, Plan Grafana proposes destroying `grafana_data_source.github` (exit code 2 — still green). |

OIDC trust subject (immutable form; Terraform default):

`repo:7oas7er@2952810/netrunner@87063790:environment:terraform`

Confirm with `gh api repos/7oas7er/netrunner/actions/oidc/customization/sub`. If the prefix differs, set `github_actions_plan_subject` in stg tfvars and re-apply.

## Local commands after this change

Backends no longer set `profile = "7oas7er"`. Before any root:

```bash
export AWS_PROFILE=7oas7er
```

Keep `aws_profile = "7oas7er"` in local `terraform.tfvars` for the AWS provider where used.
