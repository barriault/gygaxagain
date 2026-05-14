# v2 Phase 4 — LLM provider + Anthropic adapter: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `Llm::` client layer (registry, Anthropic adapter, pricing, orchestrator), the `llm_calls` table + model, and the admin diagnostics tool at `admin.gygaxagain.com/diagnostics/llm` end-to-end against Anthropic. Tests stub the HTTP layer with WebMock; no real API calls in CI.

**Architecture:** Thin per-provider adapter wrapping the official `anthropic` Ruby SDK. Purpose-keyed registry (`Llm::Provider.for(:purpose)`) returns an adapter instance. `Llm::Call.execute` orchestrates: lookup → adapter call → cost computation → persist `LlmCall` row regardless of HTTP outcome (config errors raise without persisting). Diagnostics tool is one composite ViewComponent (form + optional last-call result panel). Admin layout + `Admin::ApplicationController` introduced here so the new diagnostics page slots in cleanly alongside campaigns.

**Tech Stack:** Rails 8.1 · PostgreSQL · `anthropic` Ruby SDK (~> 1.41) · WebMock · ViewComponent · RSpec · factory_bot · shoulda-matchers · Capybara (rack_test).

**Spec:** [`docs/superpowers/specs/2026-05-14-v2-phase-4-llm-provider-and-anthropic-adapter-design.md`](../specs/2026-05-14-v2-phase-4-llm-provider-and-anthropic-adapter-design.md).

**Spec deviation:** the spec mentions Lookbook previews for new components (`show_component_preview.rb`, `result_panel_component_preview.rb`, `nav_component_preview.rb`). Phases 1–3 shipped without `spec/components/previews/`; the project has no preview file pattern yet. To match the project's actual state, this plan omits preview files. They can be added uniformly across all components in a small follow-up if/when Lookbook previews get adopted.

---

## File structure

**Gems + test infra (Task 1):**
- `Gemfile` — modified (add `anthropic`, add `webmock` test-group)
- `Gemfile.lock` — regenerated
- `spec/rails_helper.rb` — modified (require + disable_net_connect)
- `spec/support/llm.rb` — new (resets Anthropic SDK client memo)

**Migration + model (Task 2):**
- `db/migrate/<ts>_create_llm_calls.rb` — new
- `app/models/llm_call.rb` — new
- `app/models/user.rb` — modified (`has_many :llm_calls`)
- `app/models/campaign.rb` — modified (`has_many :llm_calls`)
- `spec/factories/llm_calls.rb` — new
- `spec/models/llm_call_spec.rb` — new
- `spec/models/user_spec.rb` — modified
- `spec/models/campaign_spec.rb` — modified

**Llm namespace (Tasks 3–7):**
- `app/lib/llm/error.rb` — new
- `app/lib/llm/result.rb` — new
- `app/lib/llm/pricing.rb` — new
- `app/lib/llm/provider.rb` — new
- `app/lib/llm/providers/anthropic.rb` — new
- `app/lib/llm/call.rb` — new
- `app/lib/llm/diagnostics_form.rb` — new
- `spec/lib/llm/pricing_spec.rb` — new
- `spec/lib/llm/provider_spec.rb` — new
- `spec/lib/llm/providers/anthropic_spec.rb` — new
- `spec/lib/llm/call_spec.rb` — new
- `spec/lib/llm/diagnostics_form_spec.rb` — new

**Admin layout (Task 8):**
- `app/controllers/admin/application_controller.rb` — new
- `app/controllers/admin/campaigns_controller.rb` — modified (inherit from `Admin::ApplicationController`)
- `app/views/layouts/admin.html.erb` — new
- `app/components/admin/nav_component.rb` + `.html.erb` — new
- `spec/components/admin/nav_component_spec.rb` — new

**Diagnostics tool (Tasks 9–10):**
- `config/routes/admin.rb` — modified (`namespace :diagnostics`)
- `app/controllers/admin/diagnostics/llm_controller.rb` — new
- `app/components/admin/diagnostics/llm/show_component.rb` + `.html.erb` — new
- `app/components/admin/diagnostics/llm/result_panel_component.rb` + `.html.erb` — new
- `spec/requests/admin/diagnostics/llm_spec.rb` — new
- `spec/components/admin/diagnostics/llm/show_component_spec.rb` — new
- `spec/components/admin/diagnostics/llm/result_panel_component_spec.rb` — new

**Polish + deploy (Task 11):**
- `.env.example` — modified (or created)
- `README.md` — modified (Operations/LLM diagnostics sub-section)

---

## Task 1: Add gems and WebMock infrastructure

**Files:**
- Modify: `Gemfile`
- Modify: `spec/rails_helper.rb`
- Create: `spec/support/llm.rb`

- [ ] **Step 1: Add the `anthropic` gem to the default group**

Edit `Gemfile`. Insert this line in alphabetical order alongside the other top-level gems (between `gem "annotaterb"` placement — note: `annotaterb` is in development group; the right placement is between `gem "anthropic"` and the existing default-group entries near the top):

```ruby
gem "anthropic"
```

The default-group placement should land near the top of the file in roughly alphabetical order. Locate the existing `gem "bootsnap", require: false` line and insert `gem "anthropic"` immediately above it.

- [ ] **Step 2: Add `webmock` to the test group**

In `Gemfile`, locate the `group :test do ... end` block (currently contains only `gem "capybara"`). Add inside it:

```ruby
gem "webmock"
```

The block should now read:

```ruby
group :test do
  gem "capybara"
  gem "webmock"
end
```

- [ ] **Step 3: Install the gems**

Run: `bundle install`
Expected: `Bundle complete! N Gemfile dependencies, M gems now installed.`. The `anthropic` and `webmock` gems should appear in the output. `Gemfile.lock` should be modified.

If `bundle install` fails with a Ruby version constraint, verify the project Ruby is `4.0.2` (which satisfies the SDK's `>= 3.2.0` requirement) and re-run.

- [ ] **Step 4: Wire WebMock into rails_helper**

Edit `spec/rails_helper.rb`. Find the `require 'rspec/rails'` line. Immediately after it, add:

```ruby
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)
```

The `allow_localhost: true` keeps Capybara / Selenium-driven specs working if they're added later.

- [ ] **Step 5: Create the LLM support file**

Create `spec/support/llm.rb`:

```ruby
RSpec.configure do |config|
  config.before(:each) do
    Llm::Providers::Anthropic.reset_client! if defined?(Llm::Providers::Anthropic)
  end
end
```

The `if defined?` guard avoids load-order issues during the early tasks (Tasks 1–6) when the Anthropic adapter class doesn't exist yet. Once Task 7 lands the class, the guard becomes a no-op cost.

- [ ] **Step 6: Run the existing test suite to verify nothing regressed**

Run: `bundle exec rspec`
Expected: all existing specs pass (Phase 1–3 tests). No real-network failures because no current spec hits the network.

- [ ] **Step 7: Commit**

```bash
git add Gemfile Gemfile.lock spec/rails_helper.rb spec/support/llm.rb
git commit -m "Add anthropic + webmock gems; wire WebMock into rails_helper (Phase 4.1)"
```

---

## Task 2: `llm_calls` table + `LlmCall` model + factory + spec

**Files:**
- Create: `db/migrate/<ts>_create_llm_calls.rb`
- Create: `app/models/llm_call.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/campaign.rb`
- Create: `spec/factories/llm_calls.rb`
- Create: `spec/models/llm_call_spec.rb`
- Modify: `spec/models/user_spec.rb`
- Modify: `spec/models/campaign_spec.rb`

- [ ] **Step 1: Write the failing model spec**

Create `spec/models/llm_call_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe LlmCall, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:campaign).optional }
  end

  describe "validations" do
    subject { build(:llm_call) }

    it { is_expected.to validate_presence_of(:purpose) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:model) }
  end

  describe "#text" do
    it "extracts the response content text from response_payload" do
      call = build(:llm_call,
        response_payload: {
          "content" => [{ "type" => "text", "text" => "Hello, narrator." }]
        }
      )
      expect(call.text).to eq("Hello, narrator.")
    end

    it "returns nil for an errored call" do
      call = build(:llm_call, :errored)
      expect(call.text).to be_nil
    end
  end

  describe "#successful?" do
    it "is true when response_payload has no error key" do
      expect(build(:llm_call)).to be_successful
    end

    it "is false when response_payload has an error key" do
      expect(build(:llm_call, :errored)).not_to be_successful
    end
  end

  describe "#error_message" do
    it "is nil for a successful call" do
      expect(build(:llm_call).error_message).to be_nil
    end

    it "extracts the error message for an errored call" do
      expect(build(:llm_call, :errored).error_message).to eq("Internal server error")
    end
  end

  describe "#total_cost_dollars" do
    it "divides total_cost_cents by 100" do
      expect(build(:llm_call, total_cost_cents: 250).total_cost_dollars).to eq(2.5)
    end
  end

  describe "cascade deletes" do
    it "is destroyed when its user is destroyed" do
      user = create(:user)
      create(:llm_call, user: user)
      expect { user.destroy }.to change(LlmCall, :count).by(-1)
    end

    it "is destroyed when its campaign is destroyed" do
      campaign = create(:campaign)
      create(:llm_call, user: campaign.user, campaign: campaign)
      expect { campaign.destroy }.to change(LlmCall, :count).by(-1)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/models/llm_call_spec.rb`
Expected: failure with `NameError: uninitialized constant LlmCall`.

- [ ] **Step 3: Generate and edit the migration**

Run: `bin/rails g migration CreateLlmCalls`

This creates a timestamped file like `db/migrate/20260514XXXXXX_create_llm_calls.rb`. Open it and replace the body with:

```ruby
class CreateLlmCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_calls do |t|
      t.references :user,     null: false, foreign_key: { on_delete: :cascade }
      t.references :campaign, null: true,  foreign_key: { on_delete: :cascade }
      t.references :scene,    null: true,  index: true
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

Note: `t.references :scene` writes the column + index but does **not** add a foreign key. The `scenes` table doesn't exist until Phase 5, which will add the FK then.

- [ ] **Step 4: Run the migration**

Run: `bin/rails db:migrate`
Expected: `== CreateLlmCalls: migrated` line in output, `db/schema.rb` updated with the new table.

- [ ] **Step 5: Create the `LlmCall` model**

Create `app/models/llm_call.rb`:

```ruby
class LlmCall < ApplicationRecord
  belongs_to :user
  belongs_to :campaign, optional: true
  # belongs_to :scene, optional: true  # uncomment in Phase 5 when Scene model exists

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

- [ ] **Step 6: Add the inverse associations on User and Campaign**

Edit `app/models/user.rb`. Add `has_many :llm_calls, dependent: :destroy` near the other associations:

```ruby
has_many :campaigns, dependent: :destroy
has_many :llm_calls, dependent: :destroy
belongs_to :last_played_campaign,
           class_name: "Campaign",
           optional: true
```

Edit `app/models/campaign.rb`. Add `has_many :llm_calls, dependent: :destroy`:

```ruby
class Campaign < ApplicationRecord
  belongs_to :user
  has_many :llm_calls, dependent: :destroy

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id, case_sensitive: false }
end
```

(Existing validations preserved verbatim — only the new association line is added.)

- [ ] **Step 7: Create the factory**

Create `spec/factories/llm_calls.rb`:

```ruby
FactoryBot.define do
  factory :llm_call do
    user
    purpose  { "diagnostics" }
    provider { "anthropic" }
    model    { "claude-sonnet-4-6" }
    input_tokens     { 100 }
    output_tokens    { 50 }
    total_cost_cents { 105 }
    latency_ms       { 1234 }
    provider_request_id { "msg_#{SecureRandom.hex(8)}" }
    prompt_payload do
      {
        "model" => "claude-sonnet-4-6",
        "max_tokens" => 1024,
        "messages" => [{ "role" => "user", "content" => "Hello" }]
      }
    end
    response_payload do
      {
        "id" => provider_request_id,
        "model" => "claude-sonnet-4-6",
        "content" => [{ "type" => "text", "text" => "Hi there!" }],
        "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
      }
    end

    trait :errored do
      input_tokens { 0 }
      output_tokens { 0 }
      total_cost_cents { 0 }
      provider_request_id { nil }
      response_payload do
        {
          "error" => {
            "class" => "Anthropic::Errors::InternalServerError",
            "message" => "Internal server error"
          }
        }
      end
    end
  end
end
```

- [ ] **Step 8: Update existing model specs**

Edit `spec/models/user_spec.rb`. Locate the associations `describe` block and add:

```ruby
it { is_expected.to have_many(:llm_calls).dependent(:destroy) }
```

Edit `spec/models/campaign_spec.rb`. Locate the associations `describe` block and add the same line. (If `campaign_spec.rb` doesn't have an associations block, add one alongside the existing validations block.)

- [ ] **Step 9: Run model specs to verify they pass**

Run: `bundle exec rspec spec/models`
Expected: all model specs (existing User, Campaign + new LlmCall) pass.

- [ ] **Step 10: Run annotaterb to update model annotations**

Run: `bundle exec annotaterb models`
Expected: schema annotations added/updated atop `app/models/llm_call.rb`, `app/models/user.rb`, `app/models/campaign.rb`.

- [ ] **Step 11: Commit**

```bash
git add db/migrate db/schema.rb app/models spec/models spec/factories/llm_calls.rb
git commit -m "Add llm_calls table + LlmCall model + factory (Phase 4.2)"
```

---

## Task 3: `Llm::Error` hierarchy

**Files:**
- Create: `app/lib/llm/error.rb`

This is a tiny task with no spec of its own — the error classes are exercised by Tasks 5, 6, 7, 8.

- [ ] **Step 1: Create the error file**

Create `app/lib/llm/error.rb`:

```ruby
module Llm
  class Error < StandardError; end

  class ConfigError < Error; end

  class ProviderError < Error
    attr_reader :provider_class, :provider_message

    def initialize(provider_class:, provider_message:)
      @provider_class   = provider_class
      @provider_message = provider_message
      super("[#{provider_class}] #{provider_message}")
    end
  end
end
```

- [ ] **Step 2: Verify it loads**

Run: `bundle exec rails runner 'puts Llm::ConfigError.ancestors.first(3).inspect'`
Expected: `[Llm::ConfigError, Llm::Error, StandardError]`. Confirms autoload picks up `app/lib/llm/error.rb`.

- [ ] **Step 3: Commit**

```bash
git add app/lib/llm/error.rb
git commit -m "Add Llm::Error hierarchy (Phase 4.3)"
```

---

## Task 4: `Llm::Result` value object

**Files:**
- Create: `app/lib/llm/result.rb`

No standalone spec — exercised via the adapter spec in Task 7.

- [ ] **Step 1: Create the Result file**

Create `app/lib/llm/result.rb`:

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
    :error
  ) do
    def successful?
      error.nil?
    end
  end
end
```

- [ ] **Step 2: Verify the Data class works**

Run:

```bash
bundle exec rails runner '
result = Llm::Result.new(
  text: "hi", input_tokens: 1, output_tokens: 1,
  cache_creation_tokens: 0, cache_read_tokens: 0,
  provider_request_id: "msg_x", prompt_payload: {}, response_payload: {},
  latency_ms: 42, error: nil
)
puts result.successful?
'
```

Expected: prints `true`.

- [ ] **Step 3: Commit**

```bash
git add app/lib/llm/result.rb
git commit -m "Add Llm::Result value object (Phase 4.4)"
```

---

## Task 5: `Llm::Pricing` module + spec

**Files:**
- Create: `app/lib/llm/pricing.rb`
- Create: `spec/lib/llm/pricing_spec.rb`

- [ ] **Step 1: Write the failing pricing spec**

Create `spec/lib/llm/pricing_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Llm::Pricing do
  describe ".cost_cents" do
    it "computes Sonnet 4.6 input + output cost" do
      cost = described_class.cost_cents(
        usage: { input: 1_000_000, output: 500_000, cache_creation: 0, cache_read: 0 },
        model: "claude-sonnet-4-6"
      )
      # 1M input @ $3 = $3.00 = 300 cents
      # 500K output @ $15 = $7.50 = 750 cents
      # total = 1050 cents
      expect(cost).to eq(1050)
    end

    it "computes Sonnet 4.6 cache_creation cost (5m default)" do
      cost = described_class.cost_cents(
        usage: { input: 0, output: 0, cache_creation: 1_000_000, cache_read: 0 },
        model: "claude-sonnet-4-6"
      )
      # 1M cache_creation @ $3.75 (5m write) = $3.75 = 375 cents
      expect(cost).to eq(375)
    end

    it "uses 1h cache write rate when cache_ttl: :ephemeral_1h" do
      cost = described_class.cost_cents(
        usage: { input: 0, output: 0, cache_creation: 1_000_000, cache_read: 0 },
        model: "claude-sonnet-4-6",
        cache_ttl: :ephemeral_1h
      )
      # 1M cache_creation @ $6 (1h write) = $6.00 = 600 cents
      expect(cost).to eq(600)
    end

    it "computes Sonnet 4.6 cache_read cost" do
      cost = described_class.cost_cents(
        usage: { input: 0, output: 0, cache_creation: 0, cache_read: 1_000_000 },
        model: "claude-sonnet-4-6"
      )
      # 1M cache_read @ $0.30 = $0.30 = 30 cents
      expect(cost).to eq(30)
    end

    it "rounds sub-cent values to the nearest cent" do
      cost = described_class.cost_cents(
        usage: { input: 1, output: 0, cache_creation: 0, cache_read: 0 },
        model: "claude-sonnet-4-6"
      )
      # 1 input token @ $3/MTok = $0.000003 = 0.0003 cents → rounds to 0
      expect(cost).to eq(0)
    end

    it "computes Opus 4.7 rates correctly" do
      cost = described_class.cost_cents(
        usage: { input: 1_000_000, output: 0, cache_creation: 0, cache_read: 0 },
        model: "claude-opus-4-7"
      )
      # 1M input @ $5 = $5.00 = 500 cents
      expect(cost).to eq(500)
    end

    it "computes Haiku 4.5 rates correctly" do
      cost = described_class.cost_cents(
        usage: { input: 1_000_000, output: 0, cache_creation: 0, cache_read: 0 },
        model: "claude-haiku-4-5"
      )
      # 1M input @ $1 = $1.00 = 100 cents
      expect(cost).to eq(100)
    end

    it "raises Llm::ConfigError for an unknown model" do
      expect {
        described_class.cost_cents(
          usage: { input: 0, output: 0, cache_creation: 0, cache_read: 0 },
          model: "claude-mythical-99"
        )
      }.to raise_error(Llm::ConfigError, /Unknown model/)
    end

    it "raises Llm::ConfigError for an unknown cache_ttl" do
      expect {
        described_class.cost_cents(
          usage: { input: 0, output: 0, cache_creation: 1, cache_read: 0 },
          model: "claude-sonnet-4-6",
          cache_ttl: :forever
        )
      }.to raise_error(Llm::ConfigError, /Unknown cache_ttl/)
    end
  end

  describe ".known_models" do
    it "lists all priced models" do
      expect(described_class.known_models).to contain_exactly(
        "claude-sonnet-4-6", "claude-opus-4-7", "claude-haiku-4-5"
      )
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/lib/llm/pricing_spec.rb`
Expected: failure with `NameError: uninitialized constant Llm::Pricing`.

- [ ] **Step 3: Create the pricing module**

Create `app/lib/llm/pricing.rb`:

```ruby
require "bigdecimal"

module Llm
  module Pricing
    # USD per million tokens. Verified against
    # https://platform.claude.com/docs/en/about-claude/pricing on 2026-05-14.
    RATES = {
      "claude-sonnet-4-6" => {
        input:          3.00,
        output:         15.00,
        cache_write_5m: 3.75,
        cache_write_1h: 6.00,
        cache_read:     0.30
      },
      "claude-opus-4-7" => {
        input:          5.00,
        output:         25.00,
        cache_write_5m: 6.25,
        cache_write_1h: 10.00,
        cache_read:     0.50
      },
      "claude-haiku-4-5" => {
        input:          1.00,
        output:         5.00,
        cache_write_5m: 1.25,
        cache_write_1h: 2.00,
        cache_read:     0.10
      }
    }.freeze

    PER_MTOK = BigDecimal("1_000_000")

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

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/lib/llm/pricing_spec.rb`
Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/llm/pricing.rb spec/lib/llm/pricing_spec.rb
git commit -m "Add Llm::Pricing with Sonnet 4.6 / Opus 4.7 / Haiku 4.5 rates (Phase 4.5)"
```

---

## Task 6: `Llm::Provider` registry + spec (with adapter shell)

**Files:**
- Create: `app/lib/llm/provider.rb`
- Create: `app/lib/llm/providers/anthropic.rb` (shell only — full implementation in Task 7)
- Create: `spec/lib/llm/provider_spec.rb`

This task lands the registry and a minimal Anthropic adapter shell so the provider spec can pass without WebMock setup. Task 7 fleshes out the adapter and adds the WebMock-driven adapter spec.

- [ ] **Step 1: Write the failing provider spec**

Create `spec/lib/llm/provider_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Llm::Provider do
  describe ".for" do
    it "returns an Anthropic adapter for :narration with the registered model" do
      adapter = described_class.for(:narration)
      expect(adapter).to be_a(Llm::Providers::Anthropic)
      expect(adapter.model).to eq("claude-sonnet-4-6")
    end

    it "returns an Anthropic adapter for :diagnostics" do
      adapter = described_class.for(:diagnostics)
      expect(adapter).to be_a(Llm::Providers::Anthropic)
      expect(adapter.model).to eq("claude-sonnet-4-6")
    end

    it "returns an Anthropic adapter for :intake_long_context (Gemini placeholder)" do
      adapter = described_class.for(:intake_long_context)
      expect(adapter).to be_a(Llm::Providers::Anthropic)
      expect(adapter.model).to eq("claude-sonnet-4-6")
    end

    it "raises Llm::ConfigError for an unknown purpose" do
      expect { described_class.for(:fortune_telling) }
        .to raise_error(Llm::ConfigError, /Unknown purpose/)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/lib/llm/provider_spec.rb`
Expected: failure with `NameError: uninitialized constant Llm::Provider`.

- [ ] **Step 3: Create the Anthropic adapter shell**

Create `app/lib/llm/providers/anthropic.rb`:

```ruby
module Llm
  module Providers
    class Anthropic
      attr_reader :model

      def initialize(model:)
        @model = model
      end

      # Full implementation lands in Task 7.
      def call(system: nil, messages:, max_tokens: 1024)
        raise NotImplementedError, "Implemented in Phase 4.7"
      end

      def self.sdk_client
        @sdk_client ||= ::Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
      end

      def self.reset_client!
        @sdk_client = nil
      end
    end
  end
end
```

- [ ] **Step 4: Create the provider registry**

Create `app/lib/llm/provider.rb`:

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

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/lib/llm/provider_spec.rb`
Expected: all examples pass.

- [ ] **Step 6: Commit**

```bash
git add app/lib/llm/provider.rb app/lib/llm/providers/anthropic.rb spec/lib/llm/provider_spec.rb
git commit -m "Add Llm::Provider registry + Anthropic adapter shell (Phase 4.6)"
```

---

## Task 7: `Llm::Providers::Anthropic` full implementation + WebMock spec

**Files:**
- Modify: `app/lib/llm/providers/anthropic.rb` (replace shell with full impl)
- Create: `spec/lib/llm/providers/anthropic_spec.rb`

- [ ] **Step 1: Write the failing adapter spec**

Create `spec/lib/llm/providers/anthropic_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Llm::Providers::Anthropic do
  let(:adapter) { described_class.new(model: "claude-sonnet-4-6") }
  let(:messages) { [{ role: "user", content: "Hello" }] }

  before do
    ENV["ANTHROPIC_API_KEY"] = "sk-ant-test-key"
  end

  describe "#call (success path)" do
    let(:successful_response_body) do
      {
        id: "msg_01ABCDEF",
        type: "message",
        role: "assistant",
        model: "claude-sonnet-4-6",
        content: [{ type: "text", text: "Hi there!" }],
        stop_reason: "end_turn",
        usage: {
          input_tokens: 12,
          output_tokens: 7,
          cache_creation_input_tokens: 0,
          cache_read_input_tokens: 0
        }
      }
    end

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: successful_response_body.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns a successful Llm::Result with parsed text and tokens" do
      result = adapter.call(messages: messages)

      expect(result).to be_a(Llm::Result)
      expect(result).to be_successful
      expect(result.text).to eq("Hi there!")
      expect(result.input_tokens).to eq(12)
      expect(result.output_tokens).to eq(7)
      expect(result.cache_creation_tokens).to eq(0)
      expect(result.cache_read_tokens).to eq(0)
      expect(result.provider_request_id).to eq("msg_01ABCDEF")
      expect(result.error).to be_nil
    end

    it "captures latency_ms" do
      result = adapter.call(messages: messages)
      expect(result.latency_ms).to be_a(Integer)
      expect(result.latency_ms).to be >= 0
    end

    it "captures the request body in prompt_payload" do
      result = adapter.call(system: "You are a narrator.", messages: messages, max_tokens: 256)
      expect(result.prompt_payload).to include(
        "model" => "claude-sonnet-4-6",
        "max_tokens" => 256,
        "system" => "You are a narrator.",
        "messages" => [{ "role" => "user", "content" => "Hello" }]
      )
    end

    it "captures the response body in response_payload" do
      result = adapter.call(messages: messages)
      expect(result.response_payload).to include(
        "id" => "msg_01ABCDEF",
        "content" => [{ "type" => "text", "text" => "Hi there!" }]
      )
    end

    it "captures cache token counts when present" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: successful_response_body.merge(
            usage: {
              input_tokens: 12,
              output_tokens: 7,
              cache_creation_input_tokens: 1500,
              cache_read_input_tokens: 800
            }
          ).to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = adapter.call(messages: messages)
      expect(result.cache_creation_tokens).to eq(1500)
      expect(result.cache_read_tokens).to eq(800)
    end

    it "omits the system parameter when not provided" do
      adapter.call(messages: messages)

      expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
        .with { |req|
          body = JSON.parse(req.body)
          !body.key?("system")
        }
    end
  end

  describe "#call (error paths)" do
    it "captures a 500 server error into result.error and response_payload" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 500, body: { error: { type: "internal_server_error", message: "boom" } }.to_json)

      result = adapter.call(messages: messages)

      expect(result).not_to be_successful
      expect(result.error).to be_a(Llm::ProviderError)
      expect(result.input_tokens).to eq(0)
      expect(result.output_tokens).to eq(0)
      expect(result.cache_creation_tokens).to eq(0)
      expect(result.cache_read_tokens).to eq(0)
      expect(result.provider_request_id).to be_nil
      expect(result.response_payload).to have_key("error")
      expect(result.response_payload.dig("error", "class")).to be_present
      expect(result.response_payload.dig("error", "message")).to be_present
    end

    it "captures a 429 rate-limit error into result.error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 429, body: { error: { type: "rate_limit_error", message: "slow down" } }.to_json)

      result = adapter.call(messages: messages)

      expect(result).not_to be_successful
      expect(result.error).to be_a(Llm::ProviderError)
    end

    it "captures a network timeout into result.error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_timeout

      result = adapter.call(messages: messages)

      expect(result).not_to be_successful
      expect(result.error).to be_a(Llm::ProviderError)
    end

    it "still records prompt_payload and latency_ms on error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(status: 500)

      result = adapter.call(messages: messages)

      expect(result.prompt_payload).to include("model" => "claude-sonnet-4-6")
      expect(result.latency_ms).to be_a(Integer)
    end
  end

  describe "#call (config errors)" do
    it "raises Llm::ConfigError when ANTHROPIC_API_KEY is missing" do
      ENV.delete("ANTHROPIC_API_KEY")
      expect { adapter.call(messages: messages) }
        .to raise_error(Llm::ConfigError, /ANTHROPIC_API_KEY/)
    end

    it "raises Llm::ConfigError when ANTHROPIC_API_KEY is blank" do
      ENV["ANTHROPIC_API_KEY"] = ""
      expect { adapter.call(messages: messages) }
        .to raise_error(Llm::ConfigError, /ANTHROPIC_API_KEY/)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/lib/llm/providers/anthropic_spec.rb`
Expected: failures with `NotImplementedError: Implemented in Phase 4.7` (the shell from Task 6).

- [ ] **Step 3: Replace the adapter shell with the full implementation**

Open `app/lib/llm/providers/anthropic.rb` and replace its full contents with:

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
          latency_ms = elapsed_ms(started_at)

          Llm::Result.new(
            text:                  response.content.first.text,
            input_tokens:          response.usage.input_tokens.to_i,
            output_tokens:         response.usage.output_tokens.to_i,
            cache_creation_tokens: cache_creation_from(response.usage),
            cache_read_tokens:     cache_read_from(response.usage),
            provider_request_id:   response.id,
            prompt_payload:        request_body.deep_stringify_keys,
            response_payload:      response.to_hash.deep_stringify_keys,
            latency_ms:            latency_ms,
            error:                 nil
          )
        rescue ::Anthropic::Errors::APIError, ::Anthropic::Errors::Error => e
          latency_ms = elapsed_ms(started_at)
          Llm::Result.new(
            text: nil,
            input_tokens: 0, output_tokens: 0,
            cache_creation_tokens: 0, cache_read_tokens: 0,
            provider_request_id: nil,
            prompt_payload: request_body.deep_stringify_keys,
            response_payload: { "error" => { "class" => e.class.name, "message" => e.message } },
            latency_ms: latency_ms,
            error: Llm::ProviderError.new(
              provider_class:   e.class.name,
              provider_message: e.message
            )
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

      def elapsed_ms(started_at)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      end

      def cache_creation_from(usage)
        return 0 unless usage.respond_to?(:cache_creation_input_tokens)
        value = usage.cache_creation_input_tokens
        value.nil? ? 0 : value.to_i
      end

      def cache_read_from(usage)
        return 0 unless usage.respond_to?(:cache_read_input_tokens)
        value = usage.cache_read_input_tokens
        value.nil? ? 0 : value.to_i
      end
    end
  end
end
```

**Implementation note on rescue clauses:** the rescue catches both `Anthropic::Errors::APIError` and `Anthropic::Errors::Error` to handle different SDK error class hierarchies across versions. If `bundle exec rspec` reports `NameError: uninitialized constant Anthropic::Errors::APIError` or `Anthropic::Errors::Error`, inspect the installed SDK with `bundle show anthropic` and `ls $(bundle show anthropic)/lib/anthropic/errors*`, then adjust the rescue to match the actual class names (likely `Anthropic::APIError` / `Anthropic::Error` in older SDK majors). Update the rescue line and re-run.

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/lib/llm/providers/anthropic_spec.rb`
Expected: all examples pass.

If a spec fails because the SDK error class is named differently, follow the implementation note above to adjust.

If the `to_timeout` spec fails because the SDK wraps timeouts in a non-APIError class (e.g., `Anthropic::Errors::APIConnectionError`), add that class to the rescue clause.

- [ ] **Step 5: Run the full Llm namespace specs to confirm nothing else broke**

Run: `bundle exec rspec spec/lib/llm`
Expected: pricing, provider, and adapter specs all pass.

- [ ] **Step 6: Commit**

```bash
git add app/lib/llm/providers/anthropic.rb spec/lib/llm/providers/anthropic_spec.rb
git commit -m "Implement Llm::Providers::Anthropic with WebMock test coverage (Phase 4.7)"
```

---

## Task 8: `Llm::Call` orchestrator + spec

**Files:**
- Create: `app/lib/llm/call.rb`
- Create: `spec/lib/llm/call_spec.rb`

- [ ] **Step 1: Write the failing call spec**

Create `spec/lib/llm/call_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Llm::Call do
  let(:user) { create(:user) }
  let(:messages) { [{ role: "user", content: "Hello" }] }

  before do
    ENV["ANTHROPIC_API_KEY"] = "sk-ant-test-key"
  end

  describe ".execute (success path)" do
    let(:successful_response_body) do
      {
        id: "msg_01ABCDEF",
        type: "message",
        role: "assistant",
        model: "claude-sonnet-4-6",
        content: [{ type: "text", text: "Hi!" }],
        stop_reason: "end_turn",
        usage: { input_tokens: 1_000_000, output_tokens: 500_000,
                 cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
      }
    end

    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: successful_response_body.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "persists an LlmCall row with full fields" do
      expect {
        described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      }.to change(LlmCall, :count).by(1)

      call = LlmCall.last
      expect(call.user).to eq(user)
      expect(call.campaign).to be_nil
      expect(call.purpose).to eq("diagnostics")
      expect(call.provider).to eq("anthropic")
      expect(call.model).to eq("claude-sonnet-4-6")
      expect(call.input_tokens).to eq(1_000_000)
      expect(call.output_tokens).to eq(500_000)
      expect(call.provider_request_id).to eq("msg_01ABCDEF")
      expect(call.prompt_payload).to include("model" => "claude-sonnet-4-6")
      expect(call.response_payload).to include("id" => "msg_01ABCDEF")
    end

    it "computes total_cost_cents from token usage" do
      call = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      # 1M input @ $3 = $3.00 = 300 cents
      # 500K output @ $15 = $7.50 = 750 cents
      # total = 1050 cents
      expect(call.total_cost_cents).to eq(1050)
    end

    it "returns the persisted LlmCall record" do
      result = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      expect(result).to be_a(LlmCall)
      expect(result).to be_persisted
    end

    it "uses the model override when provided" do
      call = described_class.execute(
        purpose: :diagnostics, messages: messages, user: user, model: "claude-haiku-4-5"
      )
      expect(call.model).to eq("claude-haiku-4-5")
      # 1M input @ $1 = $1.00 = 100 cents
      # 500K output @ $5 = $2.50 = 250 cents
      # total = 350 cents
      expect(call.total_cost_cents).to eq(350)
    end

    it "raises Llm::ConfigError on an unknown model override" do
      expect {
        described_class.execute(
          purpose: :diagnostics, messages: messages, user: user, model: "claude-mythical-99"
        )
      }.to raise_error(Llm::ConfigError, /Unknown model/)
    end

    it "associates the call with a campaign when provided" do
      campaign = create(:campaign, user: user)
      call = described_class.execute(
        purpose: :diagnostics, messages: messages, user: user, campaign: campaign
      )
      expect(call.campaign).to eq(campaign)
    end

    it "passes a system prompt through to the adapter" do
      described_class.execute(
        purpose: :diagnostics, messages: messages, user: user, system: "You are a bard."
      )

      expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
        .with { |req| JSON.parse(req.body)["system"] == "You are a bard." }
    end
  end

  describe ".execute (HTTP error)" do
    before do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 500, body: { error: { type: "internal_server_error", message: "boom" } }.to_json)
    end

    it "still persists an LlmCall row" do
      expect {
        described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      }.to change(LlmCall, :count).by(1)
    end

    it "writes tokens=0 and cost=0 on error" do
      call = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      expect(call.input_tokens).to eq(0)
      expect(call.output_tokens).to eq(0)
      expect(call.total_cost_cents).to eq(0)
    end

    it "captures the error in response_payload" do
      call = described_class.execute(purpose: :diagnostics, messages: messages, user: user)
      expect(call.response_payload).to have_key("error")
      expect(call).not_to be_successful
    end
  end

  describe ".execute (config error)" do
    it "raises Llm::ConfigError without persisting a row when API key is missing" do
      ENV.delete("ANTHROPIC_API_KEY")
      expect {
        expect {
          described_class.execute(purpose: :diagnostics, messages: messages, user: user)
        }.to raise_error(Llm::ConfigError)
      }.not_to change(LlmCall, :count)
    end

    it "raises Llm::ConfigError on an unknown purpose" do
      expect {
        described_class.execute(purpose: :fortune_telling, messages: messages, user: user)
      }.to raise_error(Llm::ConfigError, /Unknown purpose/)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/lib/llm/call_spec.rb`
Expected: failure with `NameError: uninitialized constant Llm::Call`.

- [ ] **Step 3: Create `Llm::Call`**

Create `app/lib/llm/call.rb`:

```ruby
module Llm
  module Call
    # Returns the persisted LlmCall record. Raises Llm::ConfigError on
    # missing API key or unknown purpose / model override. Never raises
    # on HTTP errors — those are persisted into the row's response_payload.
    def self.execute(purpose:, messages:, system: nil, max_tokens: 1024,
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

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/lib/llm/call_spec.rb`
Expected: all examples pass.

- [ ] **Step 5: Run the full Llm namespace specs**

Run: `bundle exec rspec spec/lib/llm`
Expected: all pricing, provider, adapter, and call specs pass.

- [ ] **Step 6: Commit**

```bash
git add app/lib/llm/call.rb spec/lib/llm/call_spec.rb
git commit -m "Add Llm::Call orchestrator with cost computation + persistence (Phase 4.8)"
```

---

## Task 9: `Llm::DiagnosticsForm` PORO + spec

**Files:**
- Create: `app/lib/llm/diagnostics_form.rb`
- Create: `spec/lib/llm/diagnostics_form_spec.rb`

- [ ] **Step 1: Write the failing form spec**

Create `spec/lib/llm/diagnostics_form_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Llm::DiagnosticsForm do
  describe "validations" do
    it "requires a prompt" do
      form = described_class.new(prompt: "", model: "claude-sonnet-4-6")
      expect(form).not_to be_valid
      expect(form.errors[:prompt]).to be_present
    end

    it "requires a model" do
      form = described_class.new(prompt: "Hi", model: nil)
      expect(form).not_to be_valid
      expect(form.errors[:model]).to be_present
    end

    it "rejects an unknown model" do
      form = described_class.new(prompt: "Hi", model: "claude-mythical-99")
      expect(form).not_to be_valid
      expect(form.errors[:model]).to be_present
    end

    it "accepts a known model" do
      form = described_class.new(prompt: "Hi", model: "claude-sonnet-4-6")
      expect(form).to be_valid
    end

    it "treats system_prompt as optional" do
      form = described_class.new(prompt: "Hi", model: "claude-sonnet-4-6", system_prompt: nil)
      expect(form).to be_valid
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/lib/llm/diagnostics_form_spec.rb`
Expected: failure with `NameError: uninitialized constant Llm::DiagnosticsForm`.

- [ ] **Step 3: Create the form**

Create `app/lib/llm/diagnostics_form.rb`:

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
                       inclusion: { in: ->(_form) { Llm::Pricing.known_models },
                                    allow_blank: true,
                                    message: "is not a known model" }
  end
end
```

The `allow_blank: true` on the inclusion validator avoids stacking a duplicate "is not a known model" error on top of the presence error when the field is blank.

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/lib/llm/diagnostics_form_spec.rb`
Expected: all examples pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/llm/diagnostics_form.rb spec/lib/llm/diagnostics_form_spec.rb
git commit -m "Add Llm::DiagnosticsForm form-backing PORO (Phase 4.9)"
```

---

## Task 10: Admin layout + nav + `Admin::ApplicationController`

**Files:**
- Create: `app/controllers/admin/application_controller.rb`
- Modify: `app/controllers/admin/campaigns_controller.rb`
- Create: `app/views/layouts/admin.html.erb`
- Create: `app/components/admin/nav_component.rb`
- Create: `app/components/admin/nav_component.html.erb`
- Create: `spec/components/admin/nav_component_spec.rb`

- [ ] **Step 1: Write the failing nav component spec**

Create `spec/components/admin/nav_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::NavComponent, type: :component do
  it "renders a Campaigns link" do
    render_inline(described_class.new(current_path: "/dashboard"))
    expect(page).to have_link("Campaigns", href: "/campaigns")
  end

  it "renders a Diagnostics link" do
    render_inline(described_class.new(current_path: "/dashboard"))
    expect(page).to have_link(/Diagnostics/, href: "/diagnostics/llm")
  end

  it "marks the Campaigns link as active when path matches" do
    render_inline(described_class.new(current_path: "/campaigns"))
    expect(page).to have_css("a[href='/campaigns'][aria-current='page']")
  end

  it "marks the Diagnostics link as active when path starts with /diagnostics" do
    render_inline(described_class.new(current_path: "/diagnostics/llm"))
    expect(page).to have_css("a[href='/diagnostics/llm'][aria-current='page']")
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/admin/nav_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Admin::NavComponent`.

- [ ] **Step 3: Create the nav component**

Create `app/components/admin/nav_component.rb`:

```ruby
module Admin
  class NavComponent < ViewComponent::Base
    def initialize(current_path:)
      @current_path = current_path
    end

    def link_classes(active)
      base = "px-3 py-2 rounded text-sm font-medium"
      active_classes = "bg-slate-700 text-white"
      inactive_classes = "text-slate-300 hover:bg-slate-800 hover:text-white"
      "#{base} #{active ? active_classes : inactive_classes}"
    end

    def campaigns_active?
      @current_path == "/campaigns" || @current_path.start_with?("/campaigns/")
    end

    def diagnostics_active?
      @current_path.start_with?("/diagnostics")
    end
  end
end
```

Create `app/components/admin/nav_component.html.erb`:

```erb
<nav class="bg-slate-900 border-b border-slate-800">
  <div class="max-w-5xl mx-auto px-4 py-3 flex items-center gap-2">
    <span class="text-slate-100 font-semibold mr-4">Gygaxagain admin</span>
    <%= link_to "Campaigns", "/campaigns",
                class: link_classes(campaigns_active?),
                **(campaigns_active? ? { aria: { current: "page" } } : {}) %>
    <%= link_to "Diagnostics → LLM", "/diagnostics/llm",
                class: link_classes(diagnostics_active?),
                **(diagnostics_active? ? { aria: { current: "page" } } : {}) %>
  </div>
</nav>
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/admin/nav_component_spec.rb`
Expected: all examples pass.

- [ ] **Step 5: Create the admin layout file**

Create `app/views/layouts/admin.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "Gygaxagain admin" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_include_tag "application", "data-turbo-track": "reload", type: "module" %>
  </head>

  <body>
    <% if flash[:notice].present? %>
      <div class="fixed top-4 right-4 z-50 rounded bg-emerald-800 px-4 py-2 text-sm text-emerald-100 shadow-lg">
        <%= flash[:notice] %>
      </div>
    <% end %>
    <% if flash[:alert].present? %>
      <div class="fixed top-4 right-4 z-50 rounded bg-red-800 px-4 py-2 text-sm text-red-100 shadow-lg">
        <%= flash[:alert] %>
      </div>
    <% end %>

    <div class="min-h-screen bg-slate-950 text-slate-100">
      <%= render Admin::NavComponent.new(current_path: request.path) %>
      <main class="max-w-5xl mx-auto px-4 py-6">
        <%= yield %>
      </main>
    </div>
  </body>
</html>
```

- [ ] **Step 6: Create `Admin::ApplicationController`**

Create `app/controllers/admin/application_controller.rb`:

```ruby
module Admin
  class ApplicationController < ::ApplicationController
    layout "admin"
  end
end
```

- [ ] **Step 7: Migrate `Admin::CampaignsController` to inherit from it**

Edit `app/controllers/admin/campaigns_controller.rb`. Change the class declaration from:

```ruby
module Admin
  class CampaignsController < ::ApplicationController
```

to:

```ruby
module Admin
  class CampaignsController < Admin::ApplicationController
```

(Leave the rest of the file unchanged.)

- [ ] **Step 8: Verify Phase 3 admin component templates render cleanly inside the new layout**

Inspect `app/components/admin/campaigns/index_component.html.erb` and `app/components/admin/campaigns/form_component.html.erb`. Confirm they render content fragments only — no `<html>` / `<body>` / full-page chrome. Phase 3 components are already proper ViewComponents, so this should be a no-op.

- [ ] **Step 9: Run the full test suite**

Run: `bundle exec rspec`
Expected: all existing specs pass, plus the new nav component spec. The Phase 3 admin request specs (`spec/requests/admin/campaigns_spec.rb`) should still pass — adding a layout wraps the response HTML but doesn't change status codes, redirects, or flash behavior.

If any Phase 3 admin request spec fails because it asserts on raw HTML structure that changed (e.g., the layout adds a header), update the assertion to be resilient (assert on text content / presence of specific elements rather than exact HTML structure).

- [ ] **Step 10: Commit**

```bash
git add app/controllers/admin app/views/layouts/admin.html.erb app/components/admin/nav_component.rb app/components/admin/nav_component.html.erb spec/components/admin/nav_component_spec.rb
git commit -m "Introduce admin layout + nav + Admin::ApplicationController (Phase 4.10)"
```

---

## Task 11: Diagnostics route + controller + components

**Files:**
- Modify: `config/routes/admin.rb`
- Create: `app/controllers/admin/diagnostics/llm_controller.rb`
- Create: `app/components/admin/diagnostics/llm/show_component.rb`
- Create: `app/components/admin/diagnostics/llm/show_component.html.erb`
- Create: `app/components/admin/diagnostics/llm/result_panel_component.rb`
- Create: `app/components/admin/diagnostics/llm/result_panel_component.html.erb`
- Create: `spec/components/admin/diagnostics/llm/show_component_spec.rb`
- Create: `spec/components/admin/diagnostics/llm/result_panel_component_spec.rb`

- [ ] **Step 1: Add the diagnostics namespace to admin routes**

Edit `config/routes/admin.rb`. Replace the entire file contents with:

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

- [ ] **Step 2: Verify routes are generated correctly**

Run: `bin/rails routes -c admin/diagnostics`
Expected output includes:

```
admin_diagnostics_llm GET    /diagnostics/llm  admin/diagnostics/llm#show
                     POST   /diagnostics/llm  admin/diagnostics/llm#create
```

- [ ] **Step 3: Write the failing result panel component spec**

Create `spec/components/admin/diagnostics/llm/result_panel_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Diagnostics::Llm::ResultPanelComponent, type: :component do
  describe "successful call" do
    let(:call) { create(:llm_call) }

    it "renders the response text" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("Hi there!")
    end

    it "renders the model and tokens" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("claude-sonnet-4-6")
      expect(page).to have_content("100")  # input_tokens
      expect(page).to have_content("50")   # output_tokens
    end

    it "renders the cost in dollars" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("$1.05")
    end

    it "renders the provider_request_id" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content(call.provider_request_id)
    end

    it "carries data-llm-call-id on its root element" do
      render_inline(described_class.new(call: call))
      expect(page).to have_css("[data-llm-call-id='#{call.id}']")
    end

    it "renders pretty-printed JSON for prompt and response payloads" do
      render_inline(described_class.new(call: call))
      expect(page).to have_css("details", count: 2)
      expect(page).to have_content("\"messages\"")
      expect(page).to have_content("\"content\"")
    end
  end

  describe "errored call" do
    let(:call) { create(:llm_call, :errored) }

    it "renders an error banner" do
      render_inline(described_class.new(call: call))
      expect(page).to have_content("Internal server error")
    end

    it "still carries data-llm-call-id" do
      render_inline(described_class.new(call: call))
      expect(page).to have_css("[data-llm-call-id='#{call.id}']")
    end
  end
end
```

- [ ] **Step 4: Run the result panel spec to verify it fails**

Run: `bundle exec rspec spec/components/admin/diagnostics/llm/result_panel_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Admin::Diagnostics::Llm::ResultPanelComponent`.

- [ ] **Step 5: Create the result panel component**

Create `app/components/admin/diagnostics/llm/result_panel_component.rb`:

```ruby
module Admin
  module Diagnostics
    module Llm
      class ResultPanelComponent < ViewComponent::Base
        def initialize(call:)
          @call = call
        end

        attr_reader :call

        def cost_dollars_formatted
          helpers.number_to_currency(call.total_cost_dollars)
        end

        def pretty(payload)
          JSON.pretty_generate(payload)
        end
      end
    end
  end
end
```

Create `app/components/admin/diagnostics/llm/result_panel_component.html.erb`:

```erb
<section data-llm-call-id="<%= call.id %>" class="rounded-lg border border-slate-800 bg-slate-900 p-4 mb-6">
  <% if call.successful? %>
    <div class="rounded bg-emerald-900/40 border border-emerald-700 px-3 py-2 mb-3 text-sm text-emerald-100">
      Success
    </div>
  <% else %>
    <div class="rounded bg-red-900/40 border border-red-700 px-3 py-2 mb-3 text-sm text-red-100">
      Error: <%= call.error_message %>
    </div>
  <% end %>

  <% if call.successful? && call.text.present? %>
    <pre class="whitespace-pre-wrap rounded bg-slate-950 p-3 text-sm text-slate-100 mb-3"><%= call.text %></pre>
  <% end %>

  <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-sm text-slate-200 mb-3">
    <dt class="text-slate-400">Model</dt>            <dd><%= call.model %></dd>
    <dt class="text-slate-400">Purpose</dt>          <dd><%= call.purpose %></dd>
    <dt class="text-slate-400">Input tokens</dt>     <dd><%= call.input_tokens %></dd>
    <dt class="text-slate-400">Output tokens</dt>    <dd><%= call.output_tokens %></dd>
    <dt class="text-slate-400">Cache creation</dt>   <dd><%= call.cache_creation_tokens %></dd>
    <dt class="text-slate-400">Cache read</dt>       <dd><%= call.cache_read_tokens %></dd>
    <dt class="text-slate-400">Cost</dt>             <dd><%= cost_dollars_formatted %></dd>
    <dt class="text-slate-400">Latency</dt>          <dd><%= call.latency_ms %> ms</dd>
    <dt class="text-slate-400">Request ID</dt>       <dd><code class="text-xs"><%= call.provider_request_id || "—" %></code></dd>
  </dl>

  <details class="mb-2">
    <summary class="cursor-pointer text-sm text-slate-400">prompt_payload</summary>
    <pre class="mt-2 rounded bg-slate-950 p-3 text-xs overflow-x-auto"><%= pretty(call.prompt_payload) %></pre>
  </details>

  <details>
    <summary class="cursor-pointer text-sm text-slate-400">response_payload</summary>
    <pre class="mt-2 rounded bg-slate-950 p-3 text-xs overflow-x-auto"><%= pretty(call.response_payload) %></pre>
  </details>
</section>
```

- [ ] **Step 6: Run the result panel spec to verify it passes**

Run: `bundle exec rspec spec/components/admin/diagnostics/llm/result_panel_component_spec.rb`
Expected: all examples pass.

- [ ] **Step 7: Write the failing show component spec**

Create `spec/components/admin/diagnostics/llm/show_component_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Admin::Diagnostics::Llm::ShowComponent, type: :component do
  let(:form) { Llm::DiagnosticsForm.new(model: "claude-sonnet-4-6") }

  it "renders the form with prompt, system_prompt, and model fields" do
    render_inline(described_class.new(form: form, last_call: nil))

    expect(page).to have_field("llm_diagnostics_form[prompt]")
    expect(page).to have_field("llm_diagnostics_form[system_prompt]")
    expect(page).to have_select("llm_diagnostics_form[model]")
  end

  it "populates the model dropdown from Llm::Pricing.known_models" do
    render_inline(described_class.new(form: form, last_call: nil))
    Llm::Pricing.known_models.each do |model|
      expect(page).to have_css("option[value='#{model}']")
    end
  end

  it "renders no result panel when last_call is nil" do
    render_inline(described_class.new(form: form, last_call: nil))
    expect(page).not_to have_css("[data-llm-call-id]")
  end

  it "renders a result panel when last_call is provided" do
    call = create(:llm_call)
    render_inline(described_class.new(form: form, last_call: call))
    expect(page).to have_css("[data-llm-call-id='#{call.id}']")
  end

  it "renders form errors when the form is invalid" do
    invalid_form = Llm::DiagnosticsForm.new(prompt: "", model: "claude-sonnet-4-6")
    invalid_form.valid?
    render_inline(described_class.new(form: invalid_form, last_call: nil))
    expect(page).to have_content(/can't be blank/i)
  end
end
```

- [ ] **Step 8: Run the show spec to verify it fails**

Run: `bundle exec rspec spec/components/admin/diagnostics/llm/show_component_spec.rb`
Expected: failure with `NameError: uninitialized constant Admin::Diagnostics::Llm::ShowComponent`.

- [ ] **Step 9: Create the show component**

Create `app/components/admin/diagnostics/llm/show_component.rb`:

```ruby
module Admin
  module Diagnostics
    module Llm
      class ShowComponent < ViewComponent::Base
        def initialize(form:, last_call:)
          @form      = form
          @last_call = last_call
        end

        attr_reader :form, :last_call

        def model_options
          ::Llm::Pricing.known_models
        end
      end
    end
  end
end
```

Create `app/components/admin/diagnostics/llm/show_component.html.erb`:

```erb
<div>
  <h1 class="text-2xl font-semibold text-slate-100 mb-4">LLM diagnostics</h1>

  <% if last_call.present? %>
    <%= render Admin::Diagnostics::Llm::ResultPanelComponent.new(call: last_call) %>
  <% end %>

  <%= form_with model: form, url: helpers.admin_diagnostics_llm_path, method: :post,
                local: true,
                class: "rounded-lg border border-slate-800 bg-slate-900 p-4 space-y-4" do |f| %>
    <% if form.errors.any? %>
      <div class="rounded bg-red-900/40 border border-red-700 px-3 py-2 text-sm text-red-100">
        <ul class="list-disc list-inside">
          <% form.errors.full_messages.each do |msg| %>
            <li><%= msg %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div>
      <%= f.label :prompt, class: "block text-sm font-medium text-slate-200 mb-1" %>
      <%= f.text_area :prompt, rows: 6,
                      class: "w-full rounded bg-slate-950 border border-slate-700 text-slate-100 p-2 text-sm font-mono" %>
    </div>

    <div>
      <%= f.label :system_prompt, "System prompt (optional)",
                  class: "block text-sm font-medium text-slate-200 mb-1" %>
      <%= f.text_area :system_prompt, rows: 3,
                      class: "w-full rounded bg-slate-950 border border-slate-700 text-slate-100 p-2 text-sm font-mono" %>
    </div>

    <div>
      <%= f.label :model, class: "block text-sm font-medium text-slate-200 mb-1" %>
      <%= f.select :model, model_options,
                   {},
                   class: "rounded bg-slate-950 border border-slate-700 text-slate-100 p-2 text-sm" %>
    </div>

    <div>
      <%= f.submit "Send",
                   class: "rounded bg-emerald-700 hover:bg-emerald-600 text-white text-sm font-medium px-4 py-2" %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 10: Create the diagnostics controller**

Create `app/controllers/admin/diagnostics/llm_controller.rb`:

```ruby
module Admin
  module Diagnostics
    class LlmController < Admin::ApplicationController
      def show
        form = ::Llm::DiagnosticsForm.new(model: default_model)
        last_call = load_last_call(params[:call_id])
        render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: last_call)
      end

      def create
        form = ::Llm::DiagnosticsForm.new(form_params)

        unless form.valid?
          render Admin::Diagnostics::Llm::ShowComponent.new(form: form, last_call: nil),
                 status: :unprocessable_entity
          return
        end

        begin
          call = ::Llm::Call.execute(
            purpose:  :diagnostics,
            system:   form.system_prompt.presence,
            messages: [ { role: "user", content: form.prompt } ],
            model:    form.model,
            user:     current_user
          )
          redirect_to admin_diagnostics_llm_path(call_id: call.id)
        rescue ::Llm::ConfigError => e
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
        ::Llm::Provider::PURPOSES.fetch(:diagnostics)[:model]
      end

      def load_last_call(id)
        return nil if id.blank?
        current_user.llm_calls.find_by(id: id)
      end
    end
  end
end
```

- [ ] **Step 11: Run the show component spec to verify it passes**

Run: `bundle exec rspec spec/components/admin/diagnostics/llm/show_component_spec.rb`
Expected: all examples pass.

- [ ] **Step 12: Commit**

```bash
git add config/routes/admin.rb app/controllers/admin/diagnostics app/components/admin/diagnostics spec/components/admin/diagnostics
git commit -m "Add /diagnostics/llm route + controller + ShowComponent + ResultPanelComponent (Phase 4.11)"
```

---

## Task 12: Diagnostics request specs

**Files:**
- Create: `spec/requests/admin/diagnostics/llm_spec.rb`

This is the most behavior-critical spec in Phase 4. It exercises the full HTTP path through the diagnostics tool with WebMock-stubbed Anthropic calls.

- [ ] **Step 1: Write the request spec**

Create `spec/requests/admin/diagnostics/llm_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin::Diagnostics::Llm", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:successful_response_body) do
    {
      id: "msg_01TESTREQUESTID",
      type: "message",
      role: "assistant",
      model: "claude-sonnet-4-6",
      content: [{ type: "text", text: "Hi from the model." }],
      stop_reason: "end_turn",
      usage: { input_tokens: 12, output_tokens: 5,
               cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
    }
  end

  before do
    host! "admin.gygaxagain.com"
    ENV["ANTHROPIC_API_KEY"] = "sk-ant-test-key"
  end

  describe "GET /diagnostics/llm" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        get "/diagnostics/llm"
        expect(response).to have_http_status(:found)
      end
    end

    context "authenticated" do
      before { sign_in user }

      it "renders the form with no result panel" do
        get "/diagnostics/llm"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("LLM diagnostics")
        expect(response.body).not_to include("data-llm-call-id")
      end

      it "renders the form + result panel when ?call_id is the user's own call" do
        call = create(:llm_call, user: user)
        get "/diagnostics/llm", params: { call_id: call.id }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("data-llm-call-id=\"#{call.id}\"")
      end

      it "renders form only when ?call_id is another user's call" do
        call = create(:llm_call, user: other_user)
        get "/diagnostics/llm", params: { call_id: call.id }
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("data-llm-call-id=\"#{call.id}\"")
      end

      it "renders form only when ?call_id refers to a non-existent call" do
        get "/diagnostics/llm", params: { call_id: 999_999 }
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("data-llm-call-id")
      end
    end
  end

  describe "POST /diagnostics/llm" do
    context "unauthenticated" do
      it "redirects to sign-in" do
        post "/diagnostics/llm", params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        expect(response).to have_http_status(:found)
      end
    end

    context "authenticated, valid form, successful API call" do
      before do
        sign_in user
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 200, body: successful_response_body.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "persists an LlmCall row" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        }.to change(LlmCall, :count).by(1)
      end

      it "associates the row with current_user and no campaign" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        call = LlmCall.last
        expect(call.user).to eq(user)
        expect(call.campaign).to be_nil
        expect(call.purpose).to eq("diagnostics")
      end

      it "redirects to ?call_id=N" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        call = LlmCall.last
        expect(response).to redirect_to(admin_diagnostics_llm_path(call_id: call.id))
      end

      it "passes a non-blank system prompt to the API" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: {
               prompt: "Hi", system_prompt: "You are a bard.", model: "claude-sonnet-4-6"
             } }
        expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
          .with { |req| JSON.parse(req.body)["system"] == "You are a bard." }
      end

      it "omits system from the API request when blank" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: {
               prompt: "Hi", system_prompt: "", model: "claude-sonnet-4-6"
             } }
        expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
          .with { |req| !JSON.parse(req.body).key?("system") }
      end
    end

    context "authenticated, invalid form" do
      before { sign_in user }

      it "returns 422 with form errors" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "", model: "claude-sonnet-4-6" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
      end

      it "does not persist a row" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "", model: "claude-sonnet-4-6" } }
        }.not_to change(LlmCall, :count)
      end
    end

    context "authenticated, API returns 500" do
      before do
        sign_in user
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(status: 500, body: { error: { message: "boom" } }.to_json)
      end

      it "still persists an LlmCall row with error info" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        }.to change(LlmCall, :count).by(1)

        call = LlmCall.last
        expect(call.total_cost_cents).to eq(0)
        expect(call.input_tokens).to eq(0)
        expect(call).not_to be_successful
      end

      it "redirects to ?call_id=N (so the user can see the error)" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        call = LlmCall.last
        expect(response).to redirect_to(admin_diagnostics_llm_path(call_id: call.id))
      end
    end

    context "authenticated, ANTHROPIC_API_KEY unset" do
      before do
        sign_in user
        ENV.delete("ANTHROPIC_API_KEY")
      end

      it "returns 503 with a flash alert" do
        post "/diagnostics/llm",
             params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to match(/LLM configuration error/i)
      end

      it "does not persist a row" do
        expect {
          post "/diagnostics/llm",
               params: { llm_diagnostics_form: { prompt: "Hi", model: "claude-sonnet-4-6" } }
        }.not_to change(LlmCall, :count)
      end
    end
  end
end
```

The `sign_in user` helper assumes Devise's request-spec helpers are wired in `rails_helper.rb` (Phase 2 set this up). If `sign_in` is undefined, look for the existing pattern in `spec/requests/admin/campaigns_spec.rb` and copy whatever sign-in mechanism that file uses.

The `host! "admin.gygaxagain.com"` matches Phase 3's pattern for hitting admin-subdomain routes from request specs.

- [ ] **Step 2: Run the request spec to verify all examples pass**

Run: `bundle exec rspec spec/requests/admin/diagnostics/llm_spec.rb`
Expected: all examples pass.

If a spec fails because Devise's `sign_in` helper isn't loaded, add `config.include Devise::Test::IntegrationHelpers, type: :request` to `RSpec.configure` in `spec/rails_helper.rb` (or copy the exact pattern from `spec/requests/admin/campaigns_spec.rb`).

- [ ] **Step 3: Commit**

```bash
git add spec/requests/admin/diagnostics
git commit -m "Add request specs for /diagnostics/llm covering auth + success + error + config (Phase 4.12)"
```

---

## Task 13: `.env.example` + README

**Files:**
- Create or modify: `.env.example`
- Modify: `README.md`

- [ ] **Step 1: Add `ANTHROPIC_API_KEY` to .env.example**

Check whether `.env.example` exists at the repo root. If yes, edit it; if no, create it.

If creating, the file should at minimum contain:

```
# Anthropic API key for the Llm::Providers::Anthropic adapter.
# In dev: copy this to .env (gitignored) and fill in your real key.
# In prod: set via heroku config:set ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_API_KEY=sk-ant-...
```

If editing, append the same three lines to the bottom of the existing file.

- [ ] **Step 2: Add an Operations / LLM diagnostics section to README**

Edit `README.md`. After the existing "Authentication" / "Campaigns" sections (whichever is last), add:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add .env.example README.md
git commit -m "Document ANTHROPIC_API_KEY env var + LLM diagnostics tool in README (Phase 4.13)"
```

---

## Task 14: Lint + full test pass + deploy

**Files:** none (verification + deploy only).

- [ ] **Step 1: Run RuboCop and resolve any new offenses**

Run: `bundle exec rubocop`
Expected: clean. If there are auto-fixable offenses in new files, run `bundle exec rubocop -a` and re-verify with `bundle exec rubocop`.

If non-auto-fixable offenses exist, fix them by hand and commit:

```bash
git add -u
git commit -m "RuboCop fixes for Phase 4 (Phase 4.14)"
```

- [ ] **Step 2: Run erb_lint and resolve any new offenses**

Run: `bundle exec erb_lint --lint-all`
Expected: clean. Auto-fix where safe with `bundle exec erb_lint --lint-all -a` and re-verify.

- [ ] **Step 3: Run Brakeman**

Run: `bundle exec brakeman -q`
Expected: no new warnings. The diagnostics controller's `params.require(:llm_diagnostics_form).permit(...)` should not trigger mass-assignment warnings; the redirect with `call_id:` interpolated from `LlmCall.id` (an integer) is safe.

- [ ] **Step 4: Run the full test suite**

Run: `bundle exec rspec`
Expected: every spec passes. WebMock should report no real-network attempts.

- [ ] **Step 5: Set the production API key on Heroku**

Run: `heroku config:set ANTHROPIC_API_KEY=sk-ant-<real-key>`
Expected: `Setting ANTHROPIC_API_KEY and restarting...` followed by a successful restart.

(This must be done **before** the deploy so the diagnostics tool works on first hit.)

- [ ] **Step 6: Deploy**

Run: `git push heroku main`
Expected: build completes, release phase runs `db:migrate` (which applies `CreateLlmCalls`), Procfile boots web dyno.

- [ ] **Step 7: Verify in production**

1. Sign in at `https://gygaxagain.com/users/sign_in`.
2. Navigate to `https://admin.gygaxagain.com/diagnostics/llm`.
3. Submit a short prompt (e.g., "Say hi in one word").
4. Confirm the response renders, the result panel shows tokens + cost + latency + request_id.
5. Run `heroku run rails console` and inspect: `LlmCall.last`. Confirm `prompt_payload` and `response_payload` are populated.

If the production submit fails with an `Llm::ConfigError`, the API key isn't set; re-run Step 5.

- [ ] **Step 8: Close the issue**

Update `#5` with links to the spec and plan; close after verifying production.

---

## Definition of done

- All Phase 4 acceptance criteria from [the spec](../specs/2026-05-14-v2-phase-4-llm-provider-and-anthropic-adapter-design.md) verified passing.
- `bundle exec rspec` clean.
- `bundle exec rubocop` + `bundle exec erb_lint --lint-all` + `bundle exec brakeman -q` clean.
- Production deploy verified: a real diagnostics call writes a real `llm_calls` row.
- GitHub issue [#5](https://github.com/barriault/gygaxagain/issues/5) closed.
