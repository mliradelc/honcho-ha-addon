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
