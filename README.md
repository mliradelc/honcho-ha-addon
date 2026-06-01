# Honcho Home Assistant Add-on

Home Assistant add-on packaging [Honcho](https://github.com/plastic-labs/honcho), an open-source memory backend for AI agents, as a one-click install for Home Assistant OS.

Modelled on [`hermes-ha-addon`](https://github.com/WolframRavenwolf/hermes-ha-addon): the Docker image carries only system-level dependencies; the Honcho source itself is cloned into the persistent `/config/` volume at first boot, so upstream updates land on a simple add-on restart without rebuilding the Docker image.

## What you get

- Honcho FastAPI service exposed via Home Assistant ingress and (optionally) on dedicated ports.
- Embedded **PostgreSQL 15 with pgvector** and **Redis** by default — zero external dependencies.
- Optional external mode: point at an existing Postgres / Redis (e.g. the HA Postgres add-on).
- Optional `auto_update`: `git pull --ff-only` on every add-on restart.
- Optional ingress basic-auth via `access_password`.

## Install

1. **Add this repository to Home Assistant:**
   _Settings → Add-ons → Add-on Store → ⋮ → Repositories → paste:_
   `https://github.com/mliradelc/honcho-ha-addon`
2. Install the **Honcho** add-on from the store.
3. Open the add-on **Configuration** tab and review the options below.
4. Start the add-on, then click **Open Web UI** for the FastAPI Swagger docs.

## Configuration

| Option | Default | Description |
|---|---|---|
| `git_url` | `https://github.com/plastic-labs/honcho.git` | Upstream repository to clone. |
| `git_ref` | _(empty)_ | Optional branch / tag / commit. Empty = repo default branch. |
| `git_token` | _(empty)_ | Optional PAT for private mirrors. |
| `auto_update` | `false` | If `true`, runs `git pull --ff-only` at every restart. |
| `db_mode` | `embedded` | `embedded` ships an in-container Postgres+pgvector. `external` uses `db_url`. |
| `db_url` | _(empty)_ | `postgres://…` URL when `db_mode=external`. |
| `redis_mode` | `embedded` | `embedded` ships an in-container Redis. `external` uses `redis_url`. |
| `redis_url` | _(empty)_ | `redis://…` URL when `redis_mode: external`. |
| `api_port` | `8000` | Internal port the Honcho FastAPI app listens on. |
| `access_password` | _(empty)_ | If set, nginx basic-auth on ingress. |
| `env_vars` | `[]` | List of `{name, value}` pairs injected into Honcho's `.env`. **Recommended for self-hosted deployments:** add these entries to enable memory extraction, card generation, summaries, deduction, and induction (all disabled by upstream defaults): |

## Architecture

```
HA ingress  ──►  nginx  ──►  Honcho FastAPI (127.0.0.1:${api_port})
                                  │
                                  ├──►  Postgres 15 + pgvector
                                  │     (embedded → 127.0.0.1:5433, data in /config/honcho/pgdata)
                                  │     (external → ${db_url})
                                  │
                                  └──►  Redis
                                        (embedded → 127.0.0.1:6380, data in /config/honcho/redis)
                                        (external → ${redis_url})

Source code lives in /config/honcho/source (clone of git_url@git_ref).
Virtualenv in     /config/honcho/source/.venv (uv-managed).
```

## Updating Honcho

- **Manual:** restart the add-on (the source is re-checked).
- **Automatic:** flip `auto_update: true`.
- **Pin a version:** set `git_ref` to a tag (e.g. `v3.0.7`) or commit SHA.

## Releases & security updates

Docker images are built automatically on GitHub Actions and pushed to **GitHub Container Registry** (`ghcr.io/mliradelc/honcho-ha-addon`). The add-on pulls pre-built images rather than building locally — faster installs and no Docker-in-Docker build issues.

System dependencies (Postgres, Redis, pgvector, base image) are tracked by:

- **`upstream-watch.yml`** — weekly check for new stable releases of Redis and pgvector.
- **`release.yml`** — on every GitHub Release, builds multi-arch (`amd64`, `aarch64`) images and pushes to GHCR with both versioned and `latest` tags.
- **Dependabot** tracks the HA base image for OS CVEs independently.

To trigger a new build: create a GitHub Release with a tag matching the `version:` field in `honcho/config.yaml`. The Supervisor checks for new image tags automatically.

## Hermes integration

### Recommended env_vars for self-hosted

Honcho's upstream defaults disable memory extraction, peer card generation, summaries, deduction, and induction — these are designed for high-throughput cloud deployments. Self-hosted add‑ons must enable them explicitly. Add the following entries under `env_vars` in the add‑on configuration:

```yaml
env_vars:
  - name: DERIVER_FLUSH_ENABLED
    value: "true"
  - name: PEER_CARD_ENABLED
    value: "true"
  - name: SUMMARY_ENABLED
    value: "true"
  - name: DREAM_ENABLED
    value: "true"
  - name: DREAM_SURPRISAL__ENABLED
    value: "true"
  - name: EMBEDDING_VECTOR_DIMENSIONS
    value: "4096"
  - name: EMBEDDING_DIMENSIONS_MODE
    value: "never"
```

These are **injected into the container automatically at every boot** (the `run.sh` appends them to Honcho's `.env`), so they cannot be lost across restarts or updates. The `DREAM_*` flags enable the induction/abduction/consolidation reasoning layers.

This add-on pairs with [Hermes Agent](https://github.com/NousResearch/hermes-agent)'s `memory.provider: honcho` setting. Point Hermes at `http://homeassistant.local:8000` (internal Honcho API).

## License

Apache 2.0. Bundled Honcho upstream is also Apache 2.0. See `LICENSE`.

## Credits

- Pattern adapted from [`WolframRavenwolf/hermes-ha-addon`](https://github.com/WolframRavenwolf/hermes-ha-addon).
- Honcho by [Plastic Labs](https://plasticlabs.ai).
