# Changelog

Keep a Changelog format. SemVer on git tags lands in V1.1 (no tags in V1.0).

## [Unreleased]

### Added
- `dockerfile-build-and-push.yml` — Dockerfile build + ECR push (OIDC,
  internal role), identity derived from `github.repository`, infra-owned ECR
  (describe-only, fail-close if missing), tags `main-<sha>`+`latest`.
- `static-publish-to-s3.yml` — SPA build + S3 sync (OIDC, internal role,
  `openworks-<env>-*` bucket guard). CloudFront invalidation NOT in V1.0.
- `ecs-deploy.yml` — drift-safe image swap, double-guard fail-close,
  per-service concurrency, image-prefix validation.
- `.github/actions/ecs-taskdef-transform` composite action (no caller
  checkout) + bash unit test.
- `self-test.yml` (build-only + unit + negative-OIDC + job_workflow_ref
  match + aggregate `selftest-gate`).
- Caller templates + onboarding.

**Notes:**
- Reusable filenames locked by deployed `{dev,prod}-gha-deployer` trust.
- Positive OIDC proof requires a *product* repo id in `product_repo_ids`
  (Phase 5). The actions repo id is never added there.
