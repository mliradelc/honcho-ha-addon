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


## LLM Configuration (Deriver)

Honcho's **Deriver** automatically extracts facts and memories from conversations using an LLM. Configure it to use Hermes Agent's OpenAI-compatible API:

| Option | Default | Description |
|---|---|---|
| `llm_transport` | `openai` | LLM transport: `openai`, `anthropic`, or `gemini` |
| `llm_model` | `hermes-agent` | Model name passed to the LLM API |
| `llm_base_url` | `https://hermes.liradelcanto.com/v1` | OpenAI-compatible base URL — defaults to Hermes |
| `llm_api_key` | *(empty)* | API key / Bearer token for the LLM endpoint |
| `embedding_transport` | `openai` | Embedding transport: `openai` or `gemini` |
| `embedding_model` | `text-embedding-3-small` | Embedding model name |
| `embedding_base_url` | *(empty)* | Override base URL for the embedding endpoint |
| `embedding_api_key` | *(empty)* | API key for the embedding endpoint |

### Pointing at Hermes Agent

Set `llm_api_key` to your `API_SERVER_KEY` from Hermes's `.env`, and `llm_base_url` to `https://hermes.liradelcanto.com/v1`. Hermes will handle model routing and fallback transparently.

> **Embeddings note:** Hermes's API server does not expose an embeddings endpoint. Leave `embedding_base_url` empty and set `embedding_api_key` to an OpenAI API key, or set `EMBED_MESSAGES=false` in `env_vars` to disable message embedding entirely.

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
