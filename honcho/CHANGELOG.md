# Changelog

All notable changes to this project will be documented here. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.32] - 2026-05-31

### Fixed
- **MistralBackend Rule 5**: `_sanitize_messages()` now removes a trailing empty
  assistant stub before sending messages to Mistral. Rule 3 (added in a prior release)
  appended an empty assistant turn after a trailing `tool` message — but Mistral's
  server rejects any request where the final message has `role: assistant` with
  `add_generation_prompt=True`, returning:
  `"Cannot set add_generation_prompt to True when the last message is from the assistant"`
  The stub is unnecessary: Mistral generates the assistant reply itself. Removing it
  fixes `honcho_reasoning` and `honcho_profile` (peer card) calls that use the
  dialectic agentic tool loop.

## [3.0.31] - 2026-05-31

### Fixed
- **Dialectic missing credentials** (`AuthenticationError` — connecting to OpenAI instead of
  configured endpoint): `apply_llm_config()` was setting `TRANSPORT` and `MODEL` for each
  dialectic level but omitting `OVERRIDES__BASE_URL` and `OVERRIDES__API_KEY`. Without these,
  Honcho's pydantic-settings fell through to the OpenAI default, ignoring `llm_base_url` and
  `llm_api_key` from the add-on config. All five levels (minimal/low/medium/high/max) now
  receive the full four-field override block, matching the deriver/summary/dream subsystems.
  This fixes `honcho_reasoning` and `honcho_profile` (peer card) returning empty results.

## [3.0.30] - 2026-05-31

### Fixed
- `sync_source()` in `run.sh` now uses `git fetch && git reset --hard origin/main` instead
  of `git stash / git pull / git stash pop`. The stash approach failed silently when the
  source directory had uncommitted modifications (editable-install `.pth` files, `uv.lock`
  changes) — leaving the container running stale code despite reporting a successful update.
  Hard reset guarantees a clean working tree on every startup.

## [3.0.29] - 2026-05-31

### Fixed
- Added `git checkout -- uv.lock` before `git pull` in `sync_source()` to prevent the
  `Your local changes … would be overwritten` error that blocked auto-update when
  `uv pip install -e .` modified `uv.lock` as a side effect of the editable install.

## [3.0.28] - 2026-05-31

### Fixed
- **Deriver worker never started**: `run.sh` now launches `python -m src.deriver` as a
  background process before starting Uvicorn. Previously the deriver process was never
  spawned — all conversation work units were queued but never consumed, leaving Honcho
  memory permanently empty.
- **Deriver disabled by default**: `config.toml` template now sets `enabled = true` for
  the deriver section. The upstream default (`enabled = false`) silently suppressed memory
  extraction even if the process had been started.
- Deriver log is now tailed to stdout so it appears in the HA add-on log viewer alongside
  the rest of the add-on output.

## [3.0.27] - 2026-05-30

### Fixed
- `apply_llm_config()` in `run.sh` now remaps `EMBEDDING_DIMENSIONS_MODE` (user-facing
  add-on env_var name) to `EMBEDDING_MODEL_CONFIG__DIMENSIONS_MODE` (the pydantic-settings
  nested field that Honcho actually reads). Without this, `dimensions=4096` was sent to
  every KI:Connect embedding call, which rejects that parameter — causing HTTP 500 on
  both the dialectic (`/peers/{id}/chat`) and conclusions (`/workspaces/{id}/conclusions`)
  endpoints.

## [3.0.26] - 2026-05-30

### Fixed
- `scripts/configure_embeddings.py` in `honcho-max`: skip HNSW index recreation when
  `EMBEDDING_VECTOR_DIMENSIONS > 2000`. pgvector's HNSW index type has a hard 2000-dim
  limit — attempting to recreate it after resizing columns to 4096 raised
  `ProgramLimitExceeded: column cannot have more than 2000 dimensions for hnsw index`.
  Index is now skipped with a warning; use IVFFlat manually for high-dimensional ANN search.

## [3.0.25] - 2026-05-30

### Fixed
- `configure_embeddings.py --yes` call moved to the **main execution flow** in `run.sh`,
  outside the marker-gated `ensure_installed()` block. Previously, if the install marker
  was unchanged (same git HEAD), `ensure_installed()` returned early and the script never
  ran — leaving pgvector columns at 1536 on every restart. Now runs unconditionally after
  `ensure_installed`, before `render_config`. The script is idempotent (no-op when dims
  already match).

## [3.0.24] - 2026-05-30

### Fixed
- Pass `--yes` flag to `configure_embeddings.py` — the script prompts `apply? [y/N]`
  interactively and crashed with `EOFError: EOF when reading a line` when run in a
  non-TTY container environment.
- Remove `fix_vector_dimensions()` call from main flow — the raw SQL `ALTER TABLE`
  fails when an HNSW index exists (pgvector HNSW hard limit: 2000 dims).
  `configure_embeddings.py` handles this correctly by dropping the index first.

## [3.0.23] - 2026-05-30

### Fixed
- Run `configure_embeddings.py --yes` after `alembic upgrade head` in `ensure_installed()`.
  Alembic creates pgvector columns at the hardcoded default of 1536 dims. The script
  resizes them to `EMBEDDING_VECTOR_DIMENSIONS` immediately after migration, preventing
  the startup `StartupValidationError: public.documents.embedding dim (1536) does not
  match EMBEDDING_VECTOR_DIMENSIONS (4096)`.

## [3.0.22] - 2026-05-30

### Fixed
- `render_config` and `fix_vector_dimensions`: were reading `VECTOR_DIMENSIONS`
  (non-existent) — corrected to `EMBEDDING_VECTOR_DIMENSIONS` per Honcho's
  `.env.template`. Set `EMBEDDING_VECTOR_DIMENSIONS=4096` in env_vars when using
  KI:Connect `e5-mistral-7b-instruct`.

## [3.0.21] - 2026-05-30

### Changed
- Default `git_url` now points to `mliradelc/honcho-1` fork which adds the
  `mistral` transport — set `llm_transport = mistral` in add-on config to
  enable Mistral-strict role-sequence sanitisation (fixes `Unexpected role
  'user' after role 'tool'` 400 errors from KI:Connect Mistral endpoints)

## [3.0.20] - 2026-05-30

### Fixed
- `apply_llm_config`: replaced non-functional `LLM_DEFAULT_TRANSPORT`/`LLM_DEFAULT_MODEL` vars with correct
  per-subsystem `MODEL_CONFIG__*` overrides — Deriver, Dialectic (all 5 levels), Summary, and Dream now
  route to the configured LLM instead of defaulting to `gpt-5.4-mini`
- `render_config`: was a no-op if `config.toml` already existed; now rewrites it when `VECTOR_DIMENSIONS`
  changes, preventing stale dimension mismatches after config updates
- Added `fix_vector_dimensions()`: auto-`ALTER TABLE` to resize pgvector columns to match `VECTOR_DIMENSIONS`
  on startup, resolving "Embedding dimension mismatch: Expected 1536, got 4096" on existing installs

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
