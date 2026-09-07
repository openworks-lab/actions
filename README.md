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

`dockerfile-build-and-push.yml` pushes `main-<sha>` (immutable) + `:latest`
(mutable). Set `push_latest: false` on **prod** callers to emit only the
immutable tag — a re-supplied old build can otherwise move `:latest` backward.
Deploy always by the explicit `main-<sha>` URI, never `:latest`.

## HTML 재검증 선택 적용

`static-publish-to-s3.yml`의 `revalidate-html: true`는 `.html` 파일에만
`Cache-Control: no-cache, max-age=0, must-revalidate`를 적용한다. 기본값은 `false`다.
일반 파일을 먼저 동기화한 뒤 HTML을 동기화·재업로드한다. 내용이 같은 HTML도
메타데이터가 갱신되며, 삭제된 HTML도 기존 `--delete` 계약대로 제거된다.
JS·CSS·이미지의 캐시 정책은 변경하지 않는다. `publish: false`는 업로드하지 않는다.

호출 저장소는 DEV에서 S3와 공개 URL의 응답 헤더, 동일 브라우저 프로필의 새 탭,
화면 이동을 확인한 뒤 PROD에 배포한다. 이미 열린 페이지나 기존 브라우저 캐시를
원격으로 교체하는 기능은 아니다. 공용 workflow를 먼저 병합한 뒤 호출부 옵션을 병합한다.

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
