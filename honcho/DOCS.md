# Honcho

[Honcho](https://github.com/plastic-labs/honcho) is an open-source **memory and user-state backend** for AI agents, built by [Plastic Labs](https://plasticlabs.ai). It gives your AI assistants long-term memory and per-user context, backed by Postgres + pgvector for semantic search.

This add-on packages Honcho as a one-click install for Home Assistant OS, modelled on the Hermes Agent add-on pattern: the Docker image ships only system dependencies; Honcho itself is cloned into your persistent `/config/` volume at first boot and updated on restart.

## Features

- **Embedded Postgres 15 + pgvector** and **Redis** — zero external dependencies out of the box
- **External mode** — optionally point at an existing Postgres/Redis add-on
- **Auto-update** — `git pull` on every restart to stay current with upstream
- **Ref pinning** — lock to a specific tag or commit via `git_ref`
- **HA ingress** — Honcho FastAPI (including `/docs` Swagger UI) served through the sidebar
- **Optional basic auth** — protect the ingress with `access_password`

## Configuration

| Option | Default | Description |
|---|---|---|
| `git_url` | `https://github.com/plastic-labs/honcho.git` | Upstream repo to clone |
| `git_ref` | *(empty — default branch)* | Branch, tag, or commit to pin |
| `git_token` | *(empty)* | PAT for private mirrors |
| `auto_update` | `false` | Pull latest on every restart |
| `db_mode` | `embedded` | `embedded` or `external` |
| `db_url` | *(empty)* | Postgres URL when `db_mode: external` |
| `redis_mode` | `embedded` | `embedded` or `external` |
| `redis_url` | *(empty)* | Redis URL when `redis_mode: external` |
| `api_port` | `8000` | Internal port for the Honcho FastAPI |
| `access_password` | *(empty)* | Basic-auth password for the ingress |
| `env_vars` | `[]` | Extra env vars injected into Honcho (e.g. `OPENAI_API_KEY`) |

## First start

The default configuration requires no changes. On first boot the add-on will:

1. Initialise a Postgres 15 + pgvector data directory under `/config/honcho/pgdata/`
2. Start an embedded Redis under `/config/honcho/redis/`
3. Clone Honcho from GitHub into `/config/honcho/source/`
4. Install Python dependencies with `uv`
5. Run Alembic database migrations
6. Start the FastAPI server — accessible via the **Open Web UI** button

## Hermes Agent integration

Point [Hermes Agent](https://github.com/NousResearch/hermes-agent) at this add-on by setting `memory.provider: honcho` in your Hermes config, with the base URL pointing at the ingress or direct port.

## Support

- Add-on issues: [github.com/mliradelc/honcho-ha-addon](https://github.com/mliradelc/honcho-ha-addon/issues)
- Honcho upstream: [github.com/plastic-labs/honcho](https://github.com/plastic-labs/honcho)
