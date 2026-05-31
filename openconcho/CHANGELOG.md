# OpenConcho Add-on Changelog

## [1.0.0] - 2026-05-31
### Added
- Initial release: OpenConcho web UI as a standalone HA add-on.
- Configurable `honcho_url` points at your Honcho add-on (default: `http://homeassistant:8000`).
- `config.js` bootstraps `localStorage` so the app connects automatically on first load.
- Optional basic auth via `access_password`.
- nginx proxy at `/api/` removes CORS — all API calls are same-origin.
