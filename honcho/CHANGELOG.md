# Changelog

All notable changes to this project will be documented here. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Moved from HA-side Docker build to pre-built images on GHCR.
  Add-on now pulls `ghcr.io/mliradelc/honcho-ha-addon` instead of building locally.
- `release.yml` now builds multi-arch images (amd64, aarch64) and pushes to GHCR.
- Dockerfile updated with explicit `BUILD_FROM` default and required HA labels.
- `build.yaml` simplified to base image mapping only.

### Fixed
- `config.yaml` schema: replaced invalid `enum?` type with `str?` (HA Supervisor does not support enum schema types).

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
