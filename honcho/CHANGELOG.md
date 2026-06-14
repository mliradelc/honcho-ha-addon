## [3.0.47] - 2026-06-14
### Fixed
- Dream specialists: set `THINKING_EFFORT=high` for both deduction and induction.
  Mistral Small 4 requires `reasoning_effort="high"` to engage reasoning; without
  it the deduction specialist silently produced zero output.
- honcho-max: expose `level` field in Conclusion API response so consumers
  (OpenConcho) can distinguish explicit/deductive/inductive/contradiction conclusions.

## [3.0.46]
### Fixed
- Add /v3/ nginx location to Honcho web UI

## [3.0.45] - 2026-06-11
### Fixed
- run.sh: create default `options.json` if missing to prevent downstream startup crashes
- config.yaml: mark `openconcho_enabled` as optional (`?`) to match operational modes

## [3.0.44] - 2026-06-10
### Fixed
- Hard error in run.sh on missing dialectic OVERRIDES to catch misconfiguration early

## [3.0.43] - 2026-06-08
### Fixed
- Fixed authentication propagation from Home Assistant options to dialectic model OVERRIDES

## [3.0.41]
### Fixed
- run.sh: nginx auth_block variable initialised as empty string

## [3.0.40] - 2026-05-31
### Changed
- OpenConcho removed from this add-on. Use the new standalone OpenConcho add-on.
- Dockerfile cleaned: no more multi-stage OpenConcho builder (faster builds).
- nginx restored to simple pass-through — no duplicate locations, no crash.

## [3.0.39] — 2026-05-31
### Fixed
- Add runtime nginx dedup guard: duplicate `location /v3/` blocks auto-removed at startup

## [3.0.38] - 2026-05-31
### Fixed
- Remove duplicate `location /v3/` block in nginx config
- Remove duplicate `config.js` write block in `start_nginx()`
- Remove duplicate `index.html` patch block in `start_nginx()`

## [3.0.37] - 2026-05-31
### Fixed
- nginx crash on startup: removed duplicate `location /v3/` block in `run.sh`
### Improved
- Smoke test (`validate.yml`) now generates and validates nginx config with `nginx -t`

## [3.0.36] - 2026-05-31
### Fixed
- OpenConcho Web UI: config.js now seeds `localStorage['openconcho:instances']` directly

## [3.0.35] - 2026-05-31
### Fixed
- OpenConcho Web UI: config.js now auto-detects HA ingress prefix at runtime

## [3.0.34] - 2026-05-31
### Fixed
- Docker build failure on aarch64: pinned OpenConcho builder to `--platform=linux/amd64`

## [3.0.33] - 2026-05-31
### Fixed
- OpenConcho web UI not loading: three SPA/nginx fixes in run.sh

## [3.0.32] - 2026-05-31
### Fixed
- MistralBackend Rule 5: remove trailing empty assistant stub before sending to Mistral

## [3.0.31] - 2026-05-31
### Fixed
- Dialectic missing credentials: apply_llm_config now sets OVERRIDES for all 5 dialectic levels

## [3.0.30] - 2026-05-31
### Fixed
- sync_source now uses git fetch + hard reset instead of stash/pull/stash pop

## [3.0.29] - 2026-05-31
### Fixed
- Added git checkout uv.lock before pull in sync_source

## [3.0.28] - 2026-05-31
### Fixed
- Deriver worker now started as background process
- config.toml template sets deriver enabled=true
- Deriver log tailed to stdout

## [3.0.27] - 2026-05-30
### Fixed
- Remap EMBEDDING_DIMENSIONS_MODE to EMBEDDING_MODEL_CONFIG__DIMENSIONS_MODE

## [3.0.26] - 2026-05-30
### Fixed
- Skip HNSW index recreation when EMBEDDING_VECTOR_DIMENSIONS > 2000

## [3.0.25] - 2026-05-30
### Fixed
- configure_embeddings.py --yes moved to main execution flow

## [3.0.24] - 2026-05-30
### Fixed
- Pass --yes flag to configure_embeddings.py

## [3.0.23] - 2026-05-30
### Fixed
- Run configure_embeddings.py after alembic upgrade head

## [3.0.22] - 2026-05-30
### Fixed
- Corrected VECTOR_DIMENSIONS to EMBEDDING_VECTOR_DIMENSIONS

## [3.0.21] - 2026-05-30
### Changed
- Default git_url now points to mliradelc/honcho-1 fork with mistral transport

## [3.0.20] - 2026-05-30
### Fixed
- apply_llm_config: replaced non-functional LLM_DEFAULT vars with per-subsystem MODEL_CONFIG overrides
- render_config: now rewrites config.toml when VECTOR_DIMENSIONS changes
- Added fix_vector_dimensions(): auto-ALTER TABLE pgvector columns on startup

## [3.0.19] - 2026-05-30
### Fixed
- Embedding env var mismatch: correct names now use EMBEDDING_MODEL_CONFIG__* prefix

## [3.0.18] - 2026-05-30
### Fixed
- Critical boot loop: orphaned nginx http block removed

## [3.0.17] - 2026-05-28
### Added
- OpenConcho web UI bundled in the Docker image

## [3.0.16] - 2026-05-28
### Fixed
- Removed provider-specific defaults from LLM/embedding configuration

## [3.0.15] - 2026-05-28
### Added
- Full parameter descriptions in translations/en.yaml

## [3.0.14] - 2026-05-28
### Added
- LLM and embedding configuration options in HA add-on UI

## [3.0.13] - 2026-05-28
### Fixed
- psql connection via TCP instead of Unix socket

## [3.0.12] - 2026-05-28
### Added
- honcho/DOCS.md and honcho/CHANGELOG.md

## [3.0.11] - 2026-05-28
### Fixed
- Postgres logs directory permissions

## [3.0.10] - 2026-05-28
### Fixed
- Run initdb/pg_ctl/psql as postgres user

## [3.0.9] - 2026-05-28
### Fixed
- Add PostgreSQL 15 bin dir to PATH

## [3.0.8] - 2026-05-28
### Fixed
- Remove /{arch} from image field, fix db_url/redis_url schema, fix CI manifest

## [3.0.7] - 2026-05-25
### Added
- Initial scaffold of Honcho Home Assistant add-on

## [0.0.0-pre-alpha] - 2026-05-25
- First development iteration — infrastructure scaffold before first tagged release
