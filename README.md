# openworks-lab/actions

Reusable GitHub Actions workflows for the openworks-lab fleet. Callers pass
`env: dev|prod` (+ `service_slug`); identity and the deployer role are derived
inside the reusable. Security/tooling upgrades happen here once.

## Workflows

| File | Purpose | Required caller inputs |
|---|---|---|
| `dockerfile-build-and-push.yml` | Build a Dockerfile, push to (infra-owned) ECR | `env`, `service_slug` |
| `static-publish-to-s3.yml` | Build an SPA, sync to `openworks-<env>-*` S3 | `env`, `s3-bucket` |
| `ecs-deploy.yml` | Drift-safe image swap on an ECS service | `env`, `service_slug`, `cluster`, `service`, `image` |

## Trust model

These assume `arn:aws:iam::211125308791:role/<env>-gha-deployer` via OIDC.
The role trust requires the **caller repo id** in `product_repo_ids` AND the
reusable to be one of the three files above at `refs/heads/main`. Adding a
**product** repo is a PR to infra `bootstrap/product_repos.auto.tfvars`. The
actions repo id is intentionally never in that list.

## Constraints (V1.0)

- Only `refs/heads/main` push is credentialed; PRs build but never push/deploy.
- ECR repos are **infra-owned** (created in Phase 5 precondition). A missing
  repo fails the build closed.
- ECS deploy: exactly one container named `app` (sidecars → V1.1); env/secrets/
  cpu/memory preserved from the running task def (image-only swap).
- CloudFront invalidation is not in V1.0 (ADR-0006).
- `@main` only in V1.0 (`@v1` tag pinning → V1.1 governance).
