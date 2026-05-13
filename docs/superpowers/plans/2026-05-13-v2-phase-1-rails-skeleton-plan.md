# v2 Phase 1 — Rails skeleton + landing page on Heroku — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the v2 codebase. By the end of this plan, `https://gygaxagain.com` resolves to a Rails 8 app on Heroku showing a placeholder landing page, with CI running RSpec on every push, and v1 runtime artifacts cleaned out of the working tree.

**Architecture:** Greenfield Rails 8 app at the repo root, sharing space with preserved v1 content (`docs/`, `world/`, `party/`, `sessions/`, `library/lore/`, `references/`). View layer uses ViewComponent + Tailwind. Tests use RSpec. Deployed to Heroku with Postgres on the `essential-0` tier, fronted by Cloudflare with CNAME flattening on the apex.

**Tech Stack:** Rails 8.x, PostgreSQL, Bun (JS bundling), Tailwind CSS, Propshaft, ViewComponent, Lookbook (dev), RSpec, factory_bot, shoulda-matchers, Capybara, Brakeman, RuboCop (rails-omakase), erb_lint, Bullet (dev), annotaterb (dev), dotenv-rails (dev). Heroku for hosting; Cloudflare for DNS; GitHub Actions for CI.

**Closes:** Issue #2.

---

## File structure

After Phase 1 completes, the working tree contains:

**Preserved from v1:**
- `docs/superpowers/specs/` — design history including the v2 Phase 0 spec
- `docs/superpowers/plans/` — implementation plans (this file lives here)
- `docs/known-limitations.md`, `docs/resume-on-new-machine.md`
- `world/`, `party/`, `sessions/`, `library/lore/`, `references/` — content for future migration
- `.gitignore` (extended by `rails new`)

**Deleted from v1:**
- `.claude/` directory (Claude Code agent definitions, slash commands, settings)
- `CLAUDE.md`
- `dm/` directory (hidden world state files; preserved in git history via `v1-final-poc` tag)
- `tools/dm-fs-mcp/` (Python MCP server)
- `.mcp.json`
- `pytest.ini`, `.pytest_cache/`, `.venv/` (Python tooling)
- `SPEC.md` (v1 spec; redundant with `docs/superpowers/specs/`)
- `meta/` (v1 meta files; redundant)

**Created by Rails:**
- `app/` (controllers, models, views, components, jobs, mailers, helpers)
- `config/` (routes, environments, initializers, database.yml, application.rb)
- `db/` (migrations, schema.rb, seeds.rb)
- `lib/`, `public/`, `tmp/`, `vendor/`, `bin/`, `storage/`
- `Gemfile`, `Gemfile.lock`, `package.json`, `bun.lockb`
- `config.ru`, `Rakefile`, `.ruby-version`

**Phase 1-specific files:**
- `app/controllers/pages_controller.rb`
- `app/components/pages/home_component.rb`
- `app/components/pages/home_component.html.erb`
- `config/routes.rb` (root route)
- `spec/requests/pages_spec.rb`
- `spec/rails_helper.rb`, `spec/spec_helper.rb` (RSpec)
- `.rspec`
- `.erb-lint.yml`
- `.github/workflows/ci.yml`
- `Procfile`
- `bin/build` (Heroku build script with bun installation)
- `public/robots.txt` (deny-all)
- `README.md` (rewritten for v2)

---

## Task 1: Tag v1, clean working tree

**Files:**
- Tag: `v1-final-poc` at current HEAD
- Delete: `.claude/`, `CLAUDE.md`, `dm/`, `tools/dm-fs-mcp/`, `.mcp.json`, `pytest.ini`, `.pytest_cache/`, `.venv/`, `SPEC.md`, `meta/`
- Modify: `.gitignore` (remove Python-specific entries; will be replaced by Rails-flavored gitignore in Task 2)

- [ ] **Step 1: Verify clean working tree**

Run:
```
git -C /Users/barriault/dnd/gygaxagain status
```
Expected: `nothing to commit, working tree clean`

- [ ] **Step 2: Tag the v1 final state**

Run:
```
git -C /Users/barriault/dnd/gygaxagain tag v1-final-poc HEAD
git -C /Users/barriault/dnd/gygaxagain push origin v1-final-poc
```
Expected: `* [new tag] v1-final-poc -> v1-final-poc` in push output.

- [ ] **Step 3: Verify tag is pushed**

Run:
```
git -C /Users/barriault/dnd/gygaxagain ls-remote --tags origin | grep v1-final-poc
```
Expected: one line with the tag SHA + `refs/tags/v1-final-poc`.

- [ ] **Step 4: Delete v1 Claude Code runtime**

Run:
```
cd /Users/barriault/dnd/gygaxagain && rm -rf .claude/ CLAUDE.md dm/ tools/dm-fs-mcp/ .mcp.json
```
Expected: no output (silent success).

- [ ] **Step 5: Delete v1 Python tooling and redundant artifacts**

Run:
```
cd /Users/barriault/dnd/gygaxagain && rm -rf pytest.ini .pytest_cache/ .venv/ SPEC.md meta/
```
Expected: no output.

- [ ] **Step 6: Verify deletion**

Run:
```
ls /Users/barriault/dnd/gygaxagain/.claude /Users/barriault/dnd/gygaxagain/CLAUDE.md /Users/barriault/dnd/gygaxagain/dm /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp /Users/barriault/dnd/gygaxagain/.mcp.json 2>&1
```
Expected: all paths report "No such file or directory."

- [ ] **Step 7: Commit the cleanup**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add -A
git -C /Users/barriault/dnd/gygaxagain commit -m "Remove v1 Claude Code runtime in preparation for Rails v2"
git -C /Users/barriault/dnd/gygaxagain push origin main
```
Expected: commit succeeds; push succeeds.

---

## Task 2: Initialize Rails 8 application

**Files:**
- Create: Standard Rails 8 layout (`app/`, `config/`, `db/`, `lib/`, `public/`, `bin/`, `Gemfile`, `Gemfile.lock`, `package.json`, etc.)
- Modify: `.gitignore` (Rails-flavored)

- [ ] **Step 1: Confirm Ruby version**

Run:
```
ruby --version
```
Expected: `ruby 3.3.x` or later (Rails 8 requires ≥3.2; 3.3 recommended).

If Ruby is older than 3.3, install via `mise` / `rbenv` / `asdf` before continuing.

- [ ] **Step 2: Confirm Rails 8 is installed**

Run:
```
gem list rails -i
```
Expected: `true`. If false, run `gem install rails -v "~> 8.0"`.

- [ ] **Step 3: Verify Rails version**

Run:
```
rails --version
```
Expected: `Rails 8.0.x` or later.

- [ ] **Step 4: Generate the Rails app into the current directory**

Run:
```
cd /Users/barriault/dnd/gygaxagain && rails new . --database=postgresql --javascript=bun --css=tailwind --asset-pipeline=propshaft --skip-test --skip-git --skip-bundle --force
```

Notes:
- `--skip-test` because RSpec is added in Task 4.
- `--skip-git` because the repo already exists.
- `--skip-bundle` because we'll add Phase 1 gems in Task 3 before running bundle.
- `--force` overwrites the existing `.gitignore` and `README.md` (those are preserved separately or rewritten later).

Expected: Rails generates files. Conflicts on `.gitignore` and `README.md` are overwritten without prompting.

- [ ] **Step 5: Inspect what Rails generated**

Run:
```
ls -la /Users/barriault/dnd/gygaxagain/app /Users/barriault/dnd/gygaxagain/config /Users/barriault/dnd/gygaxagain/Gemfile
```
Expected: `app/` contains `controllers/`, `models/`, etc. `config/application.rb` exists. `Gemfile` is present.

- [ ] **Step 6: Verify Gemfile has expected default gems**

Run:
```
grep -E '"rails"|"pg"|"propshaft"|"importmap"|"cssbundling"|"jsbundling"' /Users/barriault/dnd/gygaxagain/Gemfile
```
Expected: lines for `rails`, `pg`, `propshaft`, `cssbundling-rails`, `jsbundling-rails`.

- [ ] **Step 7: Commit the Rails skeleton**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add -A
git -C /Users/barriault/dnd/gygaxagain commit -m "Initialize Rails 8 application with Postgres, Bun, Tailwind, Propshaft"
```

---

## Task 3: Add Phase 1 gems and install dependencies

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Open Gemfile and add Phase 1 gems**

Append to the existing Gemfile structure (Rails 8 generates a Gemfile with `gem`, `group :development, :test do`, and `group :development do` sections). Add the following gems in their appropriate sections:

In the top-level gem list (production):
```ruby
gem "view_component"
```

In `group :development, :test do`:
```ruby
gem "rspec-rails"
gem "factory_bot_rails"
gem "shoulda-matchers"
gem "dotenv-rails"
```

In `group :development do`:
```ruby
gem "lookbook"
gem "annotaterb"
gem "bullet"
```

In `group :test do`:
```ruby
gem "capybara"
```

Note: Rails 8 already ships with `brakeman`, `rubocop-rails-omakase`, and `web-console` in the appropriate groups. Verify by inspecting Gemfile after edits.

- [ ] **Step 2: Add erb_lint to the development group**

In `group :development do`, also add:
```ruby
gem "erb_lint", require: false
```

- [ ] **Step 3: Run bundle install**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle install
```
Expected: gems install successfully. `Gemfile.lock` updates.

- [ ] **Step 4: Verify gems are installed**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle info rspec-rails view_component lookbook factory_bot_rails 2>&1 | head -20
```
Expected: each gem has a `Path: ...` line.

- [ ] **Step 5: Verify Rails can boot**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bin/rails about
```
Expected: prints Rails version, Ruby version, environment, etc., without errors.

- [ ] **Step 6: Create development + test databases and generate initial schema**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bin/rails db:create db:migrate
```
Expected: creates `gygaxagain_development` and `gygaxagain_test` databases; writes empty `db/schema.rb` (since no migrations exist yet).

This ensures the test database exists before any RSpec run, and produces the initial `schema.rb` artifact that CI will later use via `db:schema:load`.

- [ ] **Step 7: Verify schema.rb exists**

Run:
```
test -f /Users/barriault/dnd/gygaxagain/db/schema.rb && echo "schema exists" || echo "missing"
```
Expected: `schema exists`.

- [ ] **Step 8: Commit Gemfile changes and initial schema**

Run:
```
cd /Users/barriault/dnd/gygaxagain && git add Gemfile Gemfile.lock db/schema.rb
git -C /Users/barriault/dnd/gygaxagain commit -m "Add Phase 1 gems (RSpec, ViewComponent, Lookbook, factory_bot, shoulda-matchers, erb_lint, bullet, annotaterb, dotenv-rails, capybara); create databases"
```

---

## Task 4: RSpec installation and configuration

**Files:**
- Create: `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`
- Modify: `spec/rails_helper.rb` (shoulda-matchers config)

- [ ] **Step 1: Run RSpec installer**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bin/rails g rspec:install
```
Expected: creates `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb`.

- [ ] **Step 2: Configure shoulda-matchers in rails_helper.rb**

Append to `/Users/barriault/dnd/gygaxagain/spec/rails_helper.rb` (at the bottom, outside any existing block):

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

- [ ] **Step 3: Configure factory_bot in rails_helper.rb**

Inside the existing `RSpec.configure do |config|` block in `spec/rails_helper.rb`, add:

```ruby
  config.include FactoryBot::Syntax::Methods
```

- [ ] **Step 4: Verify RSpec runs without tests**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle exec rspec
```
Expected: `No examples found.` Exit code 0. No errors.

- [ ] **Step 5: Commit RSpec setup**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add .rspec spec/
git -C /Users/barriault/dnd/gygaxagain commit -m "Install RSpec with shoulda-matchers and factory_bot configuration"
```

---

## Task 5: Lookbook configuration

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Mount Lookbook engine in routes (development only)**

Edit `/Users/barriault/dnd/gygaxagain/config/routes.rb` to add the Lookbook mount block. Current state after `rails new` is roughly:

```ruby
Rails.application.routes.draw do
  # ...defaults...
end
```

Add inside the `draw` block:

```ruby
  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
```

- [ ] **Step 2: Verify Rails still boots**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bin/rails routes 2>&1 | grep lookbook | head -3
```
Expected: lines for Lookbook routes (only present in development; this command runs in development env by default).

- [ ] **Step 3: Commit Lookbook config**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add config/routes.rb
git -C /Users/barriault/dnd/gygaxagain commit -m "Mount Lookbook at /lookbook in development"
```

---

## Task 6: Linter configuration

**Files:**
- Modify: `.rubocop.yml` (verify Rails 8 default is in place)
- Create: `.erb-lint.yml`

- [ ] **Step 1: Verify rubocop-rails-omakase is configured**

Run:
```
cat /Users/barriault/dnd/gygaxagain/.rubocop.yml
```
Expected: contains `inherit_gem: rubocop-rails-omakase: rubocop.yml`. If file doesn't exist, create it with:
```yaml
inherit_gem:
  rubocop-rails-omakase: rubocop.yml
```

- [ ] **Step 2: Run RuboCop to verify it executes**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bin/rubocop --version
```
Expected: prints version number.

- [ ] **Step 3: Run Brakeman to verify it executes**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bin/brakeman --version 2>&1 | head -3
```
Expected: prints Brakeman version.

- [ ] **Step 4: Create .erb-lint.yml**

Create `/Users/barriault/dnd/gygaxagain/.erb-lint.yml` with:

```yaml
---
linters:
  ErbSafety:
    enabled: true
  SpaceAroundErbTag:
    enabled: true
  NoJavascriptTagHelper:
    enabled: true
  RightTrim:
    enabled: true
  FinalNewline:
    enabled: true
```

- [ ] **Step 5: Verify erb_lint runs**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle exec erb_lint --lint-all 2>&1 | tail -5
```
Expected: runs against existing `.erb` files (likely just `app/views/layouts/application.html.erb` so far); reports 0 errors or auto-fixable warnings.

- [ ] **Step 6: Commit linter config**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add .erb-lint.yml .rubocop.yml
git -C /Users/barriault/dnd/gygaxagain commit -m "Add erb_lint configuration; verify RuboCop and Brakeman defaults"
```

---

## Task 7: Landing page (TDD)

**Files:**
- Create: `spec/requests/pages_spec.rb`
- Create: `app/controllers/pages_controller.rb`
- Create: `app/components/pages/home_component.rb`
- Create: `app/components/pages/home_component.html.erb`
- Create: `public/robots.txt`
- Modify: `config/routes.rb` (add root route)

- [ ] **Step 1: Write the failing request spec**

Create `/Users/barriault/dnd/gygaxagain/spec/requests/pages_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /" do
    before { get "/" }

    it "returns 200 OK" do
      expect(response).to have_http_status(:ok)
    end

    it "renders the project name" do
      expect(response.body).to include("gygaxagain")
    end

    it "renders the tagline" do
      expect(response.body).to include("solo D&D")
    end

    it "marks the project as private alpha" do
      expect(response.body).to include("private alpha")
    end
  end
end
```

- [ ] **Step 2: Run the spec — expect it to fail**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle exec rspec spec/requests/pages_spec.rb
```
Expected: FAIL. Error mentions "No route matches" or `ActionController::RoutingError`.

- [ ] **Step 3: Add the root route**

Edit `/Users/barriault/dnd/gygaxagain/config/routes.rb` to add `root "pages#home"` inside the existing `Rails.application.routes.draw do` block (above or below the Lookbook mount; placement doesn't matter):

```ruby
  root "pages#home"
```

- [ ] **Step 4: Run the spec again — expect FAIL (no controller)**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle exec rspec spec/requests/pages_spec.rb
```
Expected: FAIL with "uninitialized constant PagesController" or similar.

- [ ] **Step 5: Create the PagesController**

Create `/Users/barriault/dnd/gygaxagain/app/controllers/pages_controller.rb`:

```ruby
class PagesController < ApplicationController
  def home
    render Pages::HomeComponent.new
  end
end
```

- [ ] **Step 6: Run the spec — expect FAIL (no component)**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle exec rspec spec/requests/pages_spec.rb
```
Expected: FAIL with "uninitialized constant Pages::HomeComponent" or similar.

- [ ] **Step 7: Create the HomeComponent class**

Create `/Users/barriault/dnd/gygaxagain/app/components/pages/home_component.rb`:

```ruby
class Pages::HomeComponent < ViewComponent::Base
end
```

- [ ] **Step 8: Create the HomeComponent template**

Create `/Users/barriault/dnd/gygaxagain/app/components/pages/home_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 flex items-center justify-center px-4">
  <div class="text-center max-w-md">
    <h1 class="text-5xl font-bold tracking-tight">gygaxagain</h1>
    <p class="mt-4 text-slate-400">A solo D&amp;D campaign engine.</p>
    <p class="mt-8 text-xs uppercase tracking-widest text-slate-500">private alpha &middot; not for general use</p>
  </div>
</div>
```

- [ ] **Step 9: Run the spec — expect PASS**

Run:
```
cd /Users/barriault/dnd/gygaxagain && bundle exec rspec spec/requests/pages_spec.rb
```
Expected: 4 examples, 0 failures.

- [ ] **Step 10: Verify locally in the browser**

Run (in one terminal):
```
cd /Users/barriault/dnd/gygaxagain && bin/dev
```
Open `http://localhost:3000` in a browser. Expected: page renders with "gygaxagain" headline, "A solo D&D campaign engine." subhead, "private alpha" footnote. Tailwind styling applied (dark background, centered content).

Stop the dev server with Ctrl+C when verified.

- [ ] **Step 11: Add deny-all robots.txt**

Replace `/Users/barriault/dnd/gygaxagain/public/robots.txt` content with:

```
User-agent: *
Disallow: /
```

- [ ] **Step 12: Commit the landing page**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add config/routes.rb app/controllers/pages_controller.rb app/components/pages/ spec/requests/pages_spec.rb public/robots.txt
git -C /Users/barriault/dnd/gygaxagain commit -m "Add Pages#home landing page via ViewComponent; deny-all robots.txt"
```

---

## Task 8: GitHub Actions CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create the CI workflow file**

Create `/Users/barriault/dnd/gygaxagain/.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: RSpec
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: gygaxagain
          POSTGRES_PASSWORD: gygaxagain
          POSTGRES_DB: gygaxagain_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://gygaxagain:gygaxagain@localhost:5432/gygaxagain_test
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - uses: oven-sh/setup-bun@v1
        with:
          bun-version: latest
      - name: Install JS dependencies
        run: bun install
      - name: Build assets
        run: bin/rails assets:precompile
      - name: Set up database
        run: bin/rails db:schema:load
      - name: Run RSpec
        run: bundle exec rspec

  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Run RuboCop
        run: bin/rubocop
      - name: Run erb_lint
        run: bundle exec erb_lint --lint-all
      - name: Run Brakeman
        run: bin/brakeman -q --no-pager
```

- [ ] **Step 2: Commit the CI workflow**

(The `db/schema.rb` artifact is already committed at the end of Task 3.)

Run:
```
git -C /Users/barriault/dnd/gygaxagain add .github/workflows/ci.yml
git -C /Users/barriault/dnd/gygaxagain commit -m "Add GitHub Actions CI workflow (RSpec + RuboCop + erb_lint + Brakeman)"
```

- [ ] **Step 3: Push and verify CI runs**

Run:
```
git -C /Users/barriault/dnd/gygaxagain push origin main
```

Then poll for CI status:
```
sleep 30 && gh run list -R barriault/gygaxagain --limit 3
```
Expected: one row showing the most recent `main` commit with status `completed` and conclusion `success`. If CI is still running, wait and re-check.

- [ ] **Step 4: Verify both jobs passed**

Run:
```
gh run view -R barriault/gygaxagain --log-failed 2>&1 | head -20
```
Expected: "no logs found" or similar — no failed jobs. If anything failed, investigate the workflow output, fix, push again.

---

## Task 9: Heroku app, addons, Procfile, build script

**Files:**
- Create: `Procfile`
- Create: `bin/build` (Heroku build script for bun)

**Prerequisites:** Heroku CLI installed and authenticated (`heroku login`). User confirms the `gygaxagain` app name is available on Heroku.

- [ ] **Step 1: Verify Heroku CLI authenticated**

Run:
```
heroku whoami
```
Expected: prints user's Heroku email.

If unauthenticated, run `heroku login` interactively before continuing.

- [ ] **Step 2: Create the Heroku app**

Run:
```
cd /Users/barriault/dnd/gygaxagain && heroku create gygaxagain --region=us
```
Expected: `Creating ⬢ gygaxagain... done` plus Heroku Git remote setup.

If the app name is taken, try `gygaxagain-app` or `gygaxagain-prod` as fallback. Subsequent steps assume `gygaxagain` — substitute the actual name where needed.

- [ ] **Step 3: Verify the Heroku remote**

Run:
```
cd /Users/barriault/dnd/gygaxagain && git remote -v | grep heroku
```
Expected: two lines with `heroku` remote pointing at `https://git.heroku.com/gygaxagain.git`.

- [ ] **Step 4: Add the Postgres add-on**

Run:
```
heroku addons:create heroku-postgresql:essential-0 --app gygaxagain
```
Expected: addon provisions; `DATABASE_URL` config var is set automatically.

- [ ] **Step 5: Verify DATABASE_URL is set**

Run:
```
heroku config:get DATABASE_URL --app gygaxagain | head -c 30
```
Expected: starts with `postgres://...`.

- [ ] **Step 6: Set Rails master key**

Run:
```
heroku config:set RAILS_MASTER_KEY="$(cat /Users/barriault/dnd/gygaxagain/config/master.key)" --app gygaxagain
```
Expected: `Setting RAILS_MASTER_KEY and restarting ⬢ gygaxagain...` (the app hasn't been deployed yet, so restart is a no-op).

- [ ] **Step 7: Set buildpacks**

Run:
```
heroku buildpacks:set heroku/ruby --app gygaxagain
heroku buildpacks:add --index 1 heroku-community/nodejs --app gygaxagain
```
Expected: `Buildpack added` for both.

- [ ] **Step 8: Verify buildpack order**

Run:
```
heroku buildpacks --app gygaxagain
```
Expected: list shows `heroku-community/nodejs` first, `heroku/ruby` second.

- [ ] **Step 9: Create the Procfile**

Create `/Users/barriault/dnd/gygaxagain/Procfile`:

```
web: bundle exec rails server -p $PORT
release: bundle exec rails db:migrate
```

- [ ] **Step 10: Verify bin/build handles bun**

The default `bin/build` generated by jsbundling-rails-with-bun calls `bun build`. Verify and adjust if needed.

Run:
```
cat /Users/barriault/dnd/gygaxagain/bin/build
```

Expected: a small script that calls `bun install && bun run build` or similar. If the file doesn't exist or doesn't reference bun, create it as:

```bash
#!/usr/bin/env bash
set -e

if ! command -v bun &> /dev/null; then
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi

bun install
bun run build
```

And ensure it's executable: `chmod +x /Users/barriault/dnd/gygaxagain/bin/build`.

- [ ] **Step 11: Verify package.json has a build script**

Run:
```
cat /Users/barriault/dnd/gygaxagain/package.json
```

Expected: contains a `"scripts"` object with a `"build"` entry, e.g., `"build": "bun build app/javascript/*.* --outdir=app/assets/builds --target=browser"`.

If the build script is missing or malformed, fix it per the jsbundling-rails README for bun.

- [ ] **Step 12: Commit Procfile and bin/build**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add Procfile bin/build
git -C /Users/barriault/dnd/gygaxagain commit -m "Add Heroku Procfile and bin/build script for bun installation"
git -C /Users/barriault/dnd/gygaxagain push origin main
```

---

## Task 10: First deploy to Heroku

- [ ] **Step 1: Push to Heroku**

Run:
```
cd /Users/barriault/dnd/gygaxagain && git push heroku main
```

Expected: build output streams. The Node buildpack installs Node and runs `bin/build` to install bun and bundle JS; the Ruby buildpack installs Ruby gems and runs `assets:precompile`; the release phase runs `db:migrate`. Final line: `Verifying deploy... done.`

If the build fails:
- Read the failing log lines. Common issues: missing build script in package.json, master key not set, asset precompile errors.
- Fix in the working tree, commit, push again.

- [ ] **Step 2: Verify the dyno is up**

Run:
```
heroku ps --app gygaxagain
```
Expected: `web.1: up <timestamp>`.

- [ ] **Step 3: Check the app responds at its Heroku URL**

Run:
```
heroku apps:info --app gygaxagain | grep "Web URL" | awk '{print $3}'
```
Note the URL (something like `https://gygaxagain-xxxx.herokuapp.com/`).

Then:
```
curl -s -o /dev/null -w "%{http_code}\n" https://gygaxagain-XXXX.herokuapp.com/
```
(substitute the actual URL)
Expected: `200`.

- [ ] **Step 4: Verify content**

Run:
```
curl -s https://gygaxagain-XXXX.herokuapp.com/ | grep -o "gygaxagain\|private alpha\|solo D" | sort -u
```
Expected: lines for each expected fragment.

---

## Task 11: Domain configuration (Cloudflare + Heroku)

**Prerequisites:** Cloudflare account active, `gygaxagain.com` zone managed in Cloudflare.

- [ ] **Step 1: Add the apex domain to Heroku**

Run:
```
heroku domains:add gygaxagain.com --app gygaxagain
```
Expected: prints something like:
```
Adding gygaxagain.com to ⬢ gygaxagain... done
 ▸    Configure your app's DNS provider to point to the DNS Target gygaxagain-NNNN.herokudns.com
```

Note the DNS target — you'll use it in Cloudflare.

- [ ] **Step 2: Display the Heroku domain target**

Run:
```
heroku domains --app gygaxagain
```
Expected: lists `gygaxagain.com` with its DNS Target column populated.

- [ ] **Step 3: Add the CNAME flattening record in Cloudflare**

This step is performed in the Cloudflare dashboard, not via CLI:

1. Go to Cloudflare → Websites → `gygaxagain.com` → DNS → Records.
2. Add a new record:
   - **Type:** CNAME
   - **Name:** `@` (this becomes the apex via CNAME flattening)
   - **Target:** the `gygaxagain-NNNN.herokudns.com` value from Step 1.
   - **Proxy status:** **DNS only** (gray cloud — do not proxy; Heroku Auto-SSL requires direct access).
   - **TTL:** Auto.
3. Save.

- [ ] **Step 4: Wait for DNS propagation and verify**

Run (in a loop until it succeeds):
```
dig +short gygaxagain.com CNAME
```
Expected: returns the Heroku DNS target. Re-run every 30s for up to 5 minutes if not yet propagated.

If `dig` returns nothing, Cloudflare's CNAME flattening returns the resolved A record for apex queries. Try:
```
dig +short gygaxagain.com
```
Expected: returns an IP address (Heroku's edge IP).

- [ ] **Step 5: Enable Heroku Auto-SSL**

Run:
```
heroku certs:auto:enable --app gygaxagain
```
Expected: `Enabling Automatic Certificate Management for gygaxagain.com... done`.

- [ ] **Step 6: Wait for SSL cert to provision**

Run (in a polling loop):
```
heroku certs:auto --app gygaxagain
```
Expected: status progresses from `Cert issued` → `OK`. Can take 1–10 minutes after DNS propagates.

- [ ] **Step 7: Verify HTTPS**

Run:
```
curl -s -o /dev/null -w "%{http_code}\n" https://gygaxagain.com/
```
Expected: `200`.

- [ ] **Step 8: Verify content over HTTPS**

Run:
```
curl -s https://gygaxagain.com/ | grep "gygaxagain\|private alpha"
```
Expected: matching lines from the landing page.

- [ ] **Step 9: Verify SSL cert is valid**

Run:
```
echo | openssl s_client -connect gygaxagain.com:443 -servername gygaxagain.com 2>/dev/null | openssl x509 -noout -subject -dates
```
Expected: subject contains `gygaxagain.com`; `notAfter=` date is ~3 months in the future.

---

## Task 12: Rewrite README for v2

**Files:**
- Modify: `/Users/barriault/dnd/gygaxagain/README.md`

- [ ] **Step 1: Write the v2 README**

Replace the contents of `/Users/barriault/dnd/gygaxagain/README.md` with:

```markdown
# gygaxagain

A solo D&D campaign engine. Single-player, Claude-narrated, deployed at [gygaxagain.com](https://gygaxagain.com).

**Private alpha — not for general use.** Account creation is invite-only and not currently offered.

## What this is

The player drives one primary PC; Claude narrates the world. Mechanical outcomes route through dice and oracle services. Hidden world state is enforced by data-model + UI separation: the player-facing context builder cannot reach `*_secrets` tables, so the narrator literally cannot leak what it was never given. The asymmetry between what the player knows and what's in the world is the load-bearing invariant of the design.

This is v2 — a Rails 8 web app rewrite of an earlier Claude Code / MCP-based proof of concept. The v1 final state is preserved at `git tag v1-final-poc`; the design history of both versions lives under `docs/superpowers/specs/`.

## Tech

Rails 8 · PostgreSQL · Bun · Tailwind · Propshaft · ViewComponent · Hotwire (Turbo + Stimulus) · Devise · RSpec · Solid Queue/Cache/Cable · Heroku · Cloudflare.

## Local development

Prerequisites: Ruby 3.3+, Bun, PostgreSQL.

```bash
bundle install
bun install
bin/rails db:create db:migrate
bin/dev
```

Visit `http://localhost:3000`. RSpec: `bundle exec rspec`. Lookbook (in dev): `http://localhost:3000/lookbook`.

## Roadmap

The v2 architectural commitments and phase progression are in [`docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md`](docs/superpowers/specs/2026-05-13-v2-phase-0-roadmap-design.md). Each phase has its own design spec and implementation plan under `docs/superpowers/`.

GitHub issue [#1](https://github.com/barriault/gygaxagain/issues/1) is the parent tracking issue for v2 work, with sub-issues for each phase.

## Known limitations

See [`docs/known-limitations.md`](docs/known-limitations.md) for cross-cutting issues. The v1-era Claude Code regression noted there no longer affects v2 (the dependency on MCP-mediated subagents is gone).
```

- [ ] **Step 2: Commit the README rewrite**

Run:
```
git -C /Users/barriault/dnd/gygaxagain add README.md
git -C /Users/barriault/dnd/gygaxagain commit -m "Rewrite README for v2 Rails skeleton"
git -C /Users/barriault/dnd/gygaxagain push origin main
```

---

## Task 13: Final verification and issue close

- [ ] **Step 1: Verify all acceptance criteria from Phase 0 spec**

Acceptance from the Phase 0 spec's "Phase 1 — Rails skeleton + landing page on Heroku" subsection:

- [ ] **Local: `bin/rails server` works.** Verify by running `cd /Users/barriault/dnd/gygaxagain && bin/dev` and visiting localhost:3000. Stop with Ctrl+C.
- [ ] **Local: `bundle exec rspec` passes ≥1 test.** Verify:
  ```
  cd /Users/barriault/dnd/gygaxagain && bundle exec rspec
  ```
  Expected: 4 examples, 0 failures.
- [ ] **CI: GitHub Actions workflow green on main.** Verify:
  ```
  gh run list -R barriault/gygaxagain --branch main --limit 1
  ```
  Expected: most recent run completed with success.
- [ ] **Production: `https://gygaxagain.com` resolves to the Heroku app, renders the landing page, valid SSL.** Verify:
  ```
  curl -s -o /dev/null -w "%{http_code}\n" https://gygaxagain.com/
  ```
  Expected: 200. Then visit in browser, see the page with valid SSL padlock.
- [ ] **v1 cleanup: `v1-final-poc` tag exists at origin.** Verify:
  ```
  git -C /Users/barriault/dnd/gygaxagain ls-remote --tags origin | grep v1-final-poc
  ```
  Expected: one line with the tag.
- [ ] **v1 cleanup: `.claude/`, `CLAUDE.md`, `dm/`, `tools/dm-fs-mcp/`, `.mcp.json` removed.** Verify:
  ```
  ls /Users/barriault/dnd/gygaxagain/.claude /Users/barriault/dnd/gygaxagain/CLAUDE.md /Users/barriault/dnd/gygaxagain/dm /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp /Users/barriault/dnd/gygaxagain/.mcp.json 2>&1 | grep -c "No such"
  ```
  Expected: `5`.
- [ ] **README rewritten to reflect v2.** Verify:
  ```
  head -3 /Users/barriault/dnd/gygaxagain/README.md
  ```
  Expected: contains "A solo D&D campaign engine" and "private alpha."

- [ ] **Step 2: Close issue #2**

Run:
```
gh issue close 2 -R barriault/gygaxagain --comment "Phase 1 complete.

- v1-final-poc tag pushed to origin.
- v1 Claude Code runtime artifacts removed from working tree.
- Rails 8 app generated with Postgres + Bun + Tailwind + Propshaft.
- RSpec + factory_bot + shoulda-matchers + Capybara installed.
- ViewComponent + Lookbook configured (dev /lookbook).
- erb_lint + RuboCop + Brakeman wired into local + CI.
- Pages#home landing page renders via Pages::HomeComponent (TDD: 4 specs, 0 failures).
- deny-all robots.txt in production.
- GitHub Actions CI green (RSpec + lint jobs).
- Heroku app gygaxagain deployed with Postgres essential-0, RAILS_MASTER_KEY set, ruby + nodejs buildpacks.
- https://gygaxagain.com resolves via Cloudflare CNAME flattening to Heroku with valid Auto-SSL.
- README rewritten for v2.

Implementation plan: docs/superpowers/plans/2026-05-13-v2-phase-1-rails-skeleton-plan.md"
```

- [ ] **Step 3: Verify the issue closed**

Run:
```
gh issue view 2 -R barriault/gygaxagain --json state | jq -r .state
```
Expected: `CLOSED`.

- [ ] **Step 4: Check the parent issue's task list reflects the closure**

Run:
```
gh issue view 1 -R barriault/gygaxagain | head -30
```
Expected: the task list for Phase 1 shows as checked. (GitHub auto-checks tasks when sub-issues close.)

---

## Notes for the executing engineer

**Branch strategy:** Solo project. Work on `main` directly. Each task ends with a commit; the working tree is left in a clean state after each commit (with one exception — the Heroku push in Task 10 doesn't commit anything new locally). Push to origin after each commit, or batch pushes at task boundaries — your call.

**External services that require human attention:**
- Task 9 (Heroku CLI auth) — must run `heroku login` interactively first if not already logged in.
- Task 11 Step 3 (Cloudflare DNS) — the DNS record must be added in the Cloudflare web UI; the plan describes the exact settings.

**Common pitfalls:**
- If `rails new` complains about Ruby version, install Ruby 3.3+ before retrying.
- If `bun install` fails on Heroku, check that `bin/build` is executable (`chmod +x bin/build`) and that `package.json` has a valid `build` script.
- If GitHub Actions fails on `assets:precompile`, the issue is usually a missing `bun` or `node` step; verify the workflow uses both `setup-ruby` and `setup-bun`.
- If `heroku certs:auto` stalls at `DNS Verification`, double-check the Cloudflare CNAME has proxy disabled (gray cloud).
- If the apex domain doesn't resolve, confirm Cloudflare's CNAME flattening is enabled for the zone (it's the default on free plans).
