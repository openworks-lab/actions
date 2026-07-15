# Changelog

Keep a Changelog format. SemVer on git tags lands in V1.1 (no tags in V1.0).

## [Unreleased]

### Changed
- `dockerfile-build-and-push.yml` — `push_latest` 입력 추가 (default `true`,
  하위호환). `false` 면 불변 `main-<sha>` 만 emit 하고 가변 `:latest` 는 생략한다.
  prod 는 `:latest` 역행(구버전 재공급 시)을 원천 차단하려 `false` 를 넘긴다.
  self-test 에 `build-only-docker-no-latest`(opt-out 경로 스모크) 추가.

### Added
- `dockerfile-build-and-push.yml` — Dockerfile build + ECR push (OIDC,
  internal role), identity derived from `github.repository`, infra-owned ECR
  (describe-only, fail-close if missing), tags `main-<sha>`+`latest`
  (`:latest` 는 `push_latest` 로 opt-out 가능 — 위 Changed 참조).
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
