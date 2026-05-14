# v2 Phase 4 — LLM provider abstraction + `llm_calls` + Anthropic adapter

Date: 2026-05-14
Status: Design spec. Drives the writing-plans pass for Phase 4.
Issue: [#5](https://github.com/barriault/gygaxagain/issues/5)
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md)
Prior phase: [`2026-05-13-v2-phase-3-campaign-crud-and-redirect-design.md`](2026-05-13-v2-phase-3-campaign-crud-and-redirect-design.md)

## Scope

Build the LLM client layer end-to-end against Anthropic. Introduces the `Llm::` namespace under `app/lib/`: a thin per-provider adapter (`Llm::Providers::Anthropic`), a purpose-keyed registry (`Llm::Provider.for(:purpose)`), a value-object result (`Llm::Result`), a pricing module (`Llm::Pricing`), an orchestrator that runs the call and persists the row (`Llm::Call`), and a typed error hierarchy. Adds the `llm_calls` table (schema verbatim from Phase 0) and an `LlmCall` ActiveRecord model. Surfaces a single admin diagnostics tool at `admin.gygaxagain.com/diagnostics/llm` that lets a signed-in user submit a prompt + system prompt + model, see the response, and inspect the persisted `llm_calls` row.

Streaming is deferred to Phase 8. `cache_control` first-class adapter parameters are deferred to Phase 8. The Gemini adapter is deferred to Phase 14; `:intake_long_context` returns Anthropic Sonnet 4.6 as a placeholder.

## Dependencies

Phase 3 ([#4](https://github.com/barriault/gygaxagain/issues/4)) complete: `User`, `Campaign`, admin subdomain scope, default-deny auth on `ApplicationController`. Phase 4 reuses the admin scope and the auth model directly; no new auth or tenancy primitives.

## Acceptance criteria

Verbatim from the GitHub issue:

- `Llm::Provider.for(:narration)` returns an Anthropic adapter.
- An admin tool at `admin.gygaxagain.com/diagnostics/llm` lets the user submit a prompt, see the response, see the `llm_calls` row written.
- `Llm::Pricing` returns correct rates for at least one Anthropic model (Sonnet) across input / output / cache_creation / cache_read.
- `llm_calls.prompt_payload` and `llm_calls.response_payload` capture full JSON.
- Tests stub the HTTP layer; no real API calls in CI.
- The `:intake_long_context` purpose is wired but returns Anthropic as a placeholder (Gemini adapter is a later phase).

## Architectural commitments inherited from Phase 0

Phase 0 already locks the LLM-shape decisions. This spec applies them; it does not re-litigate them.

- **`Llm::Provider`** is the abstraction; concrete adapters are thin and owned in our codebase. No `langchainrb` / `ruby_llm`.
- **Per-provider SDKs are allowed.** Phase 0's "no heavyweight abstraction" targeted multi-provider wrappers; the official `anthropic` Ruby SDK is a single-provider helper that fits the "thin per-provider adapter" bar. Decision: use it. (Detail in §"Open decisions resolved in this spec".)
- **Streaming is first-class for narration**, but Phase 4 is a synchronous tool. Streaming wiring lands in Phase 8.
- **Prompt caching is exposed per-provider.** Phase 4 supports it transparently (the adapter passes through `cache_control` if the caller injects it into `messages` / `system` content blocks) and tracks cache token columns when the response includes them. No first-class adapter parameter yet.
- **API keys via ENV.** `ANTHROPIC_API_KEY`. Not committed; loaded via `dotenv-rails` in dev/test, Heroku config in production.
- **Every API call writes a row to `llm_calls`.** Cost computed at write-time via `Llm::Pricing` and stored as integer cents.

## Open decisions resolved in this spec

### HTTP layer: official `anthropic` Ruby SDK

**Decision:** add `gem "anthropic"` (current minor: ~> 1.41). The adapter wraps `Anthropic::Client`, translates the SDK response to `Llm::Result`, and maps SDK exception classes to our `Llm::Error` hierarchy.

The SDK is published by Anthropic, single-provider, and well-aligned with the API's evolution. Rolling our own Faraday wrapper would re-implement headers, error classes, retry semantics, and request-shape tracking against an API that's still moving (cache TTLs, beta headers, etc.). The "thin adapter" commitment is preserved — the adapter file is small (one method, one error mapper) and the SDK lives behind it.

The SDK requires Ruby 3.2+. Project is on Ruby 4.0.2; compatible.

### Purpose-to-provider/model mapping: Ruby registry

**Decision:** a `PURPOSES` constant hash inside `Llm::Provider`, version-controlled, no YAML / no DB.

```ruby
module Llm
  module Provider
    PURPOSES = {
      diagnostics:         { provider: :anthropic, model: "claude-sonnet-4-6" },
      narration:           { provider: :anthropic, model: "claude-sonnet-4-6" },
      intake_long_context: { provider: :anthropic, model: "claude-sonnet-4-6" }, # placeholder; Gemini in Phase 14
    }.freeze
  end
end
```

Adding a purpose or changing a model is a code change + PR. No env-specific overrides; the diagnostics tool can override `model` per-call but `purpose → provider` is fixed in code.

### Default narration model: Sonnet 4.6 (`claude-sonnet-4-6`)

**Decision:** `:narration` defaults to Sonnet 4.6 ($3/MTok input, $15/MTok output). Five times cheaper than Opus per input token, fast, plenty capable for narration. Cost-tracking signal over alpha play tells us whether to upgrade later. The purpose registry is a one-line change to swap.

### Diagnostics tool model dropdown: Sonnet 4.6, Opus 4.7, Haiku 4.5

**Decision:** the diagnostics tool's model dropdown is populated from `Llm::Pricing::RATES.keys`. All three current Anthropic models are seeded with rates, even though only Sonnet is the actual narration default. Cost: a few extra entries in a constant. Benefit: diagnostics can A/B model behavior without a code change.

### `llm_calls` row write semantics on errors

**Decision:** always write a row when the adapter is invoked, regardless of HTTP-call outcome. Configuration errors (missing `ANTHROPIC_API_KEY`) raise before the adapter is invoked and do **not** persist a row.

- Successful call: row has tokens, cost, latency, request_id, full `prompt_payload` + `response_payload`.
- HTTP/transport error (5xx, 429, network timeout, malformed response): row has tokens=0, cost=0, `latency_ms` set (we got far enough to time it), `provider_request_id` nil unless the SDK exposes one on the error, `prompt_payload` set, `response_payload = { "error" => { "class" => "...", "message" => "..." } }`.
- Configuration error (`Llm::ConfigError`): no row. Controller catches, renders flash, no observable side effect on the table.

The distinction: the `llm_calls` table is for things that *attempted* to leave our process. Misconfigured calls never attempt; they're a deploy-side problem.

### Test stubbing: WebMock against `api.anthropic.com`

**Decision:** add `gem "webmock"` to the test group. `rails_helper` enables `WebMock.disable_net_connect!(allow_localhost: true)` so any unstubbed real call fails the test. Adapter specs and `Llm::Call` specs stub `POST https://api.anthropic.com/v1/messages` with realistic response bodies including the `usage` object (input/output/cache_creation/cache_read tokens) and the `id` field used as `provider_request_id`.

This exercises the full adapter — request body shape, header construction (auth + version), response parsing, error mapping — without a network round trip. Aligns literally with the acceptance criterion "tests stub the HTTP layer".

Higher-layer specs (controllers, components) stub at the `Llm::Call.execute` boundary using `instance_double(LlmCall, ...)` or by inserting a real `LlmCall` row directly.

### Cache-control: pass-through only in Phase 4

**Decision:** the Phase 4 adapter accepts only `model`, `system`, `messages`, `max_tokens`. If a caller embeds `cache_control: { type: "ephemeral" }` on a content block inside `system` or `messages`, the SDK forwards it transparently and the adapter populates `cache_creation_tokens` / `cache_read_tokens` from the response. No first-class `cache_breakpoints:` parameter yet.

The `Llm::Pricing` module supports the `:ephemeral_5m` cache TTL (the default; Anthropic's most common case) and `:ephemeral_1h` via an optional `cache_ttl:` argument. The schema's single `cache_creation_tokens` column maps to whichever TTL was used; the column does not distinguish 5m from 1h. Phase 4 has no real cache callers, so this is forward-looking only.

The `:cache_breakpoints` first-class parameter is added in Phase 8 when `Narrator::PromptBuilder` becomes the first real cache consumer.

### Diagnostics tool surface

**Decision:** one composite component, two routes, one controller.

- `GET /diagnostics/llm` (`admin_diagnostics_llm_path`): renders the form. If `?call_id=N` is present and that call belongs to `current_user`, also renders the result panel above the form.
- `POST /diagnostics/llm` (same path): runs the call via `Llm::Call.execute`, redirects to `GET /diagnostics/llm?call_id=N`.

Form fields:
- `prompt` (textarea, required) — sent as a single-message user turn.
- `system_prompt` (textarea, optional) — sent as the `system` parameter when present.
- `model` (select) — populated from `Llm::Pricing::RATES.keys`. Default = the registry's `:diagnostics` model (`claude-sonnet-4-6`).

Hard-coded for Phase 4: `purpose: :diagnostics`, `max_tokens: 1024`, `campaign: nil`, `scene: nil`. The `purpose` is fixed because the diagnostics tool isn't a real gameplay surface — it's an LLM-layer test bench. Diagnostics rows are distinguishable from real narration in the future cost dashboard.

The result panel shows: text response (or error message), model used, token counts (input / output / cache_creation / cache_read), `total_cost_cents` formatted as USD, `latency_ms`, `provider_request_id`, and a collapsible JSON viewer for `prompt_payload` and `response_payload` (using a `<details>` element — no JS).

### `Llm::Call.execute` return value: the persisted `LlmCall` record

**Decision:** `Llm::Call.execute(...)` returns the persisted `LlmCall` instance. The model exposes `#text`, `#successful?`, and `#error_message` accessors derived from `response_payload`, so callers don't need to unpack JSON themselves.

A separate `Llm::Result` value object exists between the adapter and `Llm::Call` (the adapter returns `Llm::Result`, `Llm::Call` translates it to `LlmCall` columns). Callers of `Llm::Call.execute` only see `LlmCall`.

### Service organization: `app/lib/llm/`

**Decision:** all `Llm::` code lives under `app/lib/llm/`. Rails 8 autoloads `app/lib`. The model `LlmCall` lives in `app/models/llm_call.rb` (it's an ActiveRecord; it belongs in `app/models`).

`app/lib` is preferred over `app/services` because the `Llm` namespace contains a registry, value objects, a pricing table, and adapters — not a flat list of service objects. "Library code, not per-request services" is the better mental model.

### Anthropic SDK client lifecycle: lazy class-level memo

**Decision:** `Llm::Providers::Anthropic` memoizes the `Anthropic::Client` instance at the class level (`def self.sdk_client; @sdk_client ||= ...; end`). The SDK's client is thread-safe and intended to be reused. One client per process.

Tests reset the memo via `Llm::Providers::Anthropic.reset_client!` in a `before(:each)` block (defined in `spec/support/llm.rb`) so WebMock stubs operate against a fresh client when needed.

### `provider_request_id` capture

**Decision:** capture `Anthropic::Models::Message#id` (the message ID returned in the response body) as `provider_request_id`. This is what Anthropic's support team asks for. The SDK exposes it on the response object directly. On error, `provider_request_id` is nil unless the SDK error object exposes it (which it sometimes does for 4xx responses).

### Strong params on the diagnostics form

**Decision:** `params.require(:llm_call).permit(:prompt, :system_prompt, :model)`. No tenant fields, no purpose field — both are inferred / hard-coded.

The form uses a non-AR-backed model object (`Llm::DiagnosticsForm`, a `ActiveModel::Model` PORO with the three attributes + validations) so the form helper has something to render. This avoids attaching form state to the `LlmCall` AR model, which represents the *outcome* of a submission, not its input shape.

### Routes namespace shape

**Decision:** add a nested `namespace :diagnostics` block inside the existing admin scope. Helper names follow the Rails convention.

```ruby
constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root to: redirect("/campaigns")

    resources :campaigns, except: [ :show ]

    namespace :diagnostics do
      resource :llm, only: [ :show, :create ], controller: "llm"
    end
  end
end
```

Generated helpers: `admin_diagnostics_llm_path` (GET form / POST submit) and `admin_diagnostics_llm_url`. The `resource` (singular) collapses GET + POST onto the same path; the `controller: "llm"` override avoids the auto-pluralized `llms` controller name.

### Admin navigation: add a Diagnostics link

**Decision:** the admin layout (currently a flash banner over the controller action; no nav chrome) does not exist as a real layout yet. Phase 4 adds a minimal admin top-nav with two links: "Campaigns" (the existing index) and "Diagnostics → LLM". This lives in `Admin::NavComponent`, rendered by `Admin::LayoutComponent` (which becomes the layout for all admin pages).

If introducing the admin layout feels like scope creep, the simpler fallback is: a single inline link from `admin/campaigns/index` saying "→ Diagnostics" and no link the other way. Phase 4 takes the layout approach because it's small (one component, ~30 lines of ERB), it's cleaner long-term, and the admin surface will grow more nav targets in Phase 5+ anyway.

### `LlmCall` access control

**Decision:** the diagnostics show action loads the call via `current_user.llm_calls.find_by(id: params[:call_id])`. Cross-user access returns nil (no result panel rendered, no flash); the form still appears. Cross-user access via direct manipulation never raises and never reveals existence — same 404-via-`find` posture as Phase 3, except the show action degrades gracefully because the form is the primary surface.

A request spec asserts that `?call_id=` belonging to another user returns a 200 with no result panel (via the absence of a known DOM marker).

## File inventory

Every file added or modified in Phase 4, grouped by area. Canonical list for the implementation plan.

### Gemfile

- Add `gem "anthropic"` to the production group.
- Add `gem "webmock"` to the test group.

Run `bundle install`. Commit `Gemfile` + `Gemfile.lock`.

### Migration

`db/migrate/<ts>_create_llm_calls.rb`:

```ruby
class CreateLlmCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_calls do |t|
      t.references :user,     null: false, foreign_key: { on_delete: :cascade }
      t.references :campaign, null: true,  foreign_key: { on_delete: :cascade }
      t.references :scene,    null: true,  index: true   # FK added in Phase 5 when scenes table exists
      t.string  :purpose,                  null: false
      t.string  :provider,                 null: false
      t.string  :model,                    null: false
      t.integer :input_tokens,             null: false, default: 0
      t.integer :output_tokens,            null: false, default: 0
      t.integer :cache_creation_tokens,    null: false, default: 0
      t.integer :cache_read_tokens,        null: false, default: 0
      t.integer :total_cost_cents,         null: false, default: 0
      t.integer :latency_ms
      t.string  :provider_request_id
      t.jsonb   :prompt_payload,           null: false, default: {}
      t.jsonb   :response_payload,         null: false, default: {}
      t.timestamps
    end

    add_index :llm_calls, [ :purpose, :created_at ]
    add_index :llm_calls, [ :provider, :model ]
  end
end
```

Notes:
- `t.references :scene` writes the column + index but does **not** add a FK. The `scenes` table doesn't exist until Phase 5; Phase 5's scene migration will add the FK with `add_foreign_key :llm_calls, :scenes, on_delete: :nullify`. (Or Phase 5 chooses cascade — that's a Phase 5 decision.) The Phase 4 column is nullable and unconstrained; existing rows stay null because no Phase 4 caller passes a scene.
- Cascade on `user_id` matches the Phase 3 cascade: deleting a user removes their llm_calls rows.
- Cascade on `campaign_id` is consistent: deleting a campaign removes its llm_calls rows. Diagnostics rows have null `campaign_id` so they survive campaign deletes.
- Indexes target the two expected dashboard queries: rollups by purpose-over-time, and rollups by provider+model.
- `prompt_payload` and `response_payload` default to `{}` (not null) so the columns can be queried with `WHERE response_payload ? 'error'` etc. without null-check noise.

### Models

`app/models/llm_call.rb`:

```ruby
class LlmCall < ApplicationRecord
  belongs_to :user
  belongs_to :campaign, optional: true
  # belongs_to :scene, optional: true  # uncommented in Phase 5 when scene model exists

  validates :purpose,  presence: true
  validates :provider, presence: true
  validates :model,    presence: true

  def text
    return nil unless successful?
    response_payload.dig("content", 0, "text")
  end

  def successful?
    !response_payload.key?("error")
  end

  def error_message
    return nil if successful?
    response_payload.dig("error", "message")
  end

  def total_cost_dollars
    total_cost_cents / 100.0
  end
end
```

`app/models/user.rb` updated:

```ruby
has_many :llm_calls, dependent: :destroy
```

`app/models/campaign.rb` updated:

```ruby
has_many :llm_calls, dependent: :destroy
```

`annotaterb` runs against all three models post-migration.

### `Llm` namespace

All files under `app/lib/llm/`.

`app/lib/llm/error.rb`:

```ruby
module Llm
  class Error            < StandardError; end
  class ConfigError      < Error; end          # missing API key, unknown purpose, etc.
  class ProviderError    < Error               # HTTP / SDK errors
    attr_reader :provider_class, :provider_message
    def initialize(provider_class:, provider_message:)
      @provider_class    = provider_class
      @provider_message  = provider_message
      super("[#{provider_class}] #{provider_message}")
    end
  end
end
```

`app/lib/llm/result.rb`:

```ruby
module Llm
  Result = Data.define(
    :text,
    :input_tokens,
    :output_tokens,
    :cache_creation_tokens,
    :cache_read_tokens,
    :provider_request_id,
    :prompt_payload,
    :response_payload,
    :latency_ms,
    :error  # nil on success; Llm::ProviderError on failure
  ) do
    def successful? = error.nil?
  end
end
```

`app/lib/llm/pricing.rb`:

```ruby
module Llm
  module Pricing
    # USD per million tokens. Verified against
    # https://platform.claude.com/docs/en/about-claude/pricing on 2026-05-14.
    RATES = {
      "claude-sonnet-4-6" => {
        input:                3.00,
        output:               15.00,
        cache_write_5m:       3.75,
        cache_write_1h:       6.00,
        cache_read:           0.30
      },
      "claude-opus-4-7" => {
        input:                5.00,
        output:               25.00,
        cache_write_5m:       6.25,
        cache_write_1h:       10.00,
        cache_read:           0.50
      },
      "claude-haiku-4-5" => {
        input:                1.00,
        output:               5.00,
        cache_write_5m:       1.25,
        cache_write_1h:       2.00,
        cache_read:           0.10
      }
    }.freeze

    PER_MTOK = BigDecimal("1_000_000")

    # usage: { input:, output:, cache_creation:, cache_read: }
    # cache_ttl: :ephemeral_5m (default) or :ephemeral_1h — controls which
    # cache-write rate applies to cache_creation tokens.
    def self.cost_cents(usage:, model:, cache_ttl: :ephemeral_5m)
      rates = RATES.fetch(model) { raise Llm::ConfigError, "Unknown model: #{model}" }
      cache_write_rate = case cache_ttl
                         when :ephemeral_5m then rates[:cache_write_5m]
                         when :ephemeral_1h then rates[:cache_write_1h]
                         else raise Llm::ConfigError, "Unknown cache_ttl: #{cache_ttl}"
                         end

      total_usd = BigDecimal("0")
      total_usd += BigDecimal(usage[:input].to_s)          * BigDecimal(rates[:input].to_s)         / PER_MTOK
      total_usd += BigDecimal(usage[:output].to_s)         * BigDecimal(rates[:output].to_s)        / PER_MTOK
      total_usd += BigDecimal(usage[:cache_creation].to_s) * BigDecimal(cache_write_rate.to_s)      / PER_MTOK
      total_usd += BigDecimal(usage[:cache_read].to_s)     * BigDecimal(rates[:cache_read].to_s)    / PER_MTOK

      (total_usd * BigDecimal("100")).round.to_i
    end

    def self.known_models
      RATES.keys
    end
  end
end
```

`app/lib/llm/provider.rb`:

```ruby
module Llm
  module Provider
    PURPOSES = {
      diagnostics:         { provider: :anthropic, model: "claude-sonnet-4-6" },
      narration:           { provider: :anthropic, model: "claude-sonnet-4-6" },
      intake_long_context: { provider: :anthropic, model: "claude-sonnet-4-6" }
    }.freeze

    def self.for(purpose)
      config = PURPOSES.fetch(purpose) do
        raise Llm::ConfigError, "Unknown purpose: #{purpose.inspect}"
      end

      adapter_class_for(config[:provider]).new(model: config[:model])
    end

    def self.adapter_class_for(provider)
      case provider
      when :anthropic then Llm::Providers::Anthropic
      else raise Llm::ConfigError, "Unknown provider: #{provider.inspect}"
      end
    end
  end
end
```

`app/lib/llm/providers/anthropic.rb`:

```ruby
module Llm
  module Providers
    class Anthropic
      attr_reader :model

      def initialize(model:)
        @model = model
      end

      # Returns Llm::Result. Never raises on HTTP/transport errors —
      # those are captured into result.error. Raises Llm::ConfigError
      # if the API key is missing.
      def call(system: nil, messages:, max_tokens: 1024)
        api_key = ENV["ANTHROPIC_API_KEY"]
        raise Llm::ConfigError, "ANTHROPIC_API_KEY is not set" if api_key.blank?

        request_body = {
          model: model,
          max_tokens: max_tokens,
          messages: messages
        }
        request_body[:system] = system if system.present?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          response = self.class.sdk_client.messages.create(**request_body)
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

          Llm::Result.new(
            text: response.content.first.text,
            input_tokens:           response.usage.input_tokens.to_i,
            output_tokens:          response.usage.output_tokens.to_i,
            cache_creation_tokens:  cache_creation_from(response.usage),
            cache_read_tokens:      cache_read_from(response.usage),
            provider_request_id:    response.id,
            prompt_payload:         request_body.deep_stringify_keys,
            response_payload:       response.to_hash.deep_stringify_keys,
            latency_ms:             latency_ms,
            error:                  nil
          )
        rescue ::Anthropic::Errors::APIError => e
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          provider_error = Llm::ProviderError.new(
            provider_class:   e.class.name,
            provider_message: e.message
          )
          Llm::Result.new(
            text: nil,
            input_tokens: 0, output_tokens: 0,
            cache_creation_tokens: 0, cache_read_tokens: 0,
            provider_request_id: nil,
            prompt_payload: request_body.deep_stringify_keys,
            response_payload: { "error" => { "class" => e.class.name, "message" => e.message } },
            latency_ms: latency_ms,
            error: provider_error
          )
        end
      end

      def self.sdk_client
        @sdk_client ||= ::Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
      end

      def self.reset_client!
        @sdk_client = nil
      end

      private

      def cache_creation_from(usage)
        # Anthropic SDK exposes either a flat int or a struct with
        # ephemeral_5m_input_tokens + ephemeral_1h_input_tokens. Support both.
        return 0 unless usage.respond_to?(:cache_creation_input_tokens)
        usage.cache_creation_input_tokens.to_i
      end

      def cache_read_from(usage)
        return 0 unless usage.respond_to?(:cache_read_input_tokens)
        usage.cache_read_input_tokens.to_i
      end
    end
  end
end
```

Notes:
- `Anthropic::Errors::APIError` is the SDK's base error class in current major versions (1.x). Subclasses (`RateLimitError`, `AuthenticationError`, etc.) all descend from it. Catching the base means one rescue clause covers transport, rate-limit, auth, and 5xx errors uniformly. The error class name is preserved in `response_payload["error"]["class"]` so callers / dashboards can distinguish. **Implementation note:** verify the exact constant path against the installed SDK version (`Anthropic::Errors::APIError` vs the older `Anthropic::APIError`); use whichever the gem's CHANGELOG / source confirms for the locked version in `Gemfile.lock`.
- `response.to_hash` produces a plain hash from the SDK response object. The SDK supports this conversion. `deep_stringify_keys` ensures consistent JSON shape regardless of whether the SDK returns symbol or string keys.

`app/lib/llm/call.rb`:

```ruby
module Llm
  module Call
    # Returns the persisted LlmCall record. Raises Llm::ConfigError on
    # missing API key or unknown purpose. Never raises on HTTP errors —
    # those are persisted into the row's response_payload.
    def self.execute(purpose:, system: nil, messages:, max_tokens: 1024,
                     user:, campaign: nil, scene: nil, model: nil)
      adapter = Llm::Provider.for(purpose)
      adapter = override_model(adapter, model) if model

      result = adapter.call(system: system, messages: messages, max_tokens: max_tokens)

      cost_cents = if result.successful?
                     Llm::Pricing.cost_cents(
                       usage: {
                         input:          result.input_tokens,
                         output:         result.output_tokens,
                         cache_creation: result.cache_creation_tokens,
                         cache_read:     result.cache_read_tokens
                       },
                       model: adapter.model
                     )
                   else
                     0
                   end

      LlmCall.create!(
        user:                  user,
        campaign:              campaign,
        scene_id:              scene&.id,
        purpose:               purpose.to_s,
        provider:              provider_name_for(purpose),
        model:                 adapter.model,
        input_tokens:          result.input_tokens,
        output_tokens:         result.output_tokens,
        cache_creation_tokens: result.cache_creation_tokens,
        cache_read_tokens:     result.cache_read_tokens,
        total_cost_cents:      cost_cents,
        latency_ms:            result.latency_ms,
        provider_request_id:   result.provider_request_id,
        prompt_payload:        result.prompt_payload,
        response_payload:      result.response_payload
      )
    end

    def self.override_model(adapter, model)
      raise Llm::ConfigError, "Unknown model: #{model}" unless Llm::Pricing.known_models.include?(model)
      adapter.class.new(model: model)
    end

    def self.provider_name_for(purpose)
      Llm::Provider::PURPOSES.fetch(purpose)[:provider].to_s
    end
  end
end
```

Notes:
- The `model:` override on `Llm::Call.execute` is what the diagnostics dropdown uses. Real callers (Phase 8 narrator) pass only `purpose:` and let the registry choose.
- `scene_id:` is set directly (rather than via `scene:`) because the `LlmCall` model doesn't declare `belongs_to :scene` until Phase 5.
- `provider_name_for` derives the provider string from the purpose registry, not from the adapter class — keeps the column data tied to the purpose declaration, not to dispatch.

`app/lib/llm/diagnostics_form.rb`:

```ruby
module Llm
  class DiagnosticsForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :prompt,        :string
    attribute :system_prompt, :string
    attribute :model,         :string

    validates :prompt, presence: true
    validates :model,  presence: true,
                       inclusion: { in: ->(_form) { Llm::Pricing.known_models } }
  end
end
```

This PORO is the form-backing object for the diagnostics page. It's not persisted; its job is to satisfy `form_with`'s contract and to validate input before we hand it to `Llm::Call`.

### Routes

`config/routes/admin.rb` updated:

```ruby
constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root to: redirect("/campaigns")

    resources :campaigns, except: [ :show ]

    namespace :diagnostics do
      resource :llm, only: [ :show, :create ], controller: "llm"
    end
  end
end
```

Generated helpers: `admin_diagnostics_llm_path` (GET form / POST submit), `admin_diagnostics_llm_url`. The singular `resource` collapses GET + POST onto the same path; the `controller: "llm"` override avoids the auto-pluralized `llms` controller name.

### Controller

`app/controllers/admin/diagnostics/llm_controller.rb`:

```ruby
module Admin
  module Diagnostics
    class LlmController < ::ApplicationController
      def show
        form = Llm::DiagnosticsForm.new(model: default_model)
        last_call = load_last_call(params[:call_id])
        render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: last_call)
      end

      def create
        form = Llm::DiagnosticsForm.new(form_params)

        unless form.valid?
          render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: nil),
                 status: :unprocessable_entity
          return
        end

        begin
          call = Llm::Call.execute(
            purpose:  :diagnostics,
            system:   form.system_prompt.presence,
            messages: [ { role: "user", content: form.prompt } ],
            model:    form.model,
            user:     current_user
          )
          redirect_to admin_diagnostics_llm_path(call_id: call.id)
        rescue Llm::ConfigError => e
          flash.now[:alert] = "LLM configuration error: #{e.message}"
          render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: nil),
                 status: :service_unavailable
        end
      end

      private

      def form_params
        params.require(:llm_diagnostics_form).permit(:prompt, :system_prompt, :model)
      end

      def default_model
        Llm::Provider::PURPOSES.fetch(:diagnostics)[:model]
      end

      def load_last_call(id)
        return nil unless id.present?
        current_user.llm_calls.find_by(id: id)
      end
    end
  end
end
```

### Components

Two ViewComponents added under `app/components/admin/diagnostics/llm/`. The composite show component is the only renderable; the result panel is a sub-component to keep the show component readable.

`app/components/admin/diagnostics/llm/show_component.rb` + `.html.erb`:
- Initializer: `form:`, `last_call:` (may be nil).
- Renders (in order): page heading "LLM diagnostics", optional `Admin::Diagnostics::Llm::ResultPanelComponent.new(call: last_call)` when `last_call` is present, then a `form_with(model: form, url: admin_diagnostics_llm_path)` containing the three fields + submit button.
- Renders form errors inline above the form when `form.errors.any?`.

`app/components/admin/diagnostics/llm/result_panel_component.rb` + `.html.erb`:
- Initializer: `call:` (an `LlmCall`).
- Renders: success/error banner; model + purpose; tokens table (input / output / cache_creation / cache_read); cost in USD (formatted from `total_cost_cents` via `helpers.number_to_currency(call.total_cost_dollars)`); latency_ms; provider_request_id; collapsible `<details>` blocks for `prompt_payload` and `response_payload` JSON (pretty-printed via `JSON.pretty_generate`).
- Root element carries `data-llm-call-id="<call.id>"` so request specs can assert presence/absence of the panel without coupling to text content.

Both components use the existing Tailwind dark-theme conventions (`bg-slate-900 text-slate-100`).

`app/components/admin/nav_component.rb` + `.html.erb` (new): a top nav with two links — "Campaigns" → `admin_campaigns_path` and "Diagnostics → LLM" → `admin_diagnostics_llm_path`. Highlights the current section based on `request.path`.

`app/components/admin/layout_component.rb` + `.html.erb` (new): wraps content with the nav. Used as the layout for all admin pages.

`app/views/layouts/admin.html.erb` (new): trivial layout that renders `Admin::LayoutComponent.new` around `yield`. The two existing admin controllers (`Admin::CampaignsController` and `Admin::Diagnostics::LlmController`) opt into this layout via `layout "admin"` either at the controller level or via an `Admin::ApplicationController` base introduced here.

**Decision on `Admin::ApplicationController`:** Phase 4 introduces it. Phase 3 noted it would land "when it earns its keep" — the layout selection is exactly that trigger. The base class sets `layout "admin"`. `Admin::CampaignsController` migrates to inherit from `Admin::ApplicationController` instead of `::ApplicationController`. The Phase 0 commitment to namespaced bases finally lands here.

### Specs

Add `spec/support/llm.rb`:

```ruby
RSpec.configure do |config|
  config.before(:each) do
    Llm::Providers::Anthropic.reset_client!
  end
end
```

Add to `spec/rails_helper.rb`:

```ruby
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)
```

Specs:

- `spec/lib/llm/pricing_spec.rb` — known-model rates (Sonnet 4.6, Opus 4.7, Haiku 4.5) compute correctly across all four token categories; BigDecimal rounding behaves (1 input token at $3/MTok → 0 cents; 1M input tokens → 300 cents); unknown model raises `Llm::ConfigError`; `cache_ttl: :ephemeral_1h` uses the 1h rate; unknown `cache_ttl` raises.
- `spec/lib/llm/provider_spec.rb` — `for(:narration)` returns an `Llm::Providers::Anthropic` with the registered model; `for(:diagnostics)` and `for(:intake_long_context)` likewise; `for(:unknown)` raises `Llm::ConfigError`.
- `spec/lib/llm/providers/anthropic_spec.rb` — WebMock-driven. Success path: stub returns realistic Messages API JSON (with `id`, `content[0].text`, `usage` block including `cache_creation_input_tokens` + `cache_read_input_tokens`); adapter returns `Llm::Result` with all fields populated; `latency_ms` is non-nil. Error paths: 5xx, 429, network error → adapter returns a `Llm::Result` with `error` set, tokens 0, `response_payload` containing the error class + message. Config path: missing `ANTHROPIC_API_KEY` → raises `Llm::ConfigError`.
- `spec/lib/llm/call_spec.rb` — success: stubs the Anthropic POST, asserts `LlmCall` row written with full fields, cost computed correctly, returns the record. Error: stubs a 500, asserts row written with tokens=0, cost=0, response_payload contains error info. Config: missing key → raises, no row written. Model override: passing `model: "claude-haiku-4-5"` writes a row with that model and uses Haiku rates for cost.
- `spec/lib/llm/diagnostics_form_spec.rb` — validation: prompt presence; model inclusion in `Pricing.known_models`; system_prompt optional.
- `spec/models/llm_call_spec.rb` — validations on purpose/provider/model presence; `belongs_to :user` (non-optional), `belongs_to :campaign optional: true`; `#text` extracts content from `response_payload`; `#successful?` is false when `response_payload["error"]` exists; `#error_message` extracts the message; cascade delete on user removes llm_calls; cascade on campaign removes llm_calls.
- `spec/models/user_spec.rb` updated — `has_many :llm_calls dependent: :destroy`.
- `spec/models/campaign_spec.rb` updated — `has_many :llm_calls dependent: :destroy`.
- `spec/requests/admin/diagnostics/llm_spec.rb` — auth matrix: unauth → 302. Auth + GET without `call_id` → 200, form rendered, no result panel. Auth + GET with own `call_id` → 200, form + result panel. Auth + GET with another user's `call_id` → 200, form only (no result panel — assert by absence of a known DOM marker like a `data-llm-call-id` attribute). Auth + POST valid → stubbed call succeeds, row written, redirect to `?call_id=N`. Auth + POST invalid (empty prompt) → 422, form with errors. Auth + POST when stubbed call returns 500 → row written with error, redirect to `?call_id=N`. Auth + POST when `ANTHROPIC_API_KEY` is unset → 503, no row written, alert flash.
- `spec/components/admin/diagnostics/llm/show_component_spec.rb` — renders form alone; renders form + result panel when `last_call` is a successful call; renders form + error panel when `last_call` is an errored call.
- `spec/components/admin/diagnostics/llm/result_panel_component_spec.rb` — renders all fields for a successful call; renders error banner for an errored call; renders pretty JSON for the payload `<details>` blocks.
- `spec/components/admin/nav_component_spec.rb` — renders both nav links; highlights "Campaigns" when path matches; highlights "Diagnostics" when path matches.

Factory:

`spec/factories/llm_calls.rb`:

```ruby
FactoryBot.define do
  factory :llm_call do
    user
    purpose  { "diagnostics" }
    provider { "anthropic" }
    model    { "claude-sonnet-4-6" }
    input_tokens { 100 }
    output_tokens { 50 }
    total_cost_cents { 105 }
    latency_ms { 1234 }
    provider_request_id { "msg_#{SecureRandom.hex(8)}" }
    prompt_payload {
      { "model" => "claude-sonnet-4-6", "max_tokens" => 1024,
        "messages" => [ { "role" => "user", "content" => "Hello" } ] }
    }
    response_payload {
      { "id" => provider_request_id, "model" => "claude-sonnet-4-6",
        "content" => [ { "type" => "text", "text" => "Hi there!" } ],
        "usage" => { "input_tokens" => 100, "output_tokens" => 50 } }
    }

    trait :errored do
      input_tokens { 0 }
      output_tokens { 0 }
      total_cost_cents { 0 }
      provider_request_id { nil }
      response_payload {
        { "error" => { "class" => "Anthropic::Errors::InternalServerError",
                       "message" => "Internal server error" } }
      }
    end
  end
end
```

### Lookbook previews

`spec/components/previews/admin/diagnostics/llm/show_component_preview.rb` — three scenarios: empty form, form + successful last_call, form + errored last_call.

`spec/components/previews/admin/diagnostics/llm/result_panel_component_preview.rb` — two scenarios: success, error.

`spec/components/previews/admin/nav_component_preview.rb` — three scenarios: campaigns active, diagnostics active, no path match.

### Config

`.env.example` updated to include `ANTHROPIC_API_KEY=sk-ant-...`. `.env` (gitignored) gains the real key in dev.

`config/initializers/llm.rb` — none needed in Phase 4. The SDK reads `ANTHROPIC_API_KEY` from ENV at client construction. The pricing module is data-only.

### README

Add a brief "LLM diagnostics" sub-section under a new "Operations" heading: documents the URL (`https://admin.gygaxagain.com/diagnostics/llm`), the required `ANTHROPIC_API_KEY` env var in dev (and the `dotenv-rails` `.env` file convention), and a one-liner about how the model dropdown is populated from `Llm::Pricing::RATES`.

## Implementation-level sequence

1. **Gemfile + bundle.** Add `anthropic` (default group) and `webmock` (test group). `bundle install`. Commit `Gemfile` + `Gemfile.lock`.
2. **WebMock infrastructure.** Update `spec/rails_helper.rb` with `WebMock.disable_net_connect!(allow_localhost: true)`. Add `spec/support/llm.rb` resetting the Anthropic SDK client memo before each spec. Run `bundle exec rspec` to confirm nothing regressed. Commit.
3. **Migration + LlmCall model.** Generate `CreateLlmCalls`, migrate. Add `app/models/llm_call.rb`. Update `User` and `Campaign` with `has_many :llm_calls, dependent: :destroy`. Run `annotaterb`. Commit migrations + schema.rb + models.
4. **Factory + model spec.** Add `spec/factories/llm_calls.rb`. Add `spec/models/llm_call_spec.rb`. Update `spec/models/user_spec.rb` + `spec/models/campaign_spec.rb`. `bundle exec rspec spec/models` clean. Commit.
5. **`Llm::Error` + `Llm::Result` + `Llm::Pricing`.** Add the three files under `app/lib/llm/`. Add `spec/lib/llm/pricing_spec.rb`. `bundle exec rspec spec/lib/llm/pricing_spec.rb` clean. Commit.
6. **`Llm::Provider`.** Add `app/lib/llm/provider.rb`. Add `spec/lib/llm/provider_spec.rb`. (The provider spec passes once `Llm::Providers::Anthropic` exists in the next step. Either commit step 6 + 7 together, or stub the adapter constant in the spec.) Recommend: combine 6 + 7 into a single commit.
7. **`Llm::Providers::Anthropic`.** Add `app/lib/llm/providers/anthropic.rb`. Add `spec/lib/llm/providers/anthropic_spec.rb` (WebMock-driven, success + error paths). `bundle exec rspec spec/lib/llm` clean. Commit.
8. **`Llm::Call`.** Add `app/lib/llm/call.rb`. Add `spec/lib/llm/call_spec.rb`. `bundle exec rspec spec/lib/llm/call_spec.rb` clean. Commit.
9. **`Llm::DiagnosticsForm` + spec.** Add the PORO and its spec. Commit.
10. **Admin layout introduction.** Add `app/views/layouts/admin.html.erb`, `Admin::LayoutComponent`, `Admin::NavComponent`. Introduce `Admin::ApplicationController` (sets `layout "admin"`); migrate `Admin::CampaignsController` to inherit from it. Verify Phase 3's existing admin component templates only render content fragments (no `<html>` / `<body>` chrome) so they nest cleanly inside the new layout — if any contain redundant chrome, strip it. Update Phase 3 admin request specs only if they break (they shouldn't — adding a layout wraps HTML but doesn't change response status / redirects / flash). Add `spec/components/admin/nav_component_spec.rb` + preview. Commit.
11. **Diagnostics route + controller + components.** Add the `namespace :diagnostics { resource :llm }` block to `config/routes/admin.rb`. Implement `Admin::Diagnostics::LlmController` (inheriting from `Admin::ApplicationController`). Implement `Admin::Diagnostics::Llm::ShowComponent` + `Admin::Diagnostics::Llm::ResultPanelComponent` with their previews. Commit.
12. **Diagnostics request + component specs.** Cover the auth matrix, GET without/with `call_id`, POST valid, POST invalid, POST → stubbed error, POST → config error. Component specs for show + result panel. `bundle exec rspec spec/requests/admin/diagnostics spec/components/admin/diagnostics` clean. Commit.
13. **`.env.example` + README.** Add `ANTHROPIC_API_KEY=sk-ant-...` to `.env.example`. Add the "LLM diagnostics" README section. Commit.
14. **Full RSpec + Brakeman + RuboCop + erb_lint.** Resolve any new offenses. Commit fixes as needed.
15. **Deploy.** Push to main / Heroku. Migration runs in the release phase. Set `ANTHROPIC_API_KEY` via `heroku config:set` *before* the deploy so the diagnostics tool works on first hit. Verify: sign in to admin, navigate to Diagnostics → LLM, submit a short prompt, see the response, see the row in `heroku run rails console` (`LlmCall.last`).

## Out of scope for Phase 4

Deferred to later phases (or until further notice):

- **Streaming responses.** Phase 8.
- **First-class `cache_breakpoints:` adapter parameter.** Phase 8 (the first real cache consumer).
- **Gemini adapter.** Phase 14 (intake long context).
- **Usage rollup dashboard at `admin/usage`.** Phase 0 references it but it's not in Phase 4's acceptance criteria. The data is being captured from day one; visualizing it is a separate phase.
- **Per-campaign cost widget on the admin campaigns index.** Same — data is captured, surfacing it is later.
- **Retry logic on 429 / 5xx.** Defer until Phase 8 streaming or first observed outage signal.
- **Rate limiting / spend caps.** Out of scope for invite-only alpha.
- **Asynchronous calls via Solid Queue.** Phase 4 calls are synchronous from the controller. Phase 8 narrator streaming will introduce async dispatch.
- **Real `Narrator::PromptBuilder` content.** Phase 8. The diagnostics tool is not building real narration prompts; it's a free-form prompt input.
- **Multi-turn message history in the diagnostics tool.** One user turn, one response. Phase 4 is not a chat surface.
- **Logging / observability beyond the `llm_calls` table.** No Sentry, no APM, no log shipping. The table itself is the audit trail.

## Self-review notes

- Acceptance criteria reverse-mapping:
  - "`Llm::Provider.for(:narration)` returns an Anthropic adapter" → `spec/lib/llm/provider_spec.rb`.
  - "Admin tool at `admin.gygaxagain.com/diagnostics/llm` lets the user submit a prompt, see the response, see the `llm_calls` row" → `spec/requests/admin/diagnostics/llm_spec.rb` + the show component spec.
  - "`Llm::Pricing` returns correct rates for at least one Anthropic model (Sonnet)" → `spec/lib/llm/pricing_spec.rb` covers Sonnet 4.6, Opus 4.7, Haiku 4.5 across all five rate categories.
  - "`llm_calls.prompt_payload` and `llm_calls.response_payload` capture full JSON" → adapter spec asserts both fields are populated; call spec asserts they survive the round trip into the row; the columns default to `{}` so they are always present.
  - "Tests stub the HTTP layer; no real API calls in CI" → `WebMock.disable_net_connect!` in `rails_helper`; adapter + call specs stub `api.anthropic.com`.
  - "`:intake_long_context` purpose is wired but returns Anthropic as a placeholder" → asserted in `spec/lib/llm/provider_spec.rb`; the registry comment marks it as a Phase 14 Gemini placeholder.
- The Phase 0 schema's `scene_id` is included in the Phase 4 migration as a nullable column with no FK. Phase 5's scene migration will add the FK. This avoids reordering migrations in Phase 5 and keeps the table schema-stable across phases.
- The `Admin::ApplicationController` introduction is a Phase 0 commitment finally landing. Phase 3 explicitly noted "introduce `Admin::ApplicationController` at that point and migrate the existing two controllers in the same change" when an admin-wide concern arrives. Layout selection is exactly that concern. The Phase 3 deviation closes here.
- The diagnostics tool's "model dropdown" populates from `Llm::Pricing::RATES.keys`. This means adding a new model in pricing automatically exposes it in the dropdown. Conversely, retiring a model from pricing removes it from the dropdown. This single source of truth is the correct dependency direction: pricing knows which models exist, the UI surfaces them.
- The `Llm::Result` `Data.define` shape has 10 fields. That's a lot for a positional Data class but it's the price of capturing all of `prompt_payload`, `response_payload`, the four token categories, latency, request_id, text, and error. Callers always use keyword construction; positional access is not supported by `Data.define` anyway.
- The Anthropic SDK client lifecycle (class-level memo + `reset_client!` for tests) avoids per-request instantiation overhead. The SDK's `Anthropic::Client` is documented as thread-safe.
- The `cache_creation_from` / `cache_read_from` helpers defensively handle the SDK exposing usage as either a flat-int or a struct — Anthropic's API has split `cache_creation` into `ephemeral_5m_input_tokens` + `ephemeral_1h_input_tokens` over time, and the SDK's surface for this may evolve. Phase 4 is not a real cache consumer, so this defensive code path won't be exercised much; Phase 8 will tighten it.
- The diagnostics tool's `purpose: :diagnostics` is hard-coded so all diagnostics rows are distinguishable from real narration in the future cost dashboard. A user spending a lot in diagnostics shouldn't pollute the narration cost rollup for their campaigns.
- One Phase 0 deviation: Phase 0 lists `purpose` examples as `'narration', 'oracle_compose', 'bookkeeper_audit', 'intake_extract', etc.` — Phase 4 adds `'diagnostics'` to that list. Diagnostics calls aren't part of gameplay but they are real API calls and need a purpose label. The deviation is additive, not contradictory.
