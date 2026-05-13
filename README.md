# gygaxagain

A solo D&D campaign engine. Single-player, Claude-narrated. Deployed at [gygaxagain.com](https://gygaxagain.com) (custom domain pending DNS).

**Private alpha — not for general use.** Account creation is disabled in Devise; users are created manually.

## What this is

The player drives one primary PC; Claude narrates the world. Mechanical outcomes route through dice and oracle services. Hidden world state is enforced by data-model + UI separation: the player-facing context builder cannot reach `*_secrets` tables, so the narrator literally cannot leak what it was never given. The asymmetry between what the player knows and what's in the world is the load-bearing invariant of the design.

This is v2 — a Rails 8 web app rewrite of an earlier Claude Code / MCP-based proof of concept. The v1 final state is preserved at `git tag v1-final-poc`; the design history of both versions lives under `docs/superpowers/specs/`.

## Tech

Rails 8 · PostgreSQL · Bun · Tailwind CSS v4 · Propshaft · ViewComponent · Hotwire (Turbo + Stimulus) · RSpec · Solid Queue/Cache/Cable · Heroku · Cloudflare.

Authentication via Devise (signup disabled, recoverable enabled) — added in Phase 2.

## Local development

Prerequisites: Ruby 3.2+, Bun, PostgreSQL 14+.

```bash
bundle install
bun install
bin/rails db:create db:migrate
bin/dev
```

Visit `http://localhost:3000`.

- RSpec: `bundle exec rspec`
- RuboCop: `bin/rubocop`
- Brakeman: `bin/brakeman`
- erb_lint: `bundle exec erb_lint --lint-all`
- Lookbook (component previews, dev only): `http://localhost:3000/lookbook`

## Deploy

The Heroku app is `gygaxagain` (region `us`). Add the heroku remote:

```bash
heroku git:remote --app gygaxagain
```

Deploy:

```bash
git push heroku main
```

Buildpacks: `https://github.com/jakeg/heroku-buildpack-bun` then `heroku/ruby`. Postgres add-on: `heroku-postgresql:essential-0`.

## Roadmap

The v2 architectural commitments and phase progression are in [`docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md`](docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md). Each phase has its own design spec and implementation plan under `docs/superpowers/`.

GitHub issue [#1](https://github.com/barriault/gygaxagain/issues/1) is the parent tracking issue for v2 work; sub-issues #2–#10 cover each phase.

## Known limitations

See [`docs/known-limitations.md`](docs/known-limitations.md) for cross-cutting issues. The v1-era Claude Code regression noted there no longer affects v2 (the dependency on MCP-mediated subagents is gone).
