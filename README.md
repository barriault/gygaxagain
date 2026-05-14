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

Visit `http://lvh.me:3000` (apex) or `http://admin.lvh.me:3000` (admin subdomain).

`lvh.me` is a public DNS service that resolves `*.lvh.me` to `127.0.0.1`,
so subdomain routing works locally without `/etc/hosts` edits.

- RSpec: `bundle exec rspec`
- RuboCop: `bin/rubocop`
- Brakeman: `bin/brakeman`
- erb_lint: `bundle exec erb_lint --lint-all`
- Lookbook (component previews, dev only): `http://lvh.me:3000/lookbook`

## Authentication

Alpha is invite-only; signup is disabled in Devise. Create users manually:

```bash
bin/rails users:create EMAIL=jane@example.com PASSWORD=correct-horse-battery-staple
```

On Heroku:

```bash
heroku run rake users:create EMAIL=... PASSWORD=... -a gygaxagain
```

Sign in at `https://gygaxagain.com/users/sign_in`. The session is shared
across `gygaxagain.com` and `admin.gygaxagain.com` via a cookie scoped
to `.gygaxagain.com`.

Password reset is wired but requires SMTP config (`SMTP_HOST`, `SMTP_PORT`,
`SMTP_USER`, `SMTP_PASS`, `MAIL_FROM` env vars on Heroku). These are blank
in alpha; reset requests appear to succeed but no email is sent.

### Campaigns

Campaign authoring lives on the admin subdomain at
`https://admin.gygaxagain.com/campaigns`. Each user owns their campaigns;
there is no sharing. The first time you sign in with no campaigns, you'll
land on the new-campaign form on admin.

The play surface for a campaign is at
`https://gygaxagain.com/campaigns/:id/play`. In Phase 3 this is a
placeholder; the real chat-style UI lands in Phase 6. Visiting a play URL
sets your `last_played_campaign_id`, so subsequent sign-ins drop you
straight back into that campaign.

## Operations

### LLM diagnostics

The admin diagnostics tool at `https://admin.gygaxagain.com/diagnostics/llm`
lets a signed-in user submit a free-form prompt to the configured LLM
provider, see the response, and inspect the `llm_calls` row that was
written.

Requires `ANTHROPIC_API_KEY` to be set in the environment. In dev, copy
`.env.example` to `.env` (gitignored) and fill in a real key. In prod,
set via `heroku config:set ANTHROPIC_API_KEY=sk-ant-...`.

The model dropdown is populated from `Llm::Pricing::RATES.keys`. Adding a
new model in `app/lib/llm/pricing.rb` automatically exposes it in the UI.

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

The Heroku app serves two domains: `gygaxagain.com` (play surface) and
`admin.gygaxagain.com` (campaign management). Both terminate at the same
dyno; Rails subdomain routing dispatches.

## Roadmap

The v2 architectural commitments and phase progression are in [`docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md`](docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md). Each phase has its own design spec and implementation plan under `docs/superpowers/`.

GitHub issue [#1](https://github.com/barriault/gygaxagain/issues/1) is the parent tracking issue for v2 work; sub-issues #2–#10 cover each phase.

## Known limitations

See [`docs/known-limitations.md`](docs/known-limitations.md) for cross-cutting issues. The v1-era Claude Code regression noted there no longer affects v2 (the dependency on MCP-mediated subagents is gone).
