# v2 Phase 2 — Devise + subdomain split + admin shell

Date: 2026-05-13
Status: Design spec. Drives the writing-plans pass for Phase 2.
Issue: [#3](https://github.com/barriault/gygaxagain/issues/3)
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md)

## Scope

Add authentication and the URL-space split. Sign-in works at apex; the admin subdomain requires authentication and exists as an empty shell. No data models beyond `User`. No campaign concept yet (Phase 3).

## Dependencies

Phase 1 (#2) complete: Rails 8 skeleton on Heroku, landing page at `https://gygaxagain.com`, CI green, ViewComponent and RSpec in place.

## Acceptance criteria

Verbatim from the GitHub issue:

- Sign-in at `https://gygaxagain.com/users/sign_in` works; sign-up returns 404.
- Cross-subdomain session: a signed-in user can navigate between apex and `admin.gygaxagain.com` without re-auth.
- `https://admin.gygaxagain.com` resolves, requires auth, shows an empty dashboard placeholder.
- Manual user creation works via `rake users:create EMAIL=... PASSWORD=...`.
- All tests green; CI green.

## Architectural commitments inherited from Phase 0

Phase 0 already locks the auth, routing, controller-namespacing, and ViewComponent-namespacing decisions. This spec does not re-litigate them. Key inherited commitments (see `2026-05-13-v2-phase-0-roadmap-design.md` for full rationale):

- **Devise** with `:database_authenticatable, :recoverable, :rememberable, :validatable, :trackable, :timeoutable, :lockable`. No `:registerable`, no `:confirmable`.
- **Sign-in URL** at apex only. `devise_for :users, skip: [:registrations]`.
- **Cross-subdomain session** via cookie `domain: :all, tld_length: 2`.
- **Routes split** into `config/routes/play.rb` (subdomain `""`) and `config/routes/admin.rb` (subdomain `"admin"`).
- **Controller namespaces** `Play::ApplicationController` and `Admin::ApplicationController`, both descending from `ApplicationController`. Admin base has `before_action :authenticate_user!`.
- **ViewComponent namespaces** `app/components/play/` and `app/components/admin/`.
- **Pundit / action_policy deferred.** Phase 2 has no campaigns yet, so scoping is trivial.
- **ActionMailer SMTP via ENV; blank in alpha.** Password reset will silently fail in production until SMTP is wired. Acceptable for invite-only alpha.
- **Manual user creation** via `rake users:create EMAIL=... PASSWORD=...`.
- **After-sign-in stub** redirects to admin dashboard. Real campaign-aware redirect logic comes in Phase 3.

## Open decisions resolved in this spec

The points Phase 0 left open, with decisions baked in here.

### Local-dev hostname: `lvh.me:3000`

The cross-subdomain cookie config (`domain: :all, tld_length: 2`) requires a 2-part hostname locally; `localhost` is a single part and won't work.

**Decision:** use `http://lvh.me:3000` for apex and `http://admin.lvh.me:3000` for admin during local development. `lvh.me` is a public DNS service that resolves `*.lvh.me` to 127.0.0.1, so subdomain routing works without `/etc/hosts` edits. `tld_length: 2` treats `lvh.me` the same as `gygaxagain.com`.

README is updated in this phase to show `http://lvh.me:3000` as the local URL.

### `www.gygaxagain.com` handling

The two production routes match subdomains `""` (apex) and `"admin"`. Anything else (notably `www`) would 404 under Rails default behavior.

**Decision:** add a route-level redirect from `www` subdomain to apex, in `config/routes.rb`:

```ruby
constraints subdomain: "www" do
  get "(*any)", to: redirect(status: 301) { |_params, req|
    "#{req.protocol}#{req.host.sub(/^www\./, '')}#{req.fullpath}"
  }
end
```

Belt-and-suspenders. Cloudflare may also be configured to do this, but the app does not depend on it. (Note: `redirect` ignores positional/keyword args when given a block — the block returns the full target URL on its own.)

### Devise view generation: skipped in Phase 2

**Decision:** do not run `rails g devise:views` in Phase 2. Default Devise views are functional. The only Devise view a user actually hits in alpha is the sign-in form (signup is disabled; password reset fails without SMTP). Tailwind styling of the sign-in form is deferred to a polish phase (likely alongside Phase 6 play-surface UI work).

### Routes-split mechanism

`config/routes.rb` uses Rails' built-in `draw(:name)` to load the sub-files:

```ruby
Rails.application.routes.draw do
  draw(:play)
  draw(:admin)

  constraints subdomain: "www" do
    get "(*any)", to: redirect(subdomain: "") { |_params, req|
      "#{req.protocol}#{req.host.sub(/^www\./, '')}#{req.fullpath}"
    }
  end

  get "up" => "rails/health#show", as: :rails_health_check
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?
end
```

`config/routes/play.rb`:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [:registrations]
  root "play/home#show"
end
```

`config/routes/admin.rb`:

```ruby
constraints subdomain: "admin" do
  scope module: "admin" do
    root "dashboard#show", as: :admin_root
    get "/dashboard", to: "dashboard#show", as: :admin_dashboard
  end
end
```

### Cross-subdomain URL generation

Even with a shared session cookie, URL generation needs to know how to construct an apex URL from an admin request and vice versa. Configure per-environment defaults:

(Note on `tld_length`: ActionDispatch routing uses `Rails.application.config.action_dispatch.tld_length` for subdomain extraction. The default of `1` works for both `*.gygaxagain.com` and `*.lvh.me` and does not need adjustment. The `tld_length: 2` in the session_store initializer is a separate parameter for cookie-domain scope when `domain: :all` is set; the two are unrelated despite the shared name.)

```ruby
# config/environments/production.rb
config.action_controller.default_url_options = { host: "gygaxagain.com", protocol: "https" }
config.action_mailer.default_url_options     = { host: "gygaxagain.com", protocol: "https" }

# config/environments/development.rb
config.action_controller.default_url_options = { host: "lvh.me", port: 3000 }
config.action_mailer.default_url_options     = { host: "lvh.me", port: 3000 }
```

In test (`config/environments/test.rb`):

```ruby
config.action_controller.default_url_options = { host: "gygaxagain.com" }
```

Routes generated with `subdomain: ""` resolve to apex; `subdomain: "admin"` resolves to admin.

### Sign-out target

Sign-out always lands on apex root, regardless of which subdomain the user signed out from:

```ruby
# app/controllers/application_controller.rb
def after_sign_out_path_for(_resource_or_scope)
  root_url(subdomain: "")
end
```

This means: sign out from admin → redirect to `gygaxagain.com/` (the play home shell). The session cookie has already been destroyed by the time of redirect.

### After-sign-in path stub

Phase 2's stub:

```ruby
def after_sign_in_path_for(_resource)
  admin_dashboard_url(subdomain: "admin")
end
```

Phase 3 replaces this with the three-case redirect logic (last-played campaign / has-campaigns / no-campaigns).

### Existing `Pages::HomeComponent` migration

Phase 1 produced `PagesController#home` and `Pages::HomeComponent`. Phase 2 moves these under the Play namespace:

| Phase 1 | Phase 2 |
|---|---|
| `app/controllers/pages_controller.rb` | `app/controllers/play/home_controller.rb` |
| `app/components/pages/home_component.rb` | `app/components/play/home_component.rb` |
| `app/components/pages/home_component.html.erb` | `app/components/play/home_component.html.erb` |
| `spec/requests/pages_spec.rb` (if exists) | `spec/requests/play/home_spec.rb` |
| `spec/components/pages/home_component_spec.rb` (if exists) | `spec/components/play/home_component_spec.rb` |
| `root "pages#home"` in `config/routes.rb` | `root "play/home#show"` in `config/routes/play.rb` |

Page content does not change. Controller action renames from `#home` to `#show` (REST-ier, and there's only one resource here).

### Session store config

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: "_gygaxagain_session",
  domain: :all,
  tld_length: 2,
  same_site: :lax,
  secure: Rails.env.production?
```

`same_site: :lax` is the modern safe default for cookies that need to survive top-level navigation. `secure: true` only in production (lvh.me is HTTP in development).

### ActionMailer development delivery

Add `letter_opener` to the development group. Configure:

```ruby
# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
```

Production ActionMailer uses SMTP from ENV (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM`); all blank in alpha:

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address:        ENV["SMTP_HOST"],
  port:           ENV.fetch("SMTP_PORT", 587).to_i,
  user_name:      ENV["SMTP_USER"],
  password:       ENV["SMTP_PASS"],
  authentication: :plain,
  enable_starttls_auto: true
}
config.action_mailer.raise_delivery_errors = false  # silent failure in alpha
config.action_mailer.perform_deliveries    = true
```

`raise_delivery_errors = false` means password-reset emails to a misconfigured SMTP host fail silently rather than 500ing the request. The user sees the standard "if your email exists, we sent instructions" Devise flash either way.

### Devise tuning

- `config.timeout_in = 30.days` — long-form play surface; default 30 minutes is painful.
- `config.password_length = 12..128` — bumped from Devise default `6..128`. Habit worth keeping even for one user.
- All other Devise defaults stand (lockable thresholds, remember_for, etc.).
- `config.parent_controller = "ApplicationController"` — explicit, so Devise controllers inherit our application-wide concerns.

## File inventory

Every file added or modified in Phase 2, grouped by area. This is the canonical list for the implementation plan.

### Gemfile additions

```ruby
gem "devise"

group :development do
  gem "letter_opener"
end
```

Run `bundle install`. Commit `Gemfile` and `Gemfile.lock`.

### Devise install

- `bin/rails g devise:install` — generates `config/initializers/devise.rb` and prints post-install steps.
- Edit `config/initializers/devise.rb`:
  - `config.mailer_sender = ENV.fetch("MAIL_FROM", "no-reply@gygaxagain.com")`
  - `config.password_length = 12..128`
  - `config.timeout_in = 30.days`
  - `config.parent_controller = "ApplicationController"`
  - Other defaults left as-generated.

### User model + migration

- `bin/rails g devise User` — generates the User model and the Devise migration.
- Edit the generated migration to add `:trackable`, `:lockable`, `:timeoutable` columns. Remove `:confirmable` columns (not used). The Devise generator includes most of these as commented blocks; uncomment trackable/lockable, leave confirmable commented.
- `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :trackable, :timeoutable, :lockable
end
```

- `bin/rails db:migrate`.

### Initializers

- `config/initializers/devise.rb` — generated, then edited per above.
- `config/initializers/session_store.rb` — new file with cookie-store config.
- `config/initializers/filter_parameter_logging.rb` — Devise generator adds `:password` and `:password_confirmation` to the filter list. Verify post-generation.

### Routes

- `config/routes.rb` — replace existing `root "pages#home"` line with `draw(:play)` / `draw(:admin)` / www-redirect / health-check / Lookbook mount.
- `config/routes/play.rb` — new file. Apex routes.
- `config/routes/admin.rb` — new file. Admin subdomain routes.

### Controllers

- `app/controllers/application_controller.rb` — add `after_sign_in_path_for` and `after_sign_out_path_for` overrides.
- `app/controllers/play/application_controller.rb` — new. Base for play-surface controllers. No auth requirement (play home is currently public; campaign-scoped auth comes in Phase 3).
- `app/controllers/play/home_controller.rb` — new. `#show` action; renders `Play::HomeComponent`.
- `app/controllers/admin/application_controller.rb` — new. `before_action :authenticate_user!`. Layout-overridable; no other behavior in Phase 2.
- `app/controllers/admin/dashboard_controller.rb` — new. `#show` action; renders `Admin::DashboardComponent`.
- **Delete** `app/controllers/pages_controller.rb`.

### Views

- `app/views/play/home/show.html.erb` — new, single line: `<%= render Play::HomeComponent.new %>`.
- `app/views/admin/dashboard/show.html.erb` — new, single line: `<%= render Admin::DashboardComponent.new %>`.
- `app/views/layouts/admin.html.erb` (optional, Phase 2 scope-defer) — a minimal admin layout. **Decision: defer.** Use the existing `application.html.erb` for both subdomains; Phase 6 introduces a real layout split if needed. Document this in §"Out of scope".
- **Delete** `app/views/pages/` directory if it exists.

### Components

- **Move:** `app/components/pages/home_component.{rb,html.erb}` → `app/components/play/home_component.{rb,html.erb}`. Rename class `Pages::HomeComponent` → `Play::HomeComponent`. Content unchanged.
- **Add:** `app/components/admin/dashboard_component.{rb,html.erb}` — empty-state placeholder. Renders "Admin dashboard — coming soon." plus a sign-out link.
- **Add:** Lookbook preview for `Admin::DashboardComponent` (mirrors Phase 1 pattern).

### Rake task

- `lib/tasks/users.rake` — new:

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

### Environment configs

- `config/environments/production.rb` — add `default_url_options` for both action_controller and action_mailer. Add SMTP config block with ENV reads. Set `raise_delivery_errors = false`.
- `config/environments/development.rb` — add `default_url_options` for both action_controller and action_mailer. Set `delivery_method = :letter_opener`.
- `config/environments/test.rb` — add `default_url_options = { host: "gygaxagain.com" }`.

### Specs

- `spec/system/sign_in_spec.rb` — system spec; full sign-in journey on `gygaxagain.com`. Capybara host set via `Capybara.default_host` and `Capybara.app_host`.
- `spec/requests/devise_routes_spec.rb` — sign-up route returns 404; sign-in form renders; sign-in POST with valid creds redirects to admin dashboard; sign-in POST with invalid creds re-renders form.
- `spec/requests/cross_subdomain_session_spec.rb` — sign in on apex, then GET admin dashboard with the resulting session cookie, expect 200.
- `spec/requests/admin/dashboard_spec.rb` — GET admin dashboard without auth → 302 to sign-in; with auth → 200 rendering dashboard component.
- `spec/requests/play/home_spec.rb` — GET apex root renders 200 with `Play::HomeComponent` content.
- `spec/requests/www_redirect_spec.rb` — GET `www.gygaxagain.com/foo` → 301 redirect to `gygaxagain.com/foo`.
- `spec/lib/tasks/users_spec.rb` — invokes the rake task with EMAIL/PASSWORD ENV, asserts user created. Asserts task fails clearly when EMAIL or PASSWORD missing.
- `spec/components/play/home_component_spec.rb` — moved from `spec/components/pages/...`. Class rename.
- `spec/components/admin/dashboard_component_spec.rb` — new. Renders without error.
- `spec/factories/users.rb` — new factory:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.test" }
    password { "correct horse battery staple" }
  end
end
```

- `spec/rails_helper.rb` — verify `Devise::Test::IntegrationHelpers` is included for request/system specs; add if missing. Verify `host!` defaults to `gygaxagain.com` for request specs (set in `config.before(:each, type: :request) { host! "gygaxagain.com" }`).

### Capybara host config

- `spec/support/capybara.rb` (new or existing):

```ruby
Capybara.default_host = "http://gygaxagain.com"
Capybara.app_host     = "http://gygaxagain.com"
Capybara.always_include_port = true
```

For system specs that need to hit `admin.gygaxagain.com`, the spec uses `Capybara.app_host = "http://admin.gygaxagain.com"` within an around block. Phase 2 only has one system spec (sign-in flow at apex) so this is theoretical for now.

### README updates

- Add an "Authentication" section describing the manual-user-creation rake task and the sign-in URL.
- Update "Local development" to reference `http://lvh.me:3000` (and `http://admin.lvh.me:3000`) as the local URLs.
- Add a note that signup is disabled and password reset requires SMTP env vars.

## Heroku + Cloudflare setup

Pre-implementation infrastructure work (done once, manual):

1. **Cloudflare:** add CNAME record `admin` → Heroku DNS target (the same target Phase 1 used for apex). Proxy off (DNS-only) to start; flip to proxy on after SSL verifies.
2. **Heroku:** `heroku domains:add admin.gygaxagain.com -a gygaxagain`. Take note of the DNS target Heroku returns; should match what's already configured on Cloudflare for apex.
3. **SSL:** `heroku certs:auto:enable -a gygaxagain` (idempotent if already enabled). Wait for cert to provision for `admin.gygaxagain.com`. Verify `https://admin.gygaxagain.com` returns a valid TLS handshake (will 404 from Rails until the deploy lands, which is expected).
4. **Heroku config vars:** set placeholders to document intent, even if blank:
   - `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM` — all left blank.
   - `SECRET_KEY_BASE` — already set by Heroku post-Phase 1.

## Implementation-level sequence

A refined version of Phase 0's Phase 2 detail sequence:

1. **Cloudflare + Heroku DNS for `admin.gygaxagain.com`** (per §"Heroku + Cloudflare setup"). Verify the apex DNS still resolves.
2. **Add gems:** `devise`, `letter_opener` (dev). `bundle install`. Commit.
3. **Devise install:** `bin/rails g devise:install`. Edit `config/initializers/devise.rb` per §"Devise tuning". Commit.
4. **User model + migration:** `bin/rails g devise User`. Edit migration to enable trackable/lockable/timeoutable columns, remove confirmable columns. `bin/rails db:migrate`. Edit `app/models/user.rb` to enable the right modules. Annotate with `annotaterb`. Commit migration + model + schema together.
5. **Session store config:** create `config/initializers/session_store.rb` per §"Session store config". Commit.
6. **Routes split:** create `config/routes/play.rb` and `config/routes/admin.rb`. Replace `config/routes.rb` with the new top-level draw. Commit.
7. **Controller namespaces:** create `Play::ApplicationController`, `Play::HomeController`, `Admin::ApplicationController`, `Admin::DashboardController`. Delete `PagesController`. Commit.
8. **Components migration:** move `Pages::HomeComponent` → `Play::HomeComponent`. Add `Admin::DashboardComponent`. Update Lookbook previews. Commit.
9. **Views:** add `play/home/show.html.erb` and `admin/dashboard/show.html.erb`. Delete the old pages views directory if present. Commit.
10. **Env config:** add `default_url_options` and ActionMailer config to production, development, test environments. Commit.
11. **ApplicationController overrides:** add `after_sign_in_path_for` and `after_sign_out_path_for`. Commit.
12. **Rake task:** create `lib/tasks/users.rake`. Commit.
13. **Specs:** add the spec files listed in §"File inventory" → "Specs". Local `bundle exec rspec` runs clean. Commit.
14. **Capybara host config:** add `spec/support/capybara.rb` with default host. Commit (may be combined with step 13).
15. **README updates:** authentication section, local URL change, signup-disabled note. Commit.
16. **CI verification:** push to a feature branch, watch CI pass, then merge.
17. **Heroku deploy:** `git push heroku main` (or via the merge if Heroku is configured to auto-deploy `main`). Confirm `https://admin.gygaxagain.com` 302s to sign-in form at `https://gygaxagain.com/users/sign_in`.
18. **First real user:** SSH into Heroku and `heroku run rake users:create EMAIL=... PASSWORD=... -a gygaxagain`. Verify sign-in works in a browser; verify cross-subdomain session by signing in on apex then navigating to admin.

## Out of scope for Phase 2

Deferred to later phases (or until further notice):

- **Devise view customization / Tailwind styling.** Default Devise views are used. Polish in a later phase.
- **Working password reset email.** Production SMTP env vars are blank; reset silently fails. Acceptable for invite-only alpha.
- **Confirmable** (email confirmation flow). Not enabled, since signup is disabled.
- **Pundit / action_policy.** No campaigns yet, no resources to scope.
- **`last_played_campaign_id` on User.** Phase 3 adds the Campaign model + this column + the real after-sign-in redirect logic.
- **Real after-sign-in redirect.** Phase 2 stubs the redirect to admin dashboard. Phase 3 implements the three-case logic (last-played / has-campaigns / no-campaigns).
- **Admin layout separation.** Both subdomains use the existing `application.html.erb` layout in Phase 2. Phase 6 (play UI shell) introduces a real `play.html.erb` / `admin.html.erb` split if and when the layouts need to diverge.
- **Custom Devise error pages / lockable email notifications.** Defaults.
- **Multi-user sharing.** Permanent out-of-scope per Phase 0.

## Self-review notes

- This spec resolves every open question I could think of at brainstorm time. If any decision needs revisiting during implementation, the implementation plan should call it out rather than silently drift.
- The spec is intentionally repetitive of Phase 0 in some places (e.g. Devise module list) so a reader landing here directly understands the full picture without bouncing to Phase 0. Where Phase 0 already has implementation-level detail, this spec refines rather than restates.
- Acceptance criteria from the GitHub issue are all covered by the test plan in §"Specs". Reverse-mapping:
  - "Sign-in at apex works" → `spec/system/sign_in_spec.rb` + `spec/requests/devise_routes_spec.rb`.
  - "Sign-up returns 404" → `spec/requests/devise_routes_spec.rb`.
  - "Cross-subdomain session" → `spec/requests/cross_subdomain_session_spec.rb`.
  - "Admin requires auth, shows empty dashboard" → `spec/requests/admin/dashboard_spec.rb`.
  - "Rake task works" → `spec/lib/tasks/users_spec.rb`.
  - "All tests green; CI green" → covered by the existing CI workflow continuing to run RSpec + Brakeman + RuboCop + erb_lint.
- The www-redirect is not in the issue acceptance criteria but is included as a small belt-and-suspenders addition. It carries one spec; if it's contentious it can be pulled cleanly.
- The Capybara cross-subdomain story for system specs is theoretical in Phase 2 because only the sign-in journey is tested as a system spec, and that happens entirely on apex. The infrastructure is in place for Phase 3+ when admin-side system specs become relevant.
