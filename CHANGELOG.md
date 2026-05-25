# Changelog

All notable changes to this project will be documented here. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.7] - 2026-05-25

### Added
- Initial scaffold of the Honcho Home Assistant add-on.
- Embedded PostgreSQL 15 + pgvector and Redis by default.
- Optional external database / Redis mode via `db_url` / `redis_url`.
- Optional `auto_update`: `git pull --ff-only` on every restart.
- nginx reverse proxy on HA ingress with optional basic-auth (`access_password`).
- `upstream-watch.yml` GitHub Action: weekly drift detection for Postgres, Redis and pgvector.
- `release.yml` GitHub Action: cuts a GitHub release on every `honcho/config.yaml` version bump.
- Dependabot config for the HA base image.

### Known issues
- `.github/dependabot.yml` is a placeholder — needs the proper v2 schema before merging substantive changes.
- `run.sh` does not yet implement nginx basic-auth when `access_password` is set.
- No CI step builds the Docker image — the add-on must be tested manually in Home Assistant for now.
