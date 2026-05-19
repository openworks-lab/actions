# Onboarding a repo to openworks-lab/actions

## 1. Get your PRODUCT repo into the deployer trust (one-time infra PR)
`{dev,prod}-gha-deployer` only accepts repos whose numeric id is in
`product_repo_ids`. The actions repo id is **never** added there.

```
gh api repos/openworks-lab/<your-product-repo> --jq .id
```
PR that id into `openworks-lab/infra` → `bootstrap/product_repos.auto.tfvars`,
1 review, merge, infra `apply` refreshes trust.

## 2. ECR repo is infra-owned (Phase 5 precondition)
The reusable does NOT create ECR repos. Infra must have created
`<env>-<your-repo>/<service_slug>` (tagged `Env=<env>`) with a lifecycle
policy first, or the build fails closed.

## 3. Copy a caller template
From `docs/caller-template-*.yml`. Pass only `env` (+ `service_slug` /
`s3-bucket`). You do NOT pass a role ARN — the reusable derives
`<env>-gha-deployer` internally. Keep `@main` for V1.0.

## 4. Constraints (V1.0)
- Only `refs/heads/main` push is credentialed; PRs build only.
- ECS deploy: exactly one container named `app`; env/secrets/cpu/memory
  preserved from the running task def. Shape changes go via infra Terraform.
- S3 bucket must match `openworks-<env>-*`. CloudFront invalidation is not
  in V1.0 (ADR-0006).
- Image identity is fixed: `<env>-<your-repo>/<service_slug>`, tag
  `main-<sha>` / `latest`.
