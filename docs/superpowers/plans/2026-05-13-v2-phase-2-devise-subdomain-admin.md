# v2 Phase 2 — Devise + subdomain split + admin shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Devise authentication and the apex/admin subdomain split. Sign-in works at `gygaxagain.com`; `admin.gygaxagain.com` requires authentication and shows an empty dashboard placeholder. No data models beyond `User`.

**Architecture:** Devise on the `User` model with seven modules (no `:registerable`, no `:confirmable`). Routes split into two subdomain-constrained files (`config/routes/play.rb` and `config/routes/admin.rb`). Controller and component namespaces mirror routes (`Play::*`, `Admin::*`). Cross-subdomain session via cookie `domain: :all, tld_length: 2`. After-sign-in redirect stub points to admin dashboard; refined in Phase 3. Local development uses `lvh.me:3000` so subdomain routing works without `/etc/hosts` edits.

**Tech Stack:** Rails 8.1, Devise (latest), letter_opener (dev), Postgres, RSpec, FactoryBot, Capybara (rack_test driver for the one Phase 2 system spec), ViewComponent. Existing Phase 1 toolchain unchanged.

**Spec:** [`docs/superpowers/specs/2026-05-13-v2-phase-2-devise-subdomain-admin-design.md`](../specs/2026-05-13-v2-phase-2-devise-subdomain-admin-design.md)
**Issue:** [#3](https://github.com/barriault/gygaxagain/issues/3)

---

## Task 1: Cloudflare + Heroku DNS for `admin` subdomain (manual)

This task is infrastructure-only. No code changes. Run before merging Phase 2 to production so the SSL cert is provisioned by the time the deploy lands. Can be done in parallel with Tasks 2+ since it has zero impact on local development.

**Files:** none (manual ops).

- [ ] **Step 1: Add Heroku custom domain**

Run: `heroku domains:add admin.gygaxagain.com -a gygaxagain`

Expected: command prints a DNS target string (e.g., `something.herokudns.com`). Note this — should match the target Phase 1 used for apex.

- [ ] **Step 2: Add Cloudflare CNAME record**

In the Cloudflare dashboard for `gygaxagain.com`:
- Type: `CNAME`
- Name: `admin`
- Target: the DNS target from Step 1
- Proxy status: **DNS only** (gray cloud) for initial cert provisioning
- TTL: Auto

- [ ] **Step 3: Enable Heroku automatic certificates**

Run: `heroku certs:auto -a gygaxagain` to view status. If `Automatic Certificate Management` is not enabled, run:

`heroku certs:auto:enable -a gygaxagain`

Expected: Heroku begins ACME provisioning for `admin.gygaxagain.com`. Wait until status shows `OK` (usually 1–5 min, can be up to 1 hr).

- [ ] **Step 4: Verify SSL handshake**

Run: `curl -I https://admin.gygaxagain.com` from a terminal that's not behind a corporate proxy.

Expected: TLS handshake succeeds. HTTP response will be a Rails 404 or whatever Phase 1 returns for unknown hosts — that's fine; the cert is what matters here.

- [ ] **Step 5: (Optional, post-deploy) Re-enable Cloudflare proxy**

After Phase 2 ships and `https://admin.gygaxagain.com` is serving the dashboard, flip the Cloudflare CNAME back to proxied (orange cloud). Heroku and Cloudflare both terminate SSL; this is supported and gives us Cloudflare's caching + DDoS protection at the edge.

---

## Task 2: Test infrastructure setup

Set up the test infrastructure other specs need: Capybara host config, Devise integration helpers, default URL options for test env, and a support directory autoload.

**Files:**
- Modify: `spec/rails_helper.rb`
- Create: `spec/support/capybara.rb`
- Create: `spec/support/devise.rb`
- Modify: `config/environments/test.rb`

- [ ] **Step 1: Enable spec/support autoload**

Edit `spec/rails_helper.rb`. Uncomment line 26 so that support files load:

```ruby
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }
```

- [ ] **Step 2: Add Capybara host config**

Create `spec/support/capybara.rb`:

```ruby
require "capybara/rails"
require "capybara/rspec"

Capybara.default_host = "http://gygaxagain.com"
Capybara.app_host = "http://gygaxagain.com"
Capybara.always_include_port = true
Capybara.server = :puma, { Silent: true }
```

- [ ] **Step 3: Add Devise integration helpers stub (becomes active when Devise installed)**

Create `spec/support/devise.rb`:

```ruby
RSpec.configure do |config|
  if defined?(Devise)
    config.include Devise::Test::IntegrationHelpers, type: :request
    config.include Devise::Test::IntegrationHelpers, type: :system
    config.include Devise::Test::ControllerHelpers, type: :controller
  end

  # Default request specs to apex host. Specs can override with host! "admin.gygaxagain.com".
  config.before(:each, type: :request) { host! "gygaxagain.com" }
end
```

The `defined?(Devise)` guard means this file is harmless before Task 4 installs Devise; once Devise is in the bundle, the helpers light up.

- [ ] **Step 4: Set test env default URL host**

Edit `config/environments/test.rb`. After the existing config but inside the `Rails.application.configure do` block, add:

```ruby
  config.action_controller.default_url_options = { host: "gygaxagain.com" }
  config.action_mailer.default_url_options = { host: "gygaxagain.com" }
```

- [ ] **Step 5: Verify existing test suite still passes**

Run: `bundle exec rspec`

Expected: PASS — the existing Phase 1 spec (`spec/requests/pages_spec.rb`) still passes. The new support files don't break anything; they just sit ready for later tasks.

- [ ] **Step 6: Commit**

```bash
git add spec/rails_helper.rb spec/support/ config/environments/test.rb
git commit -m "Add Capybara + Devise spec support files and test default_url_options

Wires the spec/support autoload glob, Capybara host config, a
guarded Devise integration helpers include (no-op until Devise is
installed), and the test-env default URL host. Phase 2 prep."
```

---

## Task 3: Add `devise` and `letter_opener` gems

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock`

- [ ] **Step 1: Add gems to Gemfile**

Edit `Gemfile`. Add `gem "devise"` to the top-level gems list (near `gem "view_component"`). Add `gem "letter_opener"` inside the existing `group :development do` block.

After edit, the relevant sections should read:

```ruby
gem "devise"
# ... (other top-level gems unchanged)
gem "view_component"

# ...

group :development do
  gem "annotaterb"
  gem "bullet"
  gem "erb_lint", require: false
  gem "letter_opener"
  gem "lookbook"
  gem "web-console"
end
```

- [ ] **Step 2: Install**

Run: `bundle install`

Expected: bundler resolves and installs `devise` and `letter_opener`. `Gemfile.lock` updates.

- [ ] **Step 3: Verify boot**

Run: `bin/rails runner 'puts "ok"'`

Expected: prints `ok`. No initializer errors.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add devise and letter_opener gems

Devise drives Phase 2 authentication. Letter_opener catches outbound
mail in development so password-reset flows are visible without
configuring SMTP."
```

---

## Task 4: Devise install + initializer tuning

**Files:**
- Create: `config/initializers/devise.rb` (via generator, then edited)
- Modify: `config/initializers/filter_parameter_logging.rb` (verified post-generation)

- [ ] **Step 1: Run Devise install generator**

Run: `bin/rails g devise:install`

Expected: generates `config/initializers/devise.rb` and `config/locales/devise.en.yml`. Prints post-install instructions (which are partially redundant with this plan — ignore them).

- [ ] **Step 2: Edit `config/initializers/devise.rb`**

Apply four targeted edits. The generator creates a long file with most settings commented out. Find and update (uncomment if needed):

```ruby
config.mailer_sender = ENV.fetch("MAIL_FROM", "no-reply@gygaxagain.com")
config.password_length = 12..128
config.timeout_in = 30.days
config.parent_controller = "ApplicationController"
```

`parent_controller` is normally commented as `# config.parent_controller = 'DeviseController'`. Replace with `"ApplicationController"` so Devise's auto-generated controllers inherit our app-wide concerns (after_sign_in_path_for etc., added later).

- [ ] **Step 3: Verify password filter list**

Open `config/initializers/filter_parameter_logging.rb`. Confirm the filter list includes `:password` and `:password_confirmation`. If not, add them:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
```

Default Rails 8 filter list above already covers `:password` via the `:passw` substring match. No edit needed if the file is unchanged from Rails defaults.

- [ ] **Step 4: Verify boot**

Run: `bin/rails runner 'puts Devise.password_length.inspect'`

Expected: prints `12..128`.

- [ ] **Step 5: Commit**

```bash
git add config/initializers/devise.rb config/locales/devise.en.yml
git commit -m "Devise install + initializer tuning

Sets password_length 12..128 (bumped from Devise default 6),
timeout_in 30.days (default 30 minutes is painful for a long-form
play surface), parent_controller to ApplicationController so Devise
controllers inherit our overrides, and mailer_sender from
ENV[MAIL_FROM]."
```

---

## Task 5: User model + migration + factory + model spec

**Files:**
- Create: `db/migrate/*_devise_create_users.rb` (via generator, then edited)
- Modify: `app/models/user.rb` (generator creates; we edit)
- Create: `spec/factories/users.rb`
- Create: `spec/models/user_spec.rb`
- Modify: `db/schema.rb` (via migrate)

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/user_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  describe "Devise modules" do
    it "enables the expected modules" do
      expect(User.devise_modules).to match_array(
        %i[database_authenticatable recoverable rememberable validatable
           trackable timeoutable lockable]
      )
    end

    it "does not enable registerable" do
      expect(User.devise_modules).not_to include(:registerable)
    end

    it "does not enable confirmable" do
      expect(User.devise_modules).not_to include(:confirmable)
    end
  end

  describe "factory" do
    it "creates a persistable user" do
      user = build(:user)
      expect(user).to be_valid
      expect { user.save! }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run spec to verify failure**

Run: `bundle exec rspec spec/models/user_spec.rb`

Expected: FAIL — `NameError: uninitialized constant User` (Devise hasn't generated it yet).

- [ ] **Step 3: Generate Devise User**

Run: `bin/rails g devise User`

Expected: generates `app/models/user.rb`, `db/migrate/<timestamp>_devise_create_users.rb`, and adds `devise_for :users` to `config/routes.rb` (we'll move this route in Task 9).

- [ ] **Step 4: Edit the migration to enable trackable + lockable**

Open `db/migrate/<timestamp>_devise_create_users.rb`. The generator creates most module column blocks as commented-out. Uncomment the `## Trackable` and `## Lockable` blocks. Final migration:

```ruby
class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Confirmable
      # t.string   :confirmation_token
      # t.datetime :confirmed_at
      # t.datetime :confirmation_sent_at
      # t.string   :unconfirmed_email

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token,         unique: true
  end
end
```

`Timeoutable` requires no DB columns — it's session-only.

- [ ] **Step 5: Edit `app/models/user.rb`**

Replace the generator's default content with:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :trackable, :timeoutable, :lockable
end
```

- [ ] **Step 6: Create the User factory**

Create `spec/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.test" }
    password { "correct horse battery staple" }
    password_confirmation { "correct horse battery staple" }
  end
end
```

- [ ] **Step 7: Migrate**

Run: `bin/rails db:migrate`

Expected: creates `users` table with all module columns + indexes.

- [ ] **Step 8: Run spec to verify pass**

Run: `bundle exec rspec spec/models/user_spec.rb`

Expected: PASS — all 4 examples.

- [ ] **Step 9: Annotate the User model**

Run: `bundle exec annotaterb models`

Expected: adds schema annotations to `app/models/user.rb` and `spec/models/user_spec.rb`.

- [ ] **Step 10: Commit**

```bash
git add app/models/user.rb spec/models/user_spec.rb spec/factories/users.rb \
        db/migrate/*_devise_create_users.rb db/schema.rb config/routes.rb
git commit -m "Add Devise User model + migration + factory + spec

User has database_authenticatable, recoverable, rememberable,
validatable, trackable, timeoutable, lockable. No registerable
(signup disabled per Phase 0). No confirmable (no signup flow).

devise_for :users in routes.rb is a generator artifact and will move
to config/routes/play.rb in Task 9."
```

---

## Task 6: Session store initializer (cross-subdomain cookie)

**Files:**
- Create: `config/initializers/session_store.rb`

- [ ] **Step 1: Create the initializer**

Create `config/initializers/session_store.rb`:

```ruby
Rails.application.config.session_store :cookie_store,
  key: "_gygaxagain_session",
  domain: :all,
  tld_length: 2,
  same_site: :lax,
  secure: Rails.env.production?
```

`domain: :all` + `tld_length: 2` means the cookie's `Domain` attribute is set to `gygaxagain.com` in production and `lvh.me` in development — so the cookie is sent for any subdomain. `secure: true` only in production because `lvh.me` is HTTP locally.

- [ ] **Step 2: Verify boot**

Run: `bin/rails runner 'puts "ok"'`

Expected: prints `ok`. No initializer errors.

- [ ] **Step 3: Commit**

```bash
git add config/initializers/session_store.rb
git commit -m "Configure cookie session store for cross-subdomain sharing

cookie_store with domain :all, tld_length: 2, same_site :lax.
Secure flag in production only (lvh.me dev is HTTP)."
```

---

## Task 7: Per-environment default_url_options + ActionMailer

**Files:**
- Modify: `config/environments/development.rb`
- Modify: `config/environments/production.rb`

- [ ] **Step 1: Edit development.rb**

Open `config/environments/development.rb`. Inside the `Rails.application.configure do` block, add:

```ruby
  config.action_controller.default_url_options = { host: "lvh.me", port: 3000 }
  config.action_mailer.default_url_options     = { host: "lvh.me", port: 3000 }
  config.action_mailer.delivery_method         = :letter_opener
  config.action_mailer.perform_deliveries      = true
  config.action_mailer.raise_delivery_errors   = true
```

If any of these lines already exist (Rails 8 default scaffolding may have set some), replace them rather than duplicating.

- [ ] **Step 2: Edit production.rb**

Open `config/environments/production.rb`. Inside the `Rails.application.configure do` block, add:

```ruby
  config.action_controller.default_url_options = { host: "gygaxagain.com", protocol: "https" }
  config.action_mailer.default_url_options     = { host: "gygaxagain.com", protocol: "https" }
  config.action_mailer.delivery_method         = :smtp
  config.action_mailer.smtp_settings = {
    address:              ENV["SMTP_HOST"],
    port:                 ENV.fetch("SMTP_PORT", 587).to_i,
    user_name:            ENV["SMTP_USER"],
    password:             ENV["SMTP_PASS"],
    authentication:       :plain,
    enable_starttls_auto: true
  }
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_deliveries    = true
```

`raise_delivery_errors = false` makes password-reset email failures silent in alpha (acceptable per the spec — SMTP env vars are blank by default).

- [ ] **Step 3: Verify boot in both environments**

Run: `bin/rails runner 'puts Rails.application.config.action_controller.default_url_options'`

Expected: prints `{:host=>"lvh.me", :port=>3000}`.

Run: `RAILS_ENV=production bin/rails runner 'puts Rails.application.config.action_controller.default_url_options' 2>&1 | tail -1`

Expected: prints `{:host=>"gygaxagain.com", :protocol=>"https"}`. (May print other warnings; ignore.)

- [ ] **Step 4: Commit**

```bash
git add config/environments/development.rb config/environments/production.rb
git commit -m "Configure per-environment default_url_options + ActionMailer

Dev uses lvh.me:3000 (resolves to 127.0.0.1, supports subdomain
routing without /etc/hosts edits) and letter_opener delivery.
Production uses gygaxagain.com over https and SMTP from ENV vars
(blank in alpha; raise_delivery_errors disabled so mail failures
do not 500)."
```

---

## Task 8: Routes split scaffolding

Set up the routes split structure with empty subroute files. Subsequent tasks populate them.

**Files:**
- Modify: `config/routes.rb`
- Create: `config/routes/play.rb`
- Create: `config/routes/admin.rb`

- [ ] **Step 1: Create empty play.rb**

Create `config/routes/play.rb`:

```ruby
constraints subdomain: "" do
  # Devise + play-surface routes added in subsequent tasks.
end
```

- [ ] **Step 2: Create empty admin.rb**

Create `config/routes/admin.rb`:

```ruby
constraints subdomain: "admin" do
  scope module: "admin" do
    # Admin routes added in subsequent tasks.
  end
end
```

- [ ] **Step 3: Replace the top-level routes.rb**

Open `config/routes.rb` and replace its contents with:

```ruby
Rails.application.routes.draw do
  draw(:play)
  draw(:admin)

  constraints subdomain: "www" do
    get "(*any)", to: redirect(status: 301) { |_params, req|
      "#{req.protocol}#{req.host.sub(/^www\./, '')}#{req.fullpath}"
    }
  end

  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
end
```

Note: Task 5 left a `devise_for :users` line in `config/routes.rb` from the generator. This replacement removes it. The Devise route comes back in Task 9 (inside `config/routes/play.rb`).

Note also: the existing `root "pages#home"` and `get "up" ..."` lines from Phase 1 are absorbed into this new structure. The root route now lives in `play.rb` (added in Task 10).

- [ ] **Step 4: Verify routes load**

Run: `bin/rails routes 2>&1 | head -20`

Expected: prints only the health-check route plus (in dev) Lookbook routes. No errors. The www-redirect doesn't appear in `rails routes` output because of how Rails formats anonymous redirect routes, but the route IS registered.

- [ ] **Step 5: Verify the existing pages_spec breaks (root is no longer routable yet)**

Run: `bundle exec rspec spec/requests/pages_spec.rb`

Expected: FAIL — `ActionController::RoutingError` for `GET /` (root route was moved out, not yet re-added to play.rb).

This is expected breakage. Task 10 re-adds the root route in play.rb and the spec moves to `spec/requests/play/home_spec.rb`.

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb config/routes/play.rb config/routes/admin.rb
git commit -m "Split routes by subdomain (play.rb + admin.rb)

Top-level routes.rb draws the two subdomain-constrained files plus
the www->apex 301 redirect and the health check. Subroute files are
empty stubs in this commit; routes are populated in subsequent
tasks. Root route is temporarily missing — restored in Task 10
(Pages -> Play migration)."
```

---

## Task 9: Devise routes on apex + devise_routes spec

**Files:**
- Modify: `config/routes/play.rb`
- Create: `spec/requests/devise_routes_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/requests/devise_routes_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Devise routes", type: :request do
  describe "GET /users/sign_in" do
    it "renders the sign-in form" do
      get "/users/sign_in"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log in").or include("Sign in")
    end
  end

  describe "GET /users/sign_up" do
    it "is not routable (sign-up disabled)" do
      expect { get "/users/sign_up" }.to raise_error(ActionController::RoutingError)
    end
  end

  describe "POST /users (registrations)" do
    it "is not routable (sign-up disabled)" do
      expect { post "/users", params: { user: { email: "x@y.test", password: "x" * 12 } } }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
```

- [ ] **Step 2: Run spec to verify failure**

Run: `bundle exec rspec spec/requests/devise_routes_spec.rb`

Expected: FAIL — both sign-in and sign-up cases fail (sign-in returns 404 or routing error; sign-up does not raise as expected).

- [ ] **Step 3: Add Devise route to play.rb**

Edit `config/routes/play.rb`:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [:registrations]

  # Play home root is added in Task 10.
end
```

- [ ] **Step 4: Run spec to verify pass**

Run: `bundle exec rspec spec/requests/devise_routes_spec.rb`

Expected: PASS — all 3 examples.

- [ ] **Step 5: Commit**

```bash
git add config/routes/play.rb spec/requests/devise_routes_spec.rb
git commit -m "Add Devise sign-in route on apex (registrations skipped)

devise_for :users, skip: [:registrations] inside the apex subdomain
constraint. Sign-in form renders; /users/sign_up and POST /users
are not routable (404 in production via show_exceptions; raise
ActionController::RoutingError in tests)."
```

---

## Task 10: Pages → Play namespace migration

Migrate the Phase 1 landing page from `Pages::*` to `Play::*` so the apex root route lives in the new namespace.

**Files:**
- Move: `app/components/pages/home_component.rb` → `app/components/play/home_component.rb` (class rename)
- Move: `app/components/pages/home_component.html.erb` → `app/components/play/home_component.html.erb` (content unchanged)
- Delete: `app/controllers/pages_controller.rb`
- Create: `app/controllers/play/application_controller.rb`
- Create: `app/controllers/play/home_controller.rb`
- Create: `app/views/play/home/show.html.erb`
- Delete: `spec/requests/pages_spec.rb`
- Create: `spec/requests/play/home_spec.rb`
- Create: `spec/components/play/home_component_spec.rb`
- Modify: `config/routes/play.rb`

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/play/home_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Play home", type: :request do
  describe "GET /" do
    before { get "/" }

    it "returns 200 OK" do
      expect(response).to have_http_status(:ok)
    end

    it "renders the project name" do
      expect(response.body).to include("gygaxagain")
    end

    it "renders the tagline" do
      expect(response.body).to include("solo D&amp;D")
    end

    it "marks the project as private alpha" do
      expect(response.body).to include("private alpha")
    end
  end
end
```

- [ ] **Step 2: Write the failing component spec**

Create `spec/components/play/home_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Play::HomeComponent, type: :component do
  it "renders the project name, tagline, and private-alpha tag" do
    render_inline(described_class.new)
    expect(page).to have_text("gygaxagain")
    expect(page).to have_text(/solo D&D/i)
    expect(page).to have_text(/private alpha/i)
  end
end
```

- [ ] **Step 3: Run specs to verify failure**

Run: `bundle exec rspec spec/requests/play/home_spec.rb spec/components/play/home_component_spec.rb`

Expected: FAIL — request spec gets 404/routing error; component spec gets `NameError: uninitialized constant Play::HomeComponent`.

- [ ] **Step 4: Create the namespace directories**

Run: `mkdir -p app/components/play app/controllers/play app/views/play/home`

- [ ] **Step 5: Move the component files**

Move `app/components/pages/home_component.rb` to `app/components/play/home_component.rb` and rename the class:

```ruby
class Play::HomeComponent < ViewComponent::Base
end
```

Move `app/components/pages/home_component.html.erb` to `app/components/play/home_component.html.erb`. Content unchanged.

After moves, delete the now-empty `app/components/pages/` directory.

- [ ] **Step 6: Create Play::ApplicationController**

Create `app/controllers/play/application_controller.rb`:

```ruby
module Play
  class ApplicationController < ::ApplicationController
    # Play-surface controllers inherit from here. No authentication
    # requirement at this level — campaign-scoped auth comes in Phase 3.
  end
end
```

- [ ] **Step 7: Create Play::HomeController**

Create `app/controllers/play/home_controller.rb`:

```ruby
module Play
  class HomeController < ApplicationController
    def show
      render Play::HomeComponent.new
    end
  end
end
```

- [ ] **Step 8: Create the view stub**

Create `app/views/play/home/show.html.erb` (empty file — `render Play::HomeComponent.new` in the controller bypasses this, but Rails wants a default view to exist):

Actually, since the controller calls `render Play::HomeComponent.new` directly, no `show.html.erb` is needed. Skip this file. Delete the directory if `mkdir -p` created it empty.

(Correction to the file-list header above: no view file needed.)

- [ ] **Step 9: Delete the old PagesController**

Delete `app/controllers/pages_controller.rb`.

- [ ] **Step 10: Add the root route to play.rb**

Edit `config/routes/play.rb`:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [:registrations]

  root "play/home#show"
end
```

- [ ] **Step 11: Delete the old pages_spec**

Delete `spec/requests/pages_spec.rb`. (Its content is now in `spec/requests/play/home_spec.rb`.)

- [ ] **Step 12: Run specs to verify pass**

Run: `bundle exec rspec spec/requests/play/ spec/components/play/`

Expected: PASS — all 5 examples (4 from request spec, 1 from component spec).

- [ ] **Step 13: Manual smoke test (optional but recommended)**

Run: `bin/dev` (or `bin/rails server`).

In a browser, visit `http://lvh.me:3000/`.

Expected: landing page renders with project name, tagline, and "private alpha" tag.

Stop the server with Ctrl-C.

- [ ] **Step 14: Commit**

```bash
git add app/controllers/ app/components/ spec/requests/ spec/components/ \
        config/routes/play.rb
git rm app/controllers/pages_controller.rb spec/requests/pages_spec.rb \
       app/components/pages/home_component.rb \
       app/components/pages/home_component.html.erb 2>/dev/null || true
git commit -m "Migrate Pages::* to Play::* namespace

Move the Phase 1 landing page from Pages::HomeComponent and
PagesController#home to Play::HomeComponent and Play::HomeController#show.
Root route now lives in config/routes/play.rb. Add Play::ApplicationController
as the base for play-surface controllers. Specs renamed to match."
```

The `git rm ... 2>/dev/null || true` handles the case where the files were moved (not deleted via git mv) and may need explicit removal. Adjust if your shell complains.

---

## Task 11: Admin namespace (controller + component + dashboard route)

**Files:**
- Create: `app/controllers/admin/application_controller.rb`
- Create: `app/controllers/admin/dashboard_controller.rb`
- Create: `app/components/admin/dashboard_component.rb`
- Create: `app/components/admin/dashboard_component.html.erb`
- Create: `app/components/admin/dashboard_component_preview.rb` (Lookbook)
- Create: `spec/components/admin/dashboard_component_spec.rb`
- Create: `spec/requests/admin/dashboard_spec.rb`
- Modify: `config/routes/admin.rb`

- [ ] **Step 1: Write the failing component spec**

Create `spec/components/admin/dashboard_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::DashboardComponent, type: :component do
  it "renders an admin-dashboard placeholder" do
    render_inline(described_class.new)
    expect(page).to have_text(/admin dashboard/i)
  end
end
```

- [ ] **Step 2: Write the failing request spec**

Create `spec/requests/admin/dashboard_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  before { host! "admin.gygaxagain.com" }

  describe "when not authenticated" do
    it "redirects to apex sign-in" do
      get "/dashboard"
      expect(response).to have_http_status(:found)
      expect(response.location).to include("gygaxagain.com/users/sign_in")
    end
  end

  describe "when authenticated" do
    let(:user) { create(:user) }
    before { sign_in user }

    it "renders the dashboard placeholder" do
      get "/dashboard"
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/admin dashboard/i)
    end
  end
end
```

- [ ] **Step 3: Run specs to verify failure**

Run: `bundle exec rspec spec/components/admin/ spec/requests/admin/`

Expected: FAIL — both fail (`uninitialized constant Admin::DashboardComponent` for component; routing error for request).

- [ ] **Step 4: Create the Admin component**

Create `app/components/admin/dashboard_component.rb`:

```ruby
module Admin
  class DashboardComponent < ViewComponent::Base
  end
end
```

Create `app/components/admin/dashboard_component.html.erb`:

```erb
<div class="min-h-screen bg-slate-900 text-slate-100 px-4 py-12">
  <div class="mx-auto max-w-3xl">
    <h1 class="text-3xl font-bold tracking-tight">Admin dashboard</h1>
    <p class="mt-4 text-slate-400">Coming soon. Campaign authoring lands in Phase 3.</p>
    <%= button_to "Sign out",
                  main_app.destroy_user_session_url(subdomain: ""),
                  method: :delete,
                  class: "mt-8 text-xs uppercase tracking-widest text-slate-500 hover:text-slate-300" %>
  </div>
</div>
```

The `subdomain: ""` on the sign-out URL forces it to apex (where the Devise sessions controller lives). `main_app.` namespace is harmless even when Devise isn't engine-mounted; included for clarity.

- [ ] **Step 5: Create Admin::ApplicationController**

Create `app/controllers/admin/application_controller.rb`:

```ruby
module Admin
  class ApplicationController < ::ApplicationController
    before_action :authenticate_user!
  end
end
```

- [ ] **Step 6: Create Admin::DashboardController**

Create `app/controllers/admin/dashboard_controller.rb`:

```ruby
module Admin
  class DashboardController < ApplicationController
    def show
      render Admin::DashboardComponent.new
    end
  end
end
```

- [ ] **Step 7: Add admin routes**

Edit `config/routes/admin.rb`:

```ruby
constraints subdomain: "admin" do
  scope module: "admin" do
    root "dashboard#show", as: :admin_root
    get "/dashboard", to: "dashboard#show", as: :admin_dashboard
  end
end
```

- [ ] **Step 8: Create Lookbook preview (optional, follows Phase 1 pattern)**

Create `test/components/previews/admin/dashboard_component_preview.rb`:

```ruby
module Admin
  class DashboardComponentPreview < ViewComponent::Preview
    def default
      render Admin::DashboardComponent.new
    end
  end
end
```

(If `test/components/previews/` doesn't exist, follow whatever convention Phase 1 established for the existing `Pages::HomeComponent` preview, if any. If no Lookbook previews exist yet, skip this step and defer to a polish task.)

- [ ] **Step 9: Run specs to verify pass**

Run: `bundle exec rspec spec/components/admin/ spec/requests/admin/`

Expected: PASS — 3 examples (1 component, 2 request).

- [ ] **Step 10: Manual smoke test (optional)**

Run: `bin/dev`.

In a browser, visit `http://admin.lvh.me:3000/dashboard`.

Expected: 302 redirect to `http://lvh.me:3000/users/sign_in` (the Devise sign-in form).

Stop the server.

- [ ] **Step 11: Commit**

```bash
git add app/controllers/admin/ app/components/admin/ spec/components/admin/ \
        spec/requests/admin/ config/routes/admin.rb \
        test/components/previews/admin/ 2>/dev/null
git commit -m "Add admin subdomain shell (controller + component + routes)

Admin::ApplicationController authenticates users; Admin::DashboardController#show
renders an empty placeholder. Admin routes live in config/routes/admin.rb
under the 'admin' subdomain constraint and 'admin' module scope.
Sign-out button on the dashboard targets apex via subdomain: ''."
```

---

## Task 12: ApplicationController overrides (after_sign_in / after_sign_out)

**Files:**
- Modify: `app/controllers/application_controller.rb`

- [ ] **Step 1: Add overrides**

Open `app/controllers/application_controller.rb`. Add:

```ruby
class ApplicationController < ActionController::Base
  # Phase 1 default behavior + Phase 2 Devise overrides.

  protected

  def after_sign_in_path_for(_resource)
    admin_dashboard_url(subdomain: "admin")
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_url(subdomain: "")
  end
end
```

Preserve any existing content in `ApplicationController` (e.g., `allow_browser versions: :modern` if Phase 1 added it). Add the methods inside the class body, marked `protected`.

- [ ] **Step 2: Verify boot**

Run: `bin/rails runner 'puts "ok"'`

Expected: prints `ok`.

- [ ] **Step 3: Manual verification**

Run: `bin/dev`. Create a user via console:

```bash
bin/rails runner "User.create!(email: 'test@local.test', password: 'correct horse battery staple')"
```

In a browser:
1. Visit `http://admin.lvh.me:3000/dashboard` → redirects to sign-in at `http://lvh.me:3000/users/sign_in`.
2. Submit with `test@local.test` / `correct horse battery staple`.
3. Expected: redirected to `http://admin.lvh.me:3000/dashboard`, dashboard renders.
4. Click "Sign out" on the dashboard.
5. Expected: redirected to `http://lvh.me:3000/` (apex root), Play home renders, no longer signed in.

Stop the server.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/application_controller.rb
git commit -m "ApplicationController overrides for cross-subdomain auth redirects

after_sign_in_path_for stubs to the admin dashboard (Phase 3 will
replace with campaign-aware logic). after_sign_out_path_for routes
to apex root regardless of which subdomain the user signed out from."
```

---

## Task 13: Cross-subdomain session spec

**Files:**
- Create: `spec/requests/cross_subdomain_session_spec.rb`

- [ ] **Step 1: Write the spec**

Create `spec/requests/cross_subdomain_session_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Cross-subdomain session", type: :request do
  let(:password) { "correct horse battery staple" }
  let(:user) { create(:user, password: password, password_confirmation: password) }

  it "carries a session from apex to admin without re-auth" do
    # Sign in at apex.
    host! "gygaxagain.com"
    post "/users/sign_in",
         params: { user: { email: user.email, password: password } }

    expect(response).to have_http_status(:found)
    expect(response.location).to include("admin.gygaxagain.com")

    # Navigate to admin. The session cookie set on the apex response should be
    # sent with this request because Rack::Test's cookie jar respects the
    # domain attribute (which our session_store sets to .gygaxagain.com via
    # domain: :all + tld_length: 2).
    host! "admin.gygaxagain.com"
    get "/dashboard"

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/admin dashboard/i)
  end
end
```

- [ ] **Step 2: Run the spec**

Run: `bundle exec rspec spec/requests/cross_subdomain_session_spec.rb`

Expected: PASS. (All the wiring this spec exercises was put in place by Tasks 6 + 7 + 9 + 11 + 12.)

If it fails: likely culprits are (a) cookie domain config in `config/initializers/session_store.rb`, (b) `default_url_options` in `config/environments/test.rb`, or (c) the `after_sign_in_path_for` override. Debug accordingly.

- [ ] **Step 3: Commit**

```bash
git add spec/requests/cross_subdomain_session_spec.rb
git commit -m "Test cross-subdomain session flow (apex sign-in -> admin access)

Verifies the cookie shared via domain: :all + tld_length: 2 carries
the session across the apex/admin boundary."
```

---

## Task 14: www subdomain redirect spec

**Files:**
- Create: `spec/requests/www_redirect_spec.rb`

The redirect itself was added in Task 8 (top-level `routes.rb`). This task just adds the test.

- [ ] **Step 1: Write the spec**

Create `spec/requests/www_redirect_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "www subdomain", type: :request do
  it "301-redirects to apex preserving the path" do
    host! "www.gygaxagain.com"
    get "/users/sign_in"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("http://gygaxagain.com/users/sign_in")
  end

  it "301-redirects the root path" do
    host! "www.gygaxagain.com"
    get "/"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("http://gygaxagain.com/")
  end
end
```

- [ ] **Step 2: Run the spec**

Run: `bundle exec rspec spec/requests/www_redirect_spec.rb`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add spec/requests/www_redirect_spec.rb
git commit -m "Test www.gygaxagain.com 301-redirect to apex

Verifies the route-level redirect added in Task 8."
```

---

## Task 15: Rake task `users:create` + spec

**Files:**
- Create: `lib/tasks/users.rake`
- Create: `spec/lib/tasks/users_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/lib/tasks/users_spec.rb`:

```ruby
require "rails_helper"
require "rake"

RSpec.describe "users.rake" do
  before(:all) do
    Rails.application.load_tasks
  end

  let(:task) { Rake::Task["users:create"] }

  before { task.reenable }

  describe "users:create" do
    let(:email) { "rake-test@example.test" }
    let(:password) { "correct horse battery staple" }

    after do
      ENV.delete("EMAIL")
      ENV.delete("PASSWORD")
    end

    it "creates a user from EMAIL/PASSWORD env vars" do
      ENV["EMAIL"] = email
      ENV["PASSWORD"] = password

      expect { task.invoke }.to change(User, :count).by(1)
      expect(User.find_by(email: email)).to be_present
    end

    it "aborts when EMAIL is missing" do
      ENV["PASSWORD"] = password

      expect { task.invoke }.to raise_error(SystemExit, /EMAIL required/)
    end

    it "aborts when PASSWORD is missing" do
      ENV["EMAIL"] = email

      expect { task.invoke }.to raise_error(SystemExit, /PASSWORD required/)
    end
  end
end
```

- [ ] **Step 2: Run spec to verify failure**

Run: `bundle exec rspec spec/lib/tasks/users_spec.rb`

Expected: FAIL — `Don't know how to build task 'users:create'`.

- [ ] **Step 3: Implement the rake task**

Create `lib/tasks/users.rake`:

```ruby
namespace :users do
  desc "Create a user. Usage: bin/rails users:create EMAIL=foo@bar.com PASSWORD=secret"
  task create: :environment do
    email = ENV["EMAIL"] or abort "EMAIL required"
    password = ENV["PASSWORD"] or abort "PASSWORD required"

    user = User.create!(email: email, password: password, password_confirmation: password)
    puts "Created user ##{user.id} (#{user.email})"
  end
end
```

- [ ] **Step 4: Run spec to verify pass**

Run: `bundle exec rspec spec/lib/tasks/users_spec.rb`

Expected: PASS — 3 examples.

- [ ] **Step 5: Commit**

```bash
git add lib/tasks/users.rake spec/lib/tasks/users_spec.rb
git commit -m "Add users:create rake task for manual user provisioning

Alpha is invite-only; account creation happens via rake task on
Heroku (heroku run rake users:create EMAIL=... PASSWORD=... -a gygaxagain).
Aborts with a clear message if EMAIL or PASSWORD is missing."
```

---

## Task 16: System spec for full sign-in journey

**Files:**
- Create: `spec/system/sign_in_spec.rb`

- [ ] **Step 1: Write the spec**

Create `spec/system/sign_in_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Sign in", type: :system do
  before do
    driven_by :rack_test
    Capybara.app_host = "http://gygaxagain.com"
  end

  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  it "signs in via the apex form and lands on the admin dashboard" do
    visit "/users/sign_in"
    expect(page).to have_field("Email")
    expect(page).to have_field("Password")

    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"

    # After sign-in we should be on the admin dashboard.
    expect(current_url).to include("admin.gygaxagain.com")
    expect(page).to have_text(/admin dashboard/i)
  end
end
```

`driven_by :rack_test` avoids the Selenium/DNS-resolution complexity for this single Phase 2 system spec. No JavaScript on the sign-in form means rack_test is sufficient.

If the button label is different on the default Devise sign-in form (e.g., "Sign in" rather than "Log in"), update the `click_button` argument to match. The default Devise locale uses "Log in".

- [ ] **Step 2: Run the spec**

Run: `bundle exec rspec spec/system/sign_in_spec.rb`

Expected: PASS.

If failing on the click_button label: open `config/locales/devise.en.yml` and check the `sign_in` key under `devise.sessions.new`. Update the spec to match the actual button label.

- [ ] **Step 3: Commit**

```bash
git add spec/system/sign_in_spec.rb
git commit -m "Add system spec for the full sign-in journey

Uses rack_test driver (no JS needed for the sign-in form, and it
avoids Selenium/DNS resolution complexity for cross-subdomain hosts).
Covers: visit apex sign-in form, fill credentials, click submit,
verify redirect to admin dashboard."
```

---

## Task 17: README updates

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README**

Edit `README.md`. Make four updates:

**a.** In the "Local development" section, update the URL from `http://localhost:3000` to `http://lvh.me:3000`. Add a brief explanation.

Replace:

```markdown
Visit `http://localhost:3000`.
```

with:

```markdown
Visit `http://lvh.me:3000` (apex) or `http://admin.lvh.me:3000` (admin subdomain).

`lvh.me` is a public DNS service that resolves `*.lvh.me` to `127.0.0.1`,
so subdomain routing works locally without `/etc/hosts` edits.
```

**b.** Add a new top-level "Authentication" section between "Local development" and "Deploy":

```markdown
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
```

**c.** In the "Deploy" section, add `admin.gygaxagain.com` to the list of domains served by the Heroku app:

After the existing Heroku setup paragraph, add:

```markdown
The Heroku app serves two domains: `gygaxagain.com` (play surface) and
`admin.gygaxagain.com` (campaign management). Both terminate at the same
dyno; Rails subdomain routing dispatches.
```

**d.** Verify the "Tech" section already mentions Devise (it does, per the spec — line 17 of README mentions "Authentication via Devise … added in Phase 2"). No edit needed for `d`.

- [ ] **Step 2: Verify formatting**

Run: `cat README.md | head -50` (or open in editor).

Confirm the new sections render correctly with proper headings and code-block fencing.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Update README for Phase 2 (auth + subdomain split)

Local dev URLs use lvh.me. New 'Authentication' section documents
manual user creation via rake task, sign-in URL, cookie-scoping
behavior, and the SMTP env vars that gate password-reset."
```

---

## Task 18: Full local verification + push + Heroku deploy

End-to-end verification before declaring Phase 2 done.

**Files:** none (verification only).

- [ ] **Step 1: Full local test suite**

Run: `bundle exec rspec`

Expected: PASS — all specs (including the existing Phase 1 health-check-equivalent, plus all Phase 2 additions).

- [ ] **Step 2: Static analysis**

Run: `bin/brakeman` and `bin/rubocop` and `bundle exec erb_lint --lint-all` in parallel (if your shell supports it, or sequentially):

```bash
bin/brakeman --no-pager && bin/rubocop && bundle exec erb_lint --lint-all
```

Expected: all three pass without errors. Warnings are acceptable but not preferred.

- [ ] **Step 3: Local end-to-end smoke**

Run: `bin/dev` in one terminal. In another:

```bash
bin/rails users:create EMAIL=smoke@local.test PASSWORD="correct horse battery staple"
```

In a browser, manually verify the four acceptance criteria from the issue:

1. **Sign-in at apex.** Visit `http://lvh.me:3000/users/sign_in`. Sign in. Expect: redirected to `http://admin.lvh.me:3000/dashboard`, dashboard renders.
2. **Sign-up returns 404.** Visit `http://lvh.me:3000/users/sign_up`. Expect: 404 page (development mode shows a Rails routing error page; that's the dev equivalent of a 404).
3. **Cross-subdomain session.** After signing in at apex, manually navigate to `http://lvh.me:3000/` — dashboard sign-out link visible (or your component's equivalent indicator). Then `http://admin.lvh.me:3000/dashboard` — still signed in, no re-auth prompt.
4. **Admin requires auth.** Sign out. Visit `http://admin.lvh.me:3000/dashboard`. Expect: redirect to `http://lvh.me:3000/users/sign_in`.

Stop the server.

- [ ] **Step 4: Push to feature branch + watch CI**

```bash
git push -u origin phase-2-devise-subdomain-admin
```

Open the GitHub Actions tab. Wait for the workflow to complete.

Expected: green. If red, fix the failing job locally and push again.

- [ ] **Step 5: Open PR + merge**

```bash
gh pr create --title "v2 Phase 2 — Devise + subdomain split + admin shell" \
  --body "$(cat <<'EOF'
## Summary
- Adds Devise authentication (no registerable, no confirmable) on a User model with 7 modules
- Splits routes into apex (`gygaxagain.com`) and admin (`admin.gygaxagain.com`) via subdomain constraints
- Shares Devise session across subdomains via cookie `domain: :all, tld_length: 2`
- Admin dashboard is an empty placeholder; real authoring lands in Phase 3
- Manual user provisioning via `rake users:create EMAIL=... PASSWORD=...`

## Spec
- [Design spec](docs/superpowers/specs/2026-05-13-v2-phase-2-devise-subdomain-admin-design.md)
- [Implementation plan](docs/superpowers/plans/2026-05-13-v2-phase-2-devise-subdomain-admin.md)

## Test plan
- [x] Sign-in at apex works; sign-up returns 404
- [x] Cross-subdomain session persists without re-auth
- [x] Admin requires auth, shows empty dashboard placeholder
- [x] `rake users:create` works
- [x] CI green (RSpec + Brakeman + RuboCop + erb_lint)
- [ ] Production deploy verified (apex sign-in + admin access via real domains)

Closes #3.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Verify CI green on the PR, then merge.

- [ ] **Step 6: Heroku deploy**

If Heroku is configured to auto-deploy `main`, this happens automatically on merge. Otherwise:

```bash
git checkout main
git pull
git push heroku main
```

Watch the deploy. Expected: build succeeds, release phase runs `db:migrate` (creating the `users` table on Heroku Postgres), web dynos restart.

- [ ] **Step 7: Heroku production smoke**

Run: `heroku run "rake users:create EMAIL=jeff@barriault.net PASSWORD=<real-password>" -a gygaxagain`

(Use a strong real password — this is the first real user on production.)

In a browser, verify all four acceptance criteria against the live domains:

1. `https://gygaxagain.com/users/sign_in` renders, sign-in works.
2. `https://gygaxagain.com/users/sign_up` returns 404.
3. After signing in at apex, navigate to `https://admin.gygaxagain.com/dashboard` — still signed in.
4. Sign out from admin; navigate back to `https://admin.gygaxagain.com/dashboard`; redirected to apex sign-in.

- [ ] **Step 8: Close the issue**

```bash
gh issue close 3 --comment "Phase 2 acceptance criteria all verified in production. Sub-issue closed; v2 parent issue #1 remains open through Phase 9."
```

Update the issue body's "Phase design spec" and "Implementation plan" links from "_TBD_" to the actual paths:

```bash
gh issue edit 3 --body "..."  # paste the full updated body
```

Or via the web UI. The links should point to:
- `docs/superpowers/specs/2026-05-13-v2-phase-2-devise-subdomain-admin-design.md`
- `docs/superpowers/plans/2026-05-13-v2-phase-2-devise-subdomain-admin.md`

---

## Self-review

**Spec coverage:**

| Spec section / requirement | Task(s) |
|---|---|
| Local-dev hostname `lvh.me:3000` | 7 (dev default_url_options), 17 (README) |
| `www.gygaxagain.com` redirect | 8 (route), 14 (spec) |
| Skip Devise view generation | (intentionally absent — no generator invocation) |
| Routes-split mechanism via `draw(:name)` | 8 |
| Cross-subdomain URL generation (default_url_options) | 2 (test), 7 (dev+prod) |
| Sign-out target = apex root | 12 |
| `Pages::HomeComponent` → `Play::HomeComponent` migration | 10 |
| Session store config (cookie, tld_length: 2, same_site) | 6 |
| Letter_opener in dev; SMTP in prod with raise_delivery_errors: false | 3 (gem), 7 (config) |
| Devise tuning (timeout 30d, password 12..128, parent_controller) | 4 |
| Gemfile additions (devise, letter_opener) | 3 |
| Devise install | 4 |
| User model + migration | 5 |
| Initializers (devise, session_store, filter_parameter_logging) | 4 (devise + filter), 6 (session_store) |
| Routes (top-level, play, admin) | 8, 9, 10, 11 |
| Controllers (Play::ApplicationController, Play::HomeController, Admin::ApplicationController, Admin::DashboardController) | 10, 11 |
| Delete PagesController | 10 |
| Components (Play::HomeComponent, Admin::DashboardComponent) | 10, 11 |
| Views (admin/dashboard/show.html.erb) — note: render-component-directly pattern means no view file is needed | 11 |
| Rake task | 15 |
| All listed specs | 5, 9, 10, 11, 13, 14, 15, 16 |
| README updates | 17 |
| Cloudflare + Heroku setup | 1 |
| Heroku deploy + smoke | 18 |

Every spec requirement maps to a task. Notable omission: the "view file" rows in the spec's File Inventory said to create `app/views/admin/dashboard/show.html.erb` and `app/views/play/home/show.html.erb`. The plan opts instead for `render Play::HomeComponent.new` / `render Admin::DashboardComponent.new` directly from the controller `#show` action, which is the idiomatic ViewComponent pattern and skips the unnecessary view-file stub. This is a tightening of the spec and is called out in Task 10 Step 8.

**Placeholder scan:** Searched for "TBD", "TODO", "implement later", "similar to". None present in plan body. The references to "_TBD_" in the GitHub issue's spec/plan links section in Task 18 are about the issue body, not the plan itself.

**Type / method consistency:**

- `Play::HomeComponent` — declared in Task 10, used in `Play::HomeController#show` (Task 10) and `spec/components/play/home_component_spec.rb` (Task 10). ✓
- `Admin::DashboardComponent` — declared in Task 11, used in `Admin::DashboardController#show` (Task 11) and spec (Task 11). ✓
- `User.devise_modules` — asserted in Task 5 spec to be exactly the 7 modules; the User model definition in Task 5 declares exactly those 7. ✓
- `after_sign_in_path_for` returns `admin_dashboard_url(subdomain: "admin")` (Task 12); `admin_dashboard` named route is declared in `config/routes/admin.rb` (Task 11). ✓
- `after_sign_out_path_for` returns `root_url(subdomain: "")` (Task 12); apex root is declared in `config/routes/play.rb` (Task 10). ✓
- `destroy_user_session_url(subdomain: "")` in `Admin::DashboardComponent` template (Task 11); Devise sessions controller registered in apex play.rb (Task 9). ✓
- `users:create` rake task signature uses `ENV["EMAIL"]`, `ENV["PASSWORD"]`; spec passes those exact ENV vars. ✓
- Test default host `gygaxagain.com` (Task 2) matches the Capybara host (Task 2) and the cross-subdomain spec's `host!` calls (Task 13). ✓

No inconsistencies found.

**Scope check:** Phase 2 is bounded to auth + subdomain split + admin shell. No campaign concept, no real after-sign-in redirect logic, no Pundit, no asymmetry layer. Plan stays inside that envelope.

**Out-of-scope items called out** in the design spec are respected by the plan:
- No Devise view customization (Tailwind on sign-in form deferred).
- No `last_played_campaign_id` column (Phase 3).
- No admin-specific layout (`application.html.erb` serves both subdomains).
- No working password reset (env vars blank in prod).
- No Pundit / action_policy.
