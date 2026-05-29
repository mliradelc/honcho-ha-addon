# Changelog

All notable changes to this project will be documented here. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.19] - 2026-05-30

### Fixed
- **Embedding env var mismatch** (`Error code: 401 - Incorrect API key ... api.openai.com`):
  `run.sh` was writing `EMBEDDING_DEFAULT_TRANSPORT`, `EMBEDDING_OPENAI_BASE_URL`, and
  `EMBEDDING_OPENAI_API_KEY` — env var names Honcho does not read. Honcho's
  `EmbeddingSettings` uses pydantic-settings with `env_prefix="EMBEDDING_"` and
  `env_nested_delimiter="__"`, so the correct names are
  `EMBEDDING_MODEL_CONFIG__TRANSPORT`, `EMBEDDING_MODEL_CONFIG__MODEL`,
  `EMBEDDING_MODEL_CONFIG__OVERRIDES__BASE_URL`, and
  `EMBEDDING_MODEL_CONFIG__OVERRIDES__API_KEY`. Without these, Honcho fell through to
  its default OpenAI transport with no base_url, causing all conclusion/search writes
  to fail with a 401 against `api.openai.com`.
- Stale-entry cleanup regex in `apply_llm_config()` now targets
  `^EMBEDDING_MODEL_CONFIG` instead of `^EMBEDDING_` to avoid accidentally stripping
  unrelated `EMBEDDING_*` env vars set by users.

## [3.0.18] - 2026-05-30

### Fixed
- **Critical boot loop** (`/run.sh: line 289: http: command not found`): orphaned
  nginx `http { }` config block was accidentally left outside the `start_nginx()`
  function in v3.0.17, causing bash to attempt to execute `http` as a command on
  every start. Add-on entered an infinite s6 restart loop. Lines 289–323 removed.

## [3.0.17] - 2026-05-28

### Added
- **OpenConcho web UI** bundled in the Docker image.
  - Multi-stage Dockerfile: Node 22 + pnpm builds the OpenConcho SPA (pinned to
    v0.12.1), final image copies `packages/web/dist/` to `/var/www/openconcho`.
  - nginx serves OpenConcho at `/` and reverse-proxies `/api/` to the Honcho
    FastAPI — same-origin, no CORS configuration needed.
  - New `openconcho_enabled` option (default: `true`) — disable to expose the
    raw Honcho API directly.
  - OpenConcho connects to Honcho at the `/api/` path automatically when served
    from the add-on ingress.

## [3.0.16] - 2026-05-28

### Fixed
- Removed provider-specific defaults from LLM/embedding configuration options.
  Fields now default to empty — users configure their own provider, endpoint, and key.
- Removed all provider-specific references from UI descriptions (`translations/en.yaml`).

### Changed
- Moved initial development notes from `[Unreleased]` to `[0.0.0-pre-alpha]` at the
  bottom of the changelog.

## [3.0.15] - 2026-05-28

### Changed
- Default LLM/embedding options added to the HA add-on configuration tab.
  Defaults are intentionally left blank — configure with your own provider.

### Added
- Full parameter descriptions in `translations/en.yaml` — every configuration
  option now shows a human-readable name and description in the HA add-on UI.

## [3.0.14] - 2026-05-28

### Added
- LLM and embedding configuration options in the HA add-on UI:
  `llm_transport`, `llm_model`, `llm_base_url`, `llm_api_key`,
  `embedding_transport`, `embedding_model`, `embedding_base_url`,
  `embedding_api_key`. Defaults are pre-configured to point at Hermes Agent
  (`https://hermes.liradelcanto.com/v1`).
- `apply_llm_config()` in `run.sh` — writes the configured values into
  Honcho's `.env` before startup, mapping to `LLM_OPENAI_BASE_URL`,
  `LLM_OPENAI_API_KEY`, `LLM_DEFAULT_MODEL`, and their embedding equivalents.
- Updated `DOCS.md` with full LLM/Deriver configuration guide.

## [3.0.13] - 2026-05-28

### Fixed
- Add `-h 127.0.0.1` to the `psql` call so it connects via TCP rather than
  the Unix socket. pg_ctl was started with `-k /tmp` (socket in /tmp) but psql
  defaults to `/var/run/postgresql/` — causing an immediate connection failure
  after Postgres started successfully.

## [3.0.12] - 2026-05-28

### Added
- `honcho/DOCS.md` — full long description, configuration table, and first-start
  guide shown in the HA add-on store.
- `honcho/CHANGELOG.md` — changelog now located inside the add-on directory so
  HA Supervisor can display release notes in the UI.

### Fixed
- `url` in `config.yaml` now points to the add-on repository instead of the
  upstream Honcho project.
- Improved one-line `description` in `config.yaml` for the add-on store card.

## [3.0.11] - 2026-05-28

### Fixed
- `chown postgres` the logs directory and pre-create `postgres.log` owned by
  postgres before calling `pg_ctl start`, resolving `Permission denied` that
  prevented Postgres from starting in 3.0.10.
- Tail `postgres.log` to stdout so Postgres output appears in the HA add-on
  log viewer alongside the rest of the add-on output.

## [3.0.10] - 2026-05-28

### Fixed
- Run initdb, pg_ctl, and psql as the postgres user via `su -s /bin/bash postgres -c`
  in run.sh. HA add-on containers run as root and PostgreSQL refuses to initialise a
  data directory as root, causing a persistent boot loop.

## [3.0.9] - 2026-05-28

### Fixed
- Add PostgreSQL 15 bin dir to PATH in Dockerfile (/usr/lib/postgresql/15/bin)
  so that initdb, pg_ctl and psql resolve correctly at runtime (boot-loop fix).

## [3.0.8] - 2026-05-28

### Fixed
- Remove /{arch} from image: field — HA Supervisor selects arch from multi-arch manifest automatically; sub-package path caused 403 on install.
- Change db_url and redis_url schema from url? to str? — HA URL validator rejects empty strings, preventing add-on start with default config.
- Fix multi-arch manifest CI: use --format .Manifest.Digest instead of JSON manifest-list parsing.

### Changed
- Bump actions/checkout from v4 to v6 (Node.js 24, improved credential storage).

## [3.0.7] - 2026-05-25

### Added
- Initial scaffold of the Honcho Home Assistant add-on.
- Embedded PostgreSQL 15 + pgvector and Redis by default.
- Optional external database / Redis mode via `db_url` / `redis_url`.
- Optional `auto_update`: `git pull --ff-only` on every restart.
- nginx reverse proxy on HA ingress with optional basic-auth (`access_password`).
- `upstream-watch.yml` GitHub Action: weekly drift detection for Postgres, Redis and pgvector.
- `release.yml` GitHub Action: builds multi-arch Docker images and pushes to GHCR.
- Dependabot config for the HA base image.

### Known issues
- No CI step builds the Docker image — the add-on must be tested manually in Home Assistant for now.

## [0.0.0-pre-alpha] - 2026-05-25

> First development iteration — infrastructure scaffold before the first tagged release.

### Changed
- Moved from HA-side Docker build to pre-built images on GHCR.
  Add-on now pulls `ghcr.io/mliradelc/honcho-ha-addon` instead of building locally.
- `release.yml` now builds multi-arch images (amd64, aarch64) and pushes to GHCR.
- Dockerfile updated with explicit `BUILD_FROM` default and required HA labels.
- `build.yaml` simplified to base image mapping only.

### Fixed
- `config.yaml` schema: replaced invalid `enum?` type with `str?` (HA Supervisor does not support enum schema types).
