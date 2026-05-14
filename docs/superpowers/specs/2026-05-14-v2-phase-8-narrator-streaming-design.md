# v2 Phase 8 — Narrator integration + streaming

Date: 2026-05-14
Status: Design spec. Drives the writing-plans pass for Phase 8.
Issue: [#9](https://github.com/barriault/gygaxagain/issues/9)
Parent roadmap: [`2026-05-13-v2-phase-0-roadmap-design.md`](2026-05-13-v2-phase-0-roadmap-design.md)
Prior phase: [`2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md`](2026-05-14-v2-phase-7-dice-and-mythic-oracle-design.md)
v1 lineage: `dm/agents/narrator/system-prompt.md` and the bookkeeper subagent prompts at the `v1-final-poc` tag.

## Scope

The big one. v2 turns playable. Player clicks into a scene, types "I push open the door" → narration response streams in token-by-token; an `llm_calls` row captures the full prompt/response/usage; asymmetry is guaranteed structurally because the prompt is built from `Player::*ViewModel` only. On scene close, an audit job reviews the narration for narrator-discipline issues and writes a structured result to a new `scene_audits` table (reachable from the campaign).

Five concrete deliverables:

- **`Narrator::PromptBuilder`** — pure function: `(scene, player_action_text) → Narrator::Prompt`. Reads only `Player::*ViewModel` instances. Asymmetry-tested via `not_to leak_secrets_of`. Exposes cache breakpoints on the system blocks that are stable across calls.
- **`Llm::Providers::Anthropic#call_streaming`** — extends Phase 4's adapter with a streaming method that yields token chunks, accumulates the full transcript, captures usage / cache / latency / request_id at completion, and translates Phase 4's deferred `cache_breakpoints:` into first-class adapter behavior.
- **Player input + `player_action` event kind** — fifth event kind. Player submits text; controller creates a `player_action` row + an empty `narration` row in the same response, then enqueues `NarrationJob`.
- **`NarrationJob` (Solid Queue)** — orchestrates the streaming call. Builds prompt, opens streaming Anthropic call, broadcasts batched chunks to the per-`(scene, user)` Turbo Stream, finalizes the narration event payload + writes the `llm_calls` row at completion, marks errors on failure.
- **Scene-close + `SceneAuditJob`** — admin "End scene" button sets `closed_at`, enqueues `SceneAuditJob`. The job runs one synchronous `:bookkeeper_audit` call with structured JSON output and persists a `SceneAudit` row.

## Dependencies

Phase 4 ([#5](https://github.com/barriault/gygaxagain/issues/5)) complete:
- `Llm::Provider`, `Llm::Providers::Anthropic`, `Llm::Call`, `Llm::Pricing`, `LlmCall` model, `Llm::Result` Data class, `WebMock` test infrastructure.
- The `:diagnostics`, `:narration`, `:intake_long_context` purposes are registered. Phase 8 adds `:bookkeeper_audit`.

Phase 5 ([#6](https://github.com/barriault/gygaxagain/issues/6)) complete:
- `Faction`/`FactionSecret`, `Npc`/`NpcSecret`, `Scene`, `Event`.
- `Player::FactionViewModel`, `Player::NpcViewModel`; `Narrator::FactionViewModel`, `Narrator::NpcViewModel`; `ApplicationViewModel` with the `expose` DSL.
- `leak_secrets_of` matcher accepting both ViewModel (`to_h`) and String subjects. The matcher's vacuous-pass guard from Phase 5.16 is in place.

Phase 6 ([#7](https://github.com/barriault/gygaxagain/issues/7)) complete:
- `Play::Scenes::PlayComponent`, `Play::Scenes::LogComponent` (with the `<turbo-frame>` wrapper from Phase 7), `Play::Events::Component` registry dispatcher, the four `Play::Events::*Component` classes.
- `Admin::Campaigns::ShowComponent`, `Admin::Scenes::*` CRUD, `Admin::ScenesController` with `move_up`/`move_down`.
- `Play::Scenes::InputDockComponent` (introduced in Phase 7) with the dice + oracle cards.

Phase 7 ([#8](https://github.com/barriault/gygaxagain/issues/8)) complete:
- Turbo Streams + ActionCable infrastructure validated by the dice/oracle controllers.
- `Dice::Roll`, `Mythic::Oracle` services. `Campaign#chaos_factor`. The `events.payload` jsonb column carrying typed event content.
- `Stimulus` controllers `dice-form`, `oracle-form`, `flash`. Selenium driver wired for system specs.
- `Admin::ChaosFactorsController` pattern for singleton-resource admin actions.

Phase 8 has no new external gem dependencies. The `anthropic` SDK already supports streaming; `solid_queue`, `solid_cable`, and `turbo-rails` are already in the Gemfile.

## Acceptance criteria

Verbatim from the GitHub issue:

- Player can submit an action; narration response streams in token-by-token.
- Full prompt and full response logged in `llm_calls.prompt_payload` / `response_payload`.
- The session-end audit job runs at session close, writes a structured audit result to the campaign.
- Asymmetry tests: every prompt built by `Narrator::PromptBuilder` is verified to not leak hidden state (via the `not_to_leak` matcher from Phase 5).

## Architectural commitments inherited from prior phases

Phase 0 / 4 / 5 / 6 / 7 already lock the relevant decisions. Phase 8 applies them; it does not re-litigate them.

- **Asymmetry-by-context-construction.** The narrator's prompt is built from `Player::*ViewModel` only. Hidden state is unreachable from the call graph, not merely "not supposed to be used."
- **`Llm::Provider` is the abstraction.** Per-provider adapters are thin and owned in the codebase. The streaming method is added to the existing `Llm::Providers::Anthropic`; the `Llm::Provider.for(:purpose)` registry grows a `:bookkeeper_audit` entry.
- **`llm_calls` writes are the single source of truth for cost + audit.** Streaming calls write a row at stream-completion, not on every chunk. Failed streams write a row with `error` populated and whatever partial usage was captured. Audit calls write an `llm_calls` row distinct from the `scene_audits` row that consumes it.
- **ViewComponent + Hotwire.** All new view composition through ViewComponents. All client behavior in Stimulus controllers. No inline JavaScript; no logic in `application.js` beyond controller registration.
- **Subdomain split.** Player narration UI and controllers under `Play::`. Admin scene-close + audit UI under `Admin::`. No cross-namespace component imports.
- **Default-deny auth.** All new controllers inherit `before_action :authenticate_user!`. Tenant scoping via `current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])`. Cross-user access returns 404.
- **Asymmetry test surface extends to prompt strings.** Phase 5's `leak_secrets_of` already accepts String subjects. Phase 8 uses it on the rendered prompt produced by `Narrator::PromptBuilder`.

## Open decisions resolved in this spec

### Session model: `closed_at` on Scene; new `scene_audits` table

**Decision:** Add `closed_at :datetime, null: true` to `scenes`. Add a `scene_audits` table (one row per closed scene). `Campaign has_many :scene_audits, through: :scenes` so the Phase 0 acceptance criterion's "writes a structured audit result to the campaign" is satisfied via the join.

Alternatives considered:

- **A `Session` model.** Sessions would `has_many :scenes`. More structure, more migration work, and Phase 0's playing-MVP scope doesn't yet have a concrete "session" notion (it talks about per-scene play). Promote to a real model when per-session concepts (rest mechanics, session XP, end-of-session debrief) actually arrive.
- **Defer the audit entirely.** Violates the Phase 0 acceptance criterion explicitly listed for Phase 8.

The `closed_at` column is null by default; existing scenes are unaffected. A scene may be re-opened (admin clears `closed_at`) but doing so does NOT delete the existing audit; closing again creates a second audit only after re-closure (Phase 8 limits it to one audit per closed scene at a time via a unique index — see schema below). Re-open semantics get clarified when the user actually wants to re-open a closed scene; for Phase 8 the button is disabled once `closed_at` is set.

### Player input event kind: new `player_action`

**Decision:** Extend `Event::KINDS` to `%w[narration player_action dice_roll oracle_query scene_transition]`. Each `narration` event payload links back to its triggering `player_action` event via `payload["player_action_event_id"]`; symmetrically, the `player_action` payload carries `payload["narration_event_id"]` once the narration row is created (which happens in the same controller action, so both ids are known at insert time).

`player_action` payload schema:
```json
{
  "text": "I push open the door",
  "narration_event_id": 4321
}
```

`narration` payload schema (extended from Phase 6's bare `{ "text": "..." }`):
```json
{
  "text": "The door swings...",
  "status": "streaming",
  "player_action_event_id": 4320,
  "llm_call_id": null
}
```

`status` values: `"streaming"`, `"complete"`, `"errored"`. `llm_call_id` is null while streaming, set on completion.

Alternatives considered:

- **Embed both turns in a single `narration` event.** Conflates two distinct turns; harder to render alternating chat bubbles; harder to extend (later phases want oracle results between action and narration); harder to audit (the bookkeeper job iterates events per-turn).
- **`narration` events with `payload.author = "player"`.** Schema-cheap but the `kind` enum lies about what each row represents, and the `Play::Events::Component` registry dispatcher loses its 1:1 kind→component mapping.

### Player input UX: full-width textarea above the dice/oracle dock

**Decision:** A new `Play::Narration::FormComponent` renders **above** Phase 7's `Play::Scenes::InputDockComponent`. The form is a single full-width textarea (3-line min-height, autosizing up to ~10 lines) with a Submit button labeled "Narrate" (or similar), plus a small helper line ("⌘+Enter to send").

Alternatives considered:

- **Third card alongside Dice + Oracle (3-column grid).** Squeezes everything; narration loses primacy; on narrow viewports the form gets crushed.
- **Replace the dock entirely with vertical stack** (narration big on top; dice + oracle as compact chip rows beneath). Most opinionated; reasonable but more visual churn for a Phase 8 scope. Defer to a polish phase if play feel demands it.

The chosen layout reflects the mental model: narration is the primary play action; dice and oracle are accessories that often follow a narration turn.

### Streaming wire: per-`(scene, user)` Turbo Stream + chunk batching

**Decision:** Use `Turbo::StreamsChannel` to broadcast `turbo_stream.replace` actions targeting the narration event's `dom_id`. Stream identifier is `[scene, scene.campaign.user]` so each user's narration is isolated even if multi-user-per-campaign ever lands (it won't in v2 alpha, but the stream key shape costs nothing now and forecloses a future incident).

Chunk batching: the `NarrationJob` accumulates SDK delta chunks into a buffer and flushes to the broadcast channel when **either** `(now - last_flush_at) > 80ms` **or** the buffer has accumulated `>= 25` token-chunk-events. The final `message_stop` always triggers a final flush with the complete text and `status: "complete"`.

Without batching, broadcasting on every token would issue one ActionCable frame per chunk — pathological for the browser's render loop, even on localhost. 80ms / 25-chunks gives ~12 broadcasts/sec at typical Anthropic streaming rates, which renders smoothly.

Alternatives considered:

- **Per-narration-event stream identifier.** Slightly tighter scope, but `(scene, user)` lets us also stream "narrator is thinking" placeholders before the event row exists if we ever want that. Negligible cost difference.
- **Naive per-chunk broadcast.** Simple but spam.
- **Polling instead of streams.** Rejected at architecture phase. ActionCable is already wired (Phase 7).

### Bookkeeper audit: one structured-output LLM call, persisted to `scene_audits`

**Decision:** A single LLM call with `purpose: :bookkeeper_audit` produces a structured JSON verdict + per-criterion notes. Persisted to a new `scene_audits` row (1:1 with Scene; references its `LlmCall`). The audit prompt asks the model to assess narrator discipline against ~4 criteria:

1. **Player agency.** Did the narrator give the player meaningful choices, or did the narrator dictate player actions?
2. **Follow-through.** Did the narrator pick up on player declarations and develop them, or drop them?
3. **Over-narration of intent.** Did the narrator describe what the player thinks/feels, or stick to describing the world?
4. **Mechanical handoff.** When uncertainty arose in the fiction, did the narrator suggest a dice roll or oracle question, or just resolve it narratively?

Response shape (model-enforced via the audit system prompt):

```json
{
  "verdict": "pass" | "concerns" | "fail",
  "criteria": [
    { "name": "player_agency", "status": "pass" | "concerns" | "fail", "note": "..." },
    { "name": "follow_through", "status": "...", "note": "..." },
    { "name": "over_narration_of_intent", "status": "...", "note": "..." },
    { "name": "mechanical_handoff", "status": "...", "note": "..." }
  ],
  "summary": "..."
}
```

The audit input is built by `Narrator::AuditPromptBuilder`, which takes the **narrator-side** view of the scene (it can see everything since the audit is admin-side and benefits from comparing against secrets if any leak surfaces — but Phase 8 sticks to player-visible history because secrets shouldn't have ever entered narration anyway, so the audit's job is to find narrator-discipline issues, not asymmetry leaks). The builder iterates `scene.events` in `occurred_at` order and renders each one as a labeled block:

```
[player_action @ 14:32:01] I try to convince the bartender we're trustworthy.
[narration @ 14:32:08] The bartender narrows his eyes...
[oracle_query @ 14:33:02] Q: Does the bartender believe us? (50_50, chaos 5) → No
[narration @ 14:33:10] His expression hardens. ...
```

Alternatives considered:

- **Mechanical rule-based audit (regex / heuristics).** Cheap but trivial; doesn't capture narrator-discipline meaningfully.
- **Defer the audit.** Violates the explicit Phase 0 acceptance criterion.
- **Streaming audit response.** No UX benefit for an admin diagnostic. Synchronous Sonnet call returns in ~2-5 seconds; that's faster than the page-refresh loop.

JSON parse failure handling: if the model's response isn't valid JSON for the expected schema, persist a `SceneAudit` with `verdict: "fail"`, `result: { "error" => "audit_parse_failed", "raw" => <response.text> }`. The `LlmCall` row is preserved so the failure is debuggable.

### Cache breakpoints: first-class adapter parameter

**Decision:** Phase 4 deferred this; Phase 8 implements it. The `Llm::Providers::Anthropic#call` and `#call_streaming` methods grow a `cache_breakpoints: []` keyword parameter. Each entry is an integer index into the `system:` array. Before sending, the adapter mutates the indicated `system` blocks to include `cache_control: { type: "ephemeral" }`. (TTL defaults to 5m; passing `cache_breakpoints: [{index: 0, ttl: :ephemeral_1h}]` is supported via a sibling shape — see implementation below.)

The `system:` parameter, which Phase 4 accepted as a string, now also accepts an Array of typed text blocks:

```ruby
system: [
  { type: "text", text: "<rules>" },
  { type: "text", text: "<campaign + roster>" },
  { type: "text", text: "<scene context>" }
]
```

When a String is passed, the adapter wraps it as `[{ type: "text", text: <string> }]` for backward compatibility with Phase 4 callers (the diagnostics tool, which never asks for cache breakpoints).

`Llm::Pricing.cost_cents` already supports `:ephemeral_5m` and `:ephemeral_1h`. `Llm::Call.execute` and `Llm::Call.execute_streaming` pass the `cache_ttl` through when computing cost.

### Recent-event window in the prompt: rolling window of 30 events

**Decision:** `Narrator::PromptBuilder` includes the last 30 events (any kind) from the scene in `messages:`, ordered oldest-first. Below 30, all events are included. Above 30, the older events are summarized as `"[N earlier events truncated for context]"` at the front of the messages list.

Rationale: At alpha scale, 30 events covers a typical play turn-and-response chain comfortably, costs ~3-8K tokens depending on narration verbosity, and keeps prompt size predictable for cache effectiveness. The truncation marker invites future phases to introduce rolling summarization without changing the prompt structure.

The 30 is a constant in `Narrator::PromptBuilder` (`RECENT_EVENT_WINDOW = 30`), not config — change it in code if play feel says otherwise.

### Auto-scroll behavior: smart sticky-bottom

**Decision:** A new `scene_log_scroll_controller.js` Stimulus controller observes the log container with a `MutationObserver`. On any new child appended, it calls `scrollIntoView({ block: "end" })` IF the user was already within ~120px of the bottom before the mutation. If the user has scrolled up to read older content, the auto-scroll does NOT yank them back.

Rationale: this is the standard chat-UI pattern. Without it, streaming narration that exceeds the viewport scrolls past the visible area unread; with naive auto-scroll, scrolling up to re-read mid-stream is fight-the-page-and-lose.

### Errored narration UX: inline error message + reload-to-retry

**Decision:** When the streaming call fails (any rescued `Anthropic::Errors::Error` or transport error), the narration event payload is updated to `status: "errored"` with an `error_message` field. The `Play::Events::NarrationComponent` renders an "errored" branch: a subdued red-bordered card with the partial text (if any) and an error message ("the narrator couldn't finish — try again"). No retry button in Phase 8; the user re-submits a new player action if they want to continue.

Rationale: simpler. A retry button needs to recreate the prompt from the same `player_action` event and re-enqueue the job; that's two-screens of code for a path that won't trigger often (Anthropic 5xx rates are low). Defer to a Phase 8.x polish if observed in practice.

### Strong params

- Narration: `params.require(:narration).permit(:text)`. Empty / whitespace-only text returns 422 with the form re-rendered via Turbo Stream replace.
- Scene closure: no body params. POST creates the closure.
- Scene audit: GET with no body.

### `:bookkeeper_audit` purpose registration

**Decision:** Add `bookkeeper_audit: { provider: :anthropic, model: "claude-sonnet-4-6" }` to `Llm::Provider::PURPOSES`. Same model as narration; the audit benefits from Sonnet's structured-output reliability without needing Opus.

## Service / class design

### `Narrator::PromptBuilder`

`app/lib/narrator/prompt_builder.rb`. Pure function. Returns a `Narrator::Prompt` Data class.

```ruby
module Narrator
  Prompt = Data.define(:system, :messages, :cache_breakpoints) do
    def to_call_kwargs
      {
        system: system,
        messages: messages,
        cache_breakpoints: cache_breakpoints
      }
    end

    def to_s
      [system_text, messages_text].join("\n\n")
    end

    private

    def system_text = system.map { _1[:text] }.join("\n\n---\n\n")
    def messages_text = messages.map { "[#{_1[:role]}] #{_1[:content]}" }.join("\n\n")
  end

  class PromptBuilder
    RECENT_EVENT_WINDOW = 30

    def self.call(scene:, player_action_text:)
      new(scene: scene, player_action_text: player_action_text).call
    end

    def initialize(scene:, player_action_text:)
      @scene = scene
      @player_action_text = player_action_text.to_s
    end

    def call
      Narrator::Prompt.new(
        system: build_system_blocks,
        messages: build_messages,
        cache_breakpoints: [0, 1]
      )
    end

    # Exposed for the structural asymmetry test.
    def input_view_models
      [campaign_vm, scene_vm, *faction_vms, *npc_vms]
    end

    private

    def build_system_blocks
      [
        { type: "text", text: rules_text },
        { type: "text", text: campaign_and_roster_text },
        { type: "text", text: scene_context_text }
      ]
    end

    def build_messages
      [{ role: "user", content: @player_action_text }]
    end

    def rules_text
      Narrator::SystemPrompt.text   # constant; ~600-1000 token rules block
    end

    def campaign_and_roster_text
      <<~MD
        # Campaign

        Name: #{campaign_vm.name}
        #{campaign_vm.description}

        # Factions

        #{faction_vms.map { faction_md(_1) }.join("\n\n")}

        # NPCs

        #{npc_vms.map { npc_md(_1) }.join("\n\n")}
      MD
    end

    def scene_context_text
      <<~MD
        # Current scene

        Title: #{scene_vm.title}
        #{scene_vm.summary}

        # Recent events (oldest first)

        #{recent_events_md}
      MD
    end

    def recent_events_md
      events = recent_events_window
      lines = []
      lines << "[#{omitted_count} earlier events truncated for context]" if omitted_count.positive?
      lines.concat(events.map { event_md(_1) })
      lines.join("\n\n")
    end

    def recent_events_window
      @recent_events_window ||= scene_vm.events.last(RECENT_EVENT_WINDOW)
    end

    def omitted_count
      [scene_vm.events.size - RECENT_EVENT_WINDOW, 0].max
    end

    def event_md(event_vm)
      # event_vm is a Player::EventViewModel. See ViewModel additions below.
      "[#{event_vm.kind} @ #{event_vm.occurred_at_label}] #{event_vm.text}"
    end

    def faction_md(vm) = "## #{vm.name}\n#{vm.public_description}"
    def npc_md(vm)     = "## #{vm.name}\n#{vm.public_description}#{vm.location.present? ? " (#{vm.location})" : ""}"

    def campaign_vm
      @campaign_vm ||= Player::CampaignViewModel.new(@scene.campaign)
    end

    def scene_vm
      @scene_vm ||= Player::SceneViewModel.new(@scene)
    end

    def faction_vms
      @faction_vms ||= @scene.campaign.factions.order(:name).map { Player::FactionViewModel.new(_1) }
    end

    def npc_vms
      @npc_vms ||= @scene.campaign.npcs.order(:name).map { Player::NpcViewModel.new(_1) }
    end
  end
end
```

`Narrator::SystemPrompt` is a separate file (`app/lib/narrator/system_prompt.rb`) holding the rules text as a frozen constant. Keeping it in its own file lets the file diff show prompt changes clearly and lets the spec file load it without parsing the builder.

The asymmetry contract:

- `input_view_models` returns only `Player::*` instances. The structural test asserts every element's class name starts with `"Player::"`.
- `Player::FactionViewModel` exposes only `:id, :name, :public_description` (Phase 5). Calling `vm.secrets` raises `NoMethodError`.
- `Player::NpcViewModel` exposes only `:id, :name, :public_description, :location`.
- `Player::EventViewModel` (new in Phase 8) exposes only `:id, :kind, :occurred_at, :text`. The `text` method renders the player-visible content of each event kind:
  - `narration` → `payload["text"]` (the narration prose).
  - `player_action` → `payload["text"]` (what the player typed).
  - `dice_roll` → `"Rolled #{payload["expression"]} → #{payload["result"]}"`.
  - `oracle_query` → `"Asked: #{payload["question"]} (#{payload["likelihood"]}, chaos #{payload["chaos"]}) → #{payload["answer"]}"`.
  - `scene_transition` → `payload["reason"]`.
- `Player::SceneViewModel` (new in Phase 8) exposes only `:id, :title, :summary, :events` where `events` returns an array of `Player::EventViewModel` ordered by `occurred_at`. The VM does NOT expose `campaign` or any path to factions/NPCs — those come into the prompt through their own VMs above.
- `Player::CampaignViewModel` (new in Phase 8) exposes only `:id, :name, :description`.

**This is the load-bearing asymmetry property.** A reviewer can verify by reading the four `Player::*ViewModel` files that the call graph from `Narrator::PromptBuilder` cannot reach a `FactionSecret` or `NpcSecret`. The structural test plus the dynamic `leak_secrets_of` test together close the loop.

### `Narrator::AuditPromptBuilder`

`app/lib/narrator/audit_prompt_builder.rb`. Builds the input for the bookkeeper audit. Takes a closed `Scene`. Returns a `Narrator::Prompt`.

The system block is the audit rules text (`Narrator::AuditSystemPrompt`, a separate constant file): defines the four criteria, the JSON schema the model must produce, and the discipline of "answer per criterion with a short note grounded in specific events."

The user-message block renders the entire scene as labeled events (player_action, narration, dice_roll, oracle_query, scene_transition) in order. Uses `Narrator::SceneAuditViewModel` (new) which is narrator-side — it can see everything without restriction. The audit prompt does NOT need ViewModel restriction because the audit is admin-side and is reading already-emitted narration text (which itself was built from Player VMs and so cannot have leaked secrets). The audit's asymmetry test is therefore vacuous in practice but kept in the spec suite for symmetry.

```ruby
module Narrator
  class AuditPromptBuilder
    def self.call(scene:) = new(scene: scene).call

    def initialize(scene:)
      @scene = scene
    end

    def call
      Narrator::Prompt.new(
        system: [{ type: "text", text: Narrator::AuditSystemPrompt.text }],
        messages: [{ role: "user", content: scene_transcript }],
        cache_breakpoints: [0]   # cache the rules text
      )
    end

    private

    def scene_transcript
      vm = Narrator::SceneAuditViewModel.new(@scene)
      header = "# Scene: #{vm.title}\n\n#{vm.summary}\n\n# Events\n\n"
      header + vm.events.map { event_line(_1) }.join("\n\n")
    end

    def event_line(event_vm)
      "[#{event_vm.kind} @ #{event_vm.occurred_at_label}]\n#{event_vm.text}"
    end
  end
end
```

`Narrator::SceneAuditViewModel` exposes `:title, :summary, :events`. Its `events` method wraps each `Event` in a `Narrator::EventViewModel` analogous to the Player one but with no field restriction. (For Phase 8 the rendered text happens to be the same as Player::EventViewModel — narrator audit only consumes player-visible fields — but having the narrator-side VM exists matches the Phase 5 pattern and keeps doors open for Phase 17 "audit hardening" to surface narrator-only fields.)

### `Llm::Providers::Anthropic#call_streaming`

Extends the existing class. Method signature:

```ruby
def call_streaming(system: nil, messages:, max_tokens: 4096,
                   cache_breakpoints: [], &on_chunk)
```

`&on_chunk` is called as `on_chunk.call(text: <delta_text>)` for every `content_block_delta` event. Returns an `Llm::Result` at completion (analogous to `#call`).

Implementation outline:

```ruby
def call_streaming(system: nil, messages:, max_tokens: 4096,
                   cache_breakpoints: [], &on_chunk)
  api_key = self.class.api_key
  raise Llm::ConfigError, "Anthropic API key not configured (credentials.anthropic.api_key)" if api_key.blank?

  request_body = build_request_body(system:, messages:, max_tokens:, cache_breakpoints:)

  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  text       = +""
  request_id = nil
  usage      = nil

  begin
    self.class.sdk_client.messages.stream(**request_body) do |event|
      case event.type
      when :message_start
        request_id = event.message.id
      when :content_block_delta
        delta = event.delta.text.to_s
        text << delta
        on_chunk&.call(text: delta) if delta.present?
      when :message_delta
        # Per the SDK, message_delta carries cumulative usage at the moment
        # the message stops streaming.
        usage = event.usage if event.respond_to?(:usage) && event.usage
      when :message_stop
        # No-op; loop ends after this event.
      end
    end

    Llm::Result.new(
      text:                  text,
      input_tokens:          usage&.input_tokens.to_i,
      output_tokens:         usage&.output_tokens.to_i,
      cache_creation_tokens: cache_creation_from(usage),
      cache_read_tokens:     cache_read_from(usage),
      provider_request_id:   request_id,
      prompt_payload:        request_body.deep_stringify_keys,
      response_payload:      { "content" => [{ "type" => "text", "text" => text }],
                               "id" => request_id,
                               "usage" => usage_to_hash(usage) },
      latency_ms:            elapsed_ms(started_at),
      error:                 nil
    )
  rescue ::Anthropic::Errors::Error => e
    Llm::Result.new(
      text: text.presence,
      input_tokens: 0, output_tokens: 0,
      cache_creation_tokens: 0, cache_read_tokens: 0,
      provider_request_id: request_id,
      prompt_payload: request_body.deep_stringify_keys.merge("partial_text" => text),
      response_payload: { "error" => { "class" => e.class.name, "message" => e.message } },
      latency_ms: elapsed_ms(started_at),
      error: Llm::ProviderError.new(provider_class: e.class.name, provider_message: e.message)
    )
  end
end

private

def build_request_body(system:, messages:, max_tokens:, cache_breakpoints:)
  body = {
    model: model,
    max_tokens: max_tokens,
    messages: messages
  }
  body[:system] = normalize_system(system, cache_breakpoints) if system
  body
end

def normalize_system(system, cache_breakpoints)
  blocks = case system
           when String then [{ type: "text", text: system }]
           when Array  then system.map(&:dup)
           end
  cache_breakpoints.each do |bp|
    index, ttl = case bp
                 when Integer then [bp, :ephemeral_5m]
                 when Hash    then [bp.fetch(:index), bp.fetch(:ttl, :ephemeral_5m)]
                 end
    blocks[index][:cache_control] = { type: "ephemeral", ttl: ttl_to_anthropic(ttl) }
  end
  blocks
end

def ttl_to_anthropic(ttl)
  case ttl
  when :ephemeral_5m then "5m"
  when :ephemeral_1h then "1h"
  else raise Llm::ConfigError, "Unknown cache TTL: #{ttl.inspect}"
  end
end
```

Notes:

- The SDK's `messages.stream` block-form is the supported streaming API in `anthropic` gem 1.x. The exact SDK event class names (`event.type` / `event.delta.text` / `event.usage`) need to be verified against the locked gem version during implementation; the plan adds an explicit verification step.
- The `:bookkeeper_audit` purpose uses the synchronous `#call`, not `#call_streaming`. Streaming for a structured-output audit yields no UX benefit.
- WebMock supports chunked response bodies via `Net::HTTPResponse` shenanigans. The plan's spec writes a small stub helper for "streamed Anthropic response" that emits the right sequence of SSE events from a fixture.

### `Llm::Call.execute_streaming`

Sibling of `Llm::Call.execute`. Same persistence semantics; takes a `&on_chunk` block.

```ruby
def self.execute_streaming(purpose:, system: nil, messages:, max_tokens: 4096,
                           cache_breakpoints: [], cache_ttl: :ephemeral_5m,
                           user:, campaign: nil, scene: nil, model: nil,
                           &on_chunk)
  adapter = Llm::Provider.for(purpose)
  adapter = override_model(adapter, model) if model

  result = adapter.call_streaming(
    system: system, messages: messages, max_tokens: max_tokens,
    cache_breakpoints: cache_breakpoints, &on_chunk
  )

  cost_cents = compute_cost_cents(result, adapter.model, cache_ttl)

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

def self.compute_cost_cents(result, model, cache_ttl)
  return 0 unless result.successful?

  Llm::Pricing.cost_cents(
    usage: {
      input:          result.input_tokens,
      output:         result.output_tokens,
      cache_creation: result.cache_creation_tokens,
      cache_read:     result.cache_read_tokens
    },
    model: model,
    cache_ttl: cache_ttl
  )
end
```

### `NarrationJob`

`app/jobs/narration_job.rb`. Solid Queue.

```ruby
class NarrationJob < ApplicationJob
  queue_as :narration

  FLUSH_MS    = 80
  FLUSH_BYTES = 25   # accumulated buffer bytes between flushes

  def perform(narration_event_id)
    narration_event = Event.find(narration_event_id)
    scene           = narration_event.scene
    campaign        = scene.campaign
    user            = campaign.user
    player_action   = Event.find(narration_event.payload.fetch("player_action_event_id"))

    prompt = Narrator::PromptBuilder.call(
      scene: scene,
      player_action_text: player_action.payload.fetch("text")
    )

    buffer        = +""
    last_flush    = monotonic_ms
    accumulator   = +""

    llm_call = Llm::Call.execute_streaming(
      purpose: :narration,
      user: user, campaign: campaign, scene: scene,
      **prompt.to_call_kwargs
    ) do |text:|
      accumulator << text
      buffer      << text
      now = monotonic_ms
      if now - last_flush >= FLUSH_MS || buffer.bytesize >= FLUSH_BYTES
        flush(narration_event, accumulator, status: "streaming")
        buffer.clear
        last_flush = now
      end
    end

    if llm_call.successful?
      finalize_success(narration_event, accumulator, llm_call)
    else
      finalize_error(narration_event, accumulator, llm_call)
    end
  end

  private

  def flush(event, text, status:)
    event.with_lock do
      event.update!(payload: event.payload.merge("text" => text, "status" => status))
    end
    broadcast_replace(event)
  end

  def finalize_success(event, text, llm_call)
    event.with_lock do
      event.update!(payload: event.payload.merge(
        "text" => text, "status" => "complete", "llm_call_id" => llm_call.id
      ))
    end
    broadcast_replace(event)
  end

  def finalize_error(event, text, llm_call)
    event.with_lock do
      event.update!(payload: event.payload.merge(
        "text" => text, "status" => "errored",
        "llm_call_id" => llm_call.id,
        "error_message" => llm_call.error_message
      ))
    end
    broadcast_replace(event)
  end

  def broadcast_replace(event)
    Turbo::StreamsChannel.broadcast_replace_to(
      [event.scene, event.scene.campaign.user],
      target: ActionView::RecordIdentifier.dom_id(event),
      renderable: Play::Events::NarrationComponent.new(event: event)
    )
  end

  def monotonic_ms
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
  end
end
```

Notes:

- `with_lock` serializes payload mutations across concurrent workers (defensive; in practice one job per narration event, but Solid Queue at-least-once delivery semantics make a lock cheap insurance).
- The `Turbo::StreamsChannel.broadcast_replace_to` helper accepts a `renderable:` kwarg in turbo-rails 2.x to render a ViewComponent inline. Verify the kwarg name against the locked gem version; alternative is `partial: ..., locals: { ... }` or `html: component.render_in(view_context)`. The plan resolves the exact API.
- The `flush` writes payload to the DB AND broadcasts. If a tab reloads mid-stream, the page reads the latest persisted payload, then the broadcast subscription resumes appending to it.

### `SceneAuditJob`

`app/jobs/scene_audit_job.rb`. Solid Queue.

```ruby
class SceneAuditJob < ApplicationJob
  queue_as :default

  def perform(scene_id)
    scene = Scene.find(scene_id)
    return if scene.audit.present?  # idempotent

    prompt = Narrator::AuditPromptBuilder.call(scene: scene)

    llm_call = Llm::Call.execute(
      purpose: :bookkeeper_audit,
      user: scene.campaign.user, campaign: scene.campaign, scene: scene,
      max_tokens: 2048,
      **prompt.to_call_kwargs
    )

    parsed = parse_audit_result(llm_call)

    SceneAudit.create!(
      scene: scene,
      llm_call: llm_call,
      verdict: parsed.fetch(:verdict),
      result: parsed.fetch(:result)
    )
  end

  private

  def parse_audit_result(llm_call)
    return failed_parse(llm_call, "call_failed") unless llm_call.successful?

    raw = llm_call.text.to_s
    json = extract_json(raw)
    parsed = JSON.parse(json)

    verdict = parsed.fetch("verdict")
    raise KeyError unless %w[pass concerns fail].include?(verdict)

    { verdict: verdict, result: parsed }
  rescue JSON::ParserError, KeyError
    failed_parse(llm_call, "audit_parse_failed", raw: llm_call.text)
  end

  def failed_parse(llm_call, error_kind, raw: nil)
    {
      verdict: "fail",
      result: {
        "error" => error_kind,
        "raw"   => raw,
        "llm_call_error" => llm_call.error_message
      }.compact
    }
  end

  def extract_json(text)
    # Models occasionally wrap JSON in ```json fences. Strip them.
    text.sub(/\A.*?(\{)/m, '\1').sub(/(\}).*?\z/m, '\1')
  end
end
```

## File inventory

Every file added or modified. Canonical for the implementation plan.

### Migrations

`db/migrate/<ts>_add_player_action_to_events.rb` — there is no DB enum, so the migration is a no-op for schema purposes; included as a documentation marker that we audited the table at this phase. (Optional; the plan can elide this if the team prefers code-only enum changes. Leaning toward eliding.)

`db/migrate/<ts>_add_closed_at_to_scenes.rb`:

```ruby
class AddClosedAtToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :closed_at, :datetime, null: true
    add_index  :scenes, :closed_at
  end
end
```

`db/migrate/<ts>_create_scene_audits.rb`:

```ruby
class CreateSceneAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_audits do |t|
      t.references :scene, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :llm_call, null: false, foreign_key: { on_delete: :restrict }
      t.string :verdict, null: false
      t.jsonb :result, null: false, default: {}
      t.timestamps
    end

    add_index :scene_audits, :verdict
  end
end
```

Notes:
- Unique index on `scene_id` enforces 1:1.
- `on_delete: :restrict` on `llm_call_id` because deleting the underlying audit cost row would orphan the verdict; deletes propagate properly via the scene cascade.
- `verdict` is a string for forward compatibility (we may add `incomplete` later); the model validates the inclusion list.

### Models

`app/models/event.rb` — modified:

```ruby
KINDS = %w[narration player_action dice_roll oracle_query scene_transition].freeze
```

`app/models/scene.rb` — modified:

```ruby
has_one :audit, class_name: "SceneAudit", dependent: :destroy

def closed?
  closed_at.present?
end
```

`app/models/campaign.rb` — modified:

```ruby
has_many :scene_audits, through: :scenes, source: :audit
```

`app/models/scene_audit.rb` — new:

```ruby
class SceneAudit < ApplicationRecord
  belongs_to :scene
  belongs_to :llm_call

  VERDICTS = %w[pass concerns fail].freeze

  validates :verdict, presence: true, inclusion: { in: VERDICTS }
  validates :scene_id, uniqueness: true
end
```

`annotaterb` runs against all four touched models post-migration.

### `Llm` namespace

`app/lib/llm/providers/anthropic.rb` — modified to add `#call_streaming`, `#normalize_system`, `#ttl_to_anthropic`, `#build_request_body`. The existing `#call` is refactored to share `build_request_body` so cache breakpoints work for synchronous calls too (the audit job uses `cache_breakpoints: [0]`).

`app/lib/llm/call.rb` — modified to add `Llm::Call.execute_streaming` and `compute_cost_cents` helper. The existing `Llm::Call.execute` grows a `cache_breakpoints:` and `cache_ttl:` keyword; defaults preserve Phase 4 behavior.

`app/lib/llm/provider.rb` — modified to add `bookkeeper_audit: { provider: :anthropic, model: "claude-sonnet-4-6" }` to `PURPOSES`.

`app/lib/llm/result.rb` — no changes; the existing fields cover the streaming case.

### `Narrator` namespace

`app/lib/narrator/prompt.rb` — new (the `Data.define` shape).
`app/lib/narrator/prompt_builder.rb` — new.
`app/lib/narrator/system_prompt.rb` — new (the rules text constant).
`app/lib/narrator/audit_prompt_builder.rb` — new.
`app/lib/narrator/audit_system_prompt.rb` — new (the audit rules + JSON schema).

### ViewModels

`app/view_models/player/campaign_view_model.rb` — new. `expose :id, :name, :description`.

`app/view_models/player/scene_view_model.rb` — new. `expose :id, :title, :summary`. `expose :events do; @record.events.order(:occurred_at).map { Player::EventViewModel.new(_1) }; end`.

`app/view_models/player/event_view_model.rb` — new. `expose :id, :kind, :occurred_at`. `expose :text do; render_text; end`. `expose :occurred_at_label do; @record.occurred_at.iso8601; end`. The `render_text` helper switches on `@record.kind`:

```ruby
def render_text
  case @record.kind
  when "narration"        then @record.payload["text"].to_s
  when "player_action"    then @record.payload["text"].to_s
  when "dice_roll"        then "Rolled #{@record.payload["expression"]} → #{@record.payload["result"]}"
  when "oracle_query"     then "Asked: #{@record.payload["question"]} (#{@record.payload["likelihood"]}, chaos #{@record.payload["chaos"]}) → #{@record.payload["answer"]}"
  when "scene_transition" then @record.payload["reason"].to_s
  else                         ""
  end
end
```

`app/view_models/narrator/scene_audit_view_model.rb` — new. Mirrors `Player::SceneViewModel` but its `events` returns `Narrator::EventViewModel` instances.

`app/view_models/narrator/event_view_model.rb` — new. Same exposed shape as `Player::EventViewModel` for Phase 8 (narrator audit consumes player-visible event content). Lives separately so future phases can add narrator-only event fields without touching the player class.

### Routes

`config/routes/play.rb` — modified:

```ruby
constraints subdomain: "" do
  devise_for :users, skip: [:registrations], controllers: { sessions: "users/sessions" }
  root "play/home#show"

  scope module: "play" do
    resources :campaigns, only: [:index] do
      member { get :play }
      resources :scenes, only: [] do
        member { get :play }
        resources :dice_rolls,     only: [:create]
        resources :oracle_queries, only: [:create]
        resources :narrations,     only: [:create]
      end
    end
  end
end
```

`config/routes/admin.rb` — modified:

```ruby
constraints subdomain: "admin" do
  scope module: "admin", as: :admin do
    root to: redirect("/campaigns")

    resources :campaigns do
      resource :chaos_factor, only: [:update], controller: "chaos_factors"
      resources :scenes do
        member do
          post :move_up
          post :move_down
        end
        resource :closure, only: [:create], controller: "scene_closures"
        resource :audit,   only: [:show],   controller: "scene_audits"
      end
    end

    namespace :diagnostics do
      resource :llm, only: [:show, :create], controller: "llm"
    end
  end
end
```

### Controllers

`app/controllers/play/narrations_controller.rb` — new:

```ruby
module Play
  class NarrationsController < ::ApplicationController
    before_action :load_scene

    def create
      text = params.require(:narration).permit(:text).fetch(:text, "").to_s.strip

      if text.blank?
        return render turbo_stream: turbo_stream.replace(
          dom_id_for_narration_form,
          Play::Narration::FormComponent.new(scene: @scene, text: text, error: "type something to do")
        ), status: :unprocessable_content
      end

      player_action_event = nil
      narration_event     = nil

      Event.transaction do
        # Create in the order they should appear in the log (occurred_at default
        # is set in a before_validation hook to Time.current, so creation order
        # matches occurred_at order). The player_action's narration_event_id
        # link is populated in a follow-up update once the narration row exists.
        player_action_event = @scene.events.create!(
          kind: "player_action",
          payload: { "text" => text, "narration_event_id" => nil }
        )
        narration_event = @scene.events.create!(
          kind: "narration",
          payload: {
            "text" => "", "status" => "streaming", "llm_call_id" => nil,
            "player_action_event_id" => player_action_event.id
          }
        )
        player_action_event.update!(payload: player_action_event.payload.merge(
          "narration_event_id" => narration_event.id
        ))
      end

      NarrationJob.perform_later(narration_event.id)

      respond_to do |f|
        f.turbo_stream { render turbo_stream: stream_appends_and_form_reset(player_action_event, narration_event) }
        f.html { redirect_to play_campaign_scene_path(@scene.campaign, @scene) }
      end
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end

    def stream_appends_and_form_reset(player_action_event, narration_event)
      [
        turbo_stream.append(dom_id_for_log,
                            Play::Events::Component.for(player_action_event).new(event: player_action_event)),
        turbo_stream.append(dom_id_for_log,
                            Play::Events::Component.for(narration_event).new(event: narration_event)),
        turbo_stream.remove(dom_id_for_log_empty),
        turbo_stream.replace(dom_id_for_narration_form,
                             Play::Narration::FormComponent.new(scene: @scene))
      ]
    end

    def dom_id_for_log         = view_context.dom_id(@scene, :log)
    def dom_id_for_log_empty   = view_context.dom_id(@scene, :log_empty)
    def dom_id_for_narration_form = view_context.dom_id(@scene, :narration_form)
  end
end
```

`app/controllers/admin/scene_closures_controller.rb` — new:

```ruby
module Admin
  class SceneClosuresController < Admin::ApplicationController
    before_action :load_scene

    def create
      if @scene.closed?
        redirect_to admin_campaign_path(@scene.campaign), alert: "Scene already closed."
        return
      end

      @scene.update!(closed_at: Time.current)
      SceneAuditJob.perform_later(@scene.id)
      redirect_to admin_campaign_path(@scene.campaign),
                  notice: "Scene closed; audit running."
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end
  end
end
```

`app/controllers/admin/scene_audits_controller.rb` — new:

```ruby
module Admin
  class SceneAuditsController < Admin::ApplicationController
    before_action :load_scene

    def show
      @audit = @scene.audit
      render Admin::SceneAudits::ShowComponent.new(scene: @scene, audit: @audit)
    end

    private

    def load_scene
      @scene = current_user.campaigns.find(params[:campaign_id]).scenes.find(params[:scene_id])
    end
  end
end
```

### Components

**Play side (new):**

`app/components/play/narration/form_component.{rb,html.erb}` — full-width textarea + Submit. Receives `scene:`, optional `text:` (sticky on error), optional `error:`. Renders `data-controller="narration-form"`, `data-action="keydown->narration-form#handleKeydown submit->narration-form#onSubmit"`. Container element carries `id=dom_id(scene, :narration_form)` so a `turbo_stream.replace` finds it.

`app/components/play/events/player_action_component.{rb,html.erb}` — renders the player-side turn. Slightly indented, subdued left-border accent, distinct from narration's own styling. Receives `event:`. Renders `event.payload["text"]` and a relative timestamp.

**Play side (modified):**

`app/components/play/scenes/play_component.html.erb` — modified to render `Play::Narration::FormComponent` above the existing `InputDockComponent`. Adds `data-controller="scene-log-scroll"` on a wrapping div around the log.

`app/components/play/events/narration_component.{rb,html.erb}` — modified. Reads `payload["status"]`. Status branches:
- `"streaming"`: the prose text + a small blinking-cursor element (CSS animation, no JS).
- `"complete"`: prose text only.
- `"errored"`: subdued red-bordered card; renders partial text (if any) + error message ("the narrator couldn't finish — try again").
The component's root `id` is `dom_id(event)` so the broadcast `turbo_stream.replace` finds it.

`app/components/play/events/component.rb` — modified `REGISTRY`:

```ruby
REGISTRY = {
  "narration"        => NarrationComponent,
  "player_action"    => PlayerActionComponent,
  "dice_roll"        => DiceRollComponent,
  "oracle_query"     => OracleQueryComponent,
  "scene_transition" => SceneTransitionComponent,
}.freeze
```

**Admin side (new):**

`app/components/admin/scenes/close_button_component.{rb,html.erb}` — renders the "End scene" button (PATCH form). Disabled when `scene.closed?`.

`app/components/admin/scene_audits/show_component.{rb,html.erb}` — renders the verdict, the four criteria with status badges, the summary, and a link to the underlying `LlmCall` (e.g. via the existing diagnostics surface or, future, a per-call admin page). Renders a "running…" placeholder when `audit.nil?`.

**Admin side (modified):**

`app/components/admin/scenes/row_component.{rb,html.erb}` — modified to render the `CloseButtonComponent` and, when `scene.closed?`, a "View audit" link.

`app/components/admin/campaigns/show_component.{rb,html.erb}` — no change required for Phase 8; the row component handles per-scene UI.

### Stimulus controllers

`app/javascript/controllers/narration_form_controller.js` — new. Targets: `text` (textarea). Behaviors:
- On `input` (matched via Stimulus `data-action="input->narration-form#autosize"` on the textarea), autosize the height to fit content.
- On `keydown` Cmd/Ctrl+Enter, submit the form.
- After Turbo successful response, the form is replaced with a fresh component (handled server-side); no client-side reset needed.

`app/javascript/controllers/scene_log_scroll_controller.js` — new. On `connect`, sets up a `MutationObserver` watching its element for added children. Maintains a `wasNearBottom` flag (recomputed on `scroll` events). On mutation, if `wasNearBottom`, calls `scrollIntoView({ block: "end", behavior: "smooth" })` on the last child.

`app/javascript/application.js` — modified to register the two new controllers alongside the existing `flash`, `dice-form`, `oracle-form` controllers.

### Lookbook previews

`spec/components/previews/play/narration/form_component_preview.rb` — `default`, `with_sticky_text`, `with_error`.

`spec/components/previews/play/events/player_action_component_preview.rb` — `default`, `long_text`.

`spec/components/previews/play/events/narration_component_preview.rb` — extended with `streaming`, `complete`, `errored` examples (the existing `default` preview becomes `complete`).

`spec/components/previews/admin/scenes/close_button_component_preview.rb` — `available`, `disabled_already_closed`.

`spec/components/previews/admin/scene_audits/show_component_preview.rb` — `pass`, `concerns`, `fail`, `running`.

### Specs

**Library specs:**

- `spec/lib/narrator/prompt_builder_spec.rb` — happy path: returns a `Narrator::Prompt` with three system blocks and one user message. Cache breakpoints are `[0, 1]`. **Asymmetry** (load-bearing): for a campaign with 3 factions and 4 NPCs each carrying 2 secrets, the rendered prompt does `not_to leak_secrets_of(*factions, *npcs)`. **Structural**: `input_view_models` returns only `Player::*` instances (assert each `class.name.start_with?("Player::")`). **Truncation**: when the scene has 35 events, the messages contain a `"[5 earlier events truncated for context]"` marker and the last 30 events.
- `spec/lib/narrator/audit_prompt_builder_spec.rb` — happy path: returns a `Narrator::Prompt` with one system block (cached) and one user message. Asymmetry: even though the audit is narrator-side, the prompt does `not_to leak_secrets_of(*)` for any campaign because the audit's input is the event log only and event content was already player-built. (Vacuous-pass guarded by Phase 5.16 — at least one secret must exist for the assertion to be non-trivial.)
- `spec/lib/narrator/system_prompt_spec.rb` — sanity: `Narrator::SystemPrompt.text` is non-empty; mentions "asymmetry" or equivalent rules language. (Light test; the prompt content is design-reviewed, not spec-driven.)
- `spec/lib/llm/providers/anthropic_streaming_spec.rb` — WebMock-driven streaming tests. Stub returns chunked SSE events: `message_start`, several `content_block_delta`, `message_delta` (with usage), `message_stop`. Assert: yielded chunks concatenate to the expected text; returned `Llm::Result` has correct token counts; cache_breakpoints translate into the request body's `cache_control` decorations; error mid-stream produces a populated error result with partial text in `prompt_payload["partial_text"]`. (May require a tiny fixture helper for the SSE encoding.)
- `spec/lib/llm/call_spec.rb` — extended: `execute_streaming` writes a row with the same shape as `execute`, including correct cost when cache_breakpoints are used.

**Model specs:**

- `spec/models/event_spec.rb` — extended: `player_action` is a valid kind; existing four kinds still valid.
- `spec/models/scene_spec.rb` — extended: `closed?` is true when `closed_at` is set; `audit` association.
- `spec/models/scene_audit_spec.rb` — new: validates `verdict` inclusion, `scene_id` uniqueness; cascades from scene.
- `spec/models/campaign_spec.rb` — extended: `scene_audits` reaches all closed-scene audits.

**Job specs:**

- `spec/jobs/narration_job_spec.rb` — stubs `Llm::Call.execute_streaming` to invoke the chunk callback with deterministic chunks; asserts the narration event's payload accumulates and ends `status: "complete"` with a `llm_call_id`. Asserts at least one `broadcast_replace_to` call. Error path: stub returns an errored `LlmCall`; payload ends `status: "errored"`. Test the FLUSH_MS / FLUSH_BYTES thresholds with a fake clock or by counting broadcast invocations against a known chunk sequence.
- `spec/jobs/scene_audit_job_spec.rb` — stubs `Llm::Call.execute` to return a successful `LlmCall` with valid JSON in `text`; asserts a `SceneAudit` row is created with the right verdict and result. Parse failure path: returned `text` is `"definitely not json"` → audit row created with `verdict: "fail"`, `result["error"] == "audit_parse_failed"`. Idempotency: running the job twice for the same scene creates only one audit row.

**Request specs:**

- `spec/requests/play/narrations_spec.rb` — happy path: POST creates two events (player_action + narration), enqueues `NarrationJob`, returns turbo_stream with two appends + a remove + a replace. Empty text: returns 422 with the form re-rendered. Cross-user 404. Cross-scene 404.
- `spec/requests/admin/scene_closures_spec.rb` — happy path: POST sets `closed_at`, enqueues `SceneAuditJob`, redirects with notice. Already-closed: redirect with alert; no second job. Cross-user 404.
- `spec/requests/admin/scene_audits_spec.rb` — happy path: GET shows the audit when present. Audit-not-yet-created: shows the "running" placeholder. Cross-user 404.

**Component specs:**

- `spec/components/play/narration/form_component_spec.rb` — renders textarea + button; sticky text on error; asymmetry guard.
- `spec/components/play/events/player_action_component_spec.rb` — renders the player text; renders timestamp; asymmetry guard.
- `spec/components/play/events/narration_component_spec.rb` — modified: tests for the three status branches (`streaming` shows cursor; `complete` shows clean text; `errored` shows error message). Asymmetry guard already present.
- `spec/components/play/events/component_spec.rb` — extended: `for(event)` resolves `player_action` to `PlayerActionComponent`; unknown kind still raises.
- `spec/components/admin/scenes/close_button_component_spec.rb` — enabled when not closed; disabled when closed.
- `spec/components/admin/scene_audits/show_component_spec.rb` — renders verdict, criteria, summary; renders running placeholder when audit nil.

**System spec:**

- `spec/system/phase_8_narrator_streaming_spec.rb` — Selenium. Sign in → admin: create a campaign + a faction + an NPC + a scene → switch to play subdomain → open the scene → submit "I open the door" → confirm a `player_action` event row appears immediately and a `narration` event row appears with streaming cursor → (Anthropic call is stubbed via a streaming WebMock response that emits chunks every ~50ms) → wait for the streamed text to accumulate → confirm the cursor disappears at completion. Then switch to admin → click "End scene" → reload the audit page → confirm the verdict + criteria are displayed.

  The audit LLM call is stubbed via WebMock with a fixture JSON response. The streaming narration uses a chunked WebMock stub helper introduced in this phase (see `spec/support/anthropic_streaming.rb`).

### Test infrastructure

`spec/support/anthropic_streaming.rb` — new helper. Builds chunked SSE response bodies for WebMock from a list of text chunks, with the right event-type wrappers (`message_start`, `content_block_delta`, `message_delta`, `message_stop`). One method: `stub_anthropic_streaming(text_chunks:, usage: {...})`. Used by streaming adapter spec, narration job spec, system spec.

`spec/support/turbo_streams.rb` — new. Captures `Turbo::StreamsChannel.broadcast_replace_to` calls into a per-test array so job specs can assert against them without standing up an ActionCable subscriber. Implementation: `before(:each) { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) { |*args, **kwargs| recorded << [args, kwargs] } }` exposed via a helper module included in `:job` specs.

### `.env.example` / credentials

No new environment variables. The existing `Rails.application.credentials.anthropic.api_key` covers narration and audit calls.

### README

Add a brief "Narration loop" sub-section under the existing Operations heading: documents the play-side narration submit URL, the per-`(scene, user)` Turbo Streams channel naming, and how to inspect a narration in production via `LlmCall.where(purpose: "narration").last`.

## Asymmetry test pattern

The phase's load-bearing assertion. Two complementary tests:

```ruby
# Structural: input shape constrains what's reachable.
RSpec.describe Narrator::PromptBuilder do
  describe "#input_view_models" do
    let(:scene) { create(:scene, campaign: create(:campaign, :with_factions_and_npcs_with_secrets)) }

    it "is built only from Player::* view models" do
      builder = described_class.new(scene: scene, player_action_text: "I look around.")
      expect(builder.input_view_models).to all(satisfy { |vm| vm.class.name.start_with?("Player::") })
    end
  end

  describe "asymmetry" do
    let(:campaign) { create(:campaign) }
    let(:scene)    { create(:scene, campaign: campaign) }
    let!(:factions) { create_list(:faction, 2, :with_secrets, campaign: campaign) }
    let!(:npcs)     { create_list(:npc,     3, :with_secrets, campaign: campaign) }

    it "does not leak any faction or NPC secret content into the rendered prompt" do
      prompt = described_class.call(scene: scene, player_action_text: "I look around.")
      expect(prompt.to_s).not_to leak_secrets_of(*factions, *npcs)
    end
  end
end
```

The `:with_secrets` faction trait (already proposed in Phase 5's factory inventory; if not yet present, Phase 8 adds it) creates two `FactionSecret` children with realistic `label` and `content` strings. The `:with_secrets` NPC trait does the same. Both ensure `leak_secrets_of` has non-empty secret strings to scan against, so the matcher's vacuous-pass guard from Phase 5.16 doesn't allow false negatives.

The Phase 6/7 component asymmetry guards are reused for `Play::Narration::FormComponent` and `Play::Events::PlayerActionComponent`.

## Out of scope / non-goals

- **Real-time multi-user sync.** v2 alpha is single-user-per-campaign per Phase 0; broadcasts are per-`(scene, user)` for forecloseability but no UI ever shows multiple players sharing a scene.
- **Cancel / interrupt mid-stream.** v1 didn't have it; alpha doesn't need it.
- **Retry button on errored narration.** A re-submit replaces the failed attempt as a new turn.
- **Regenerate / variant narration.** No "give me a different response" affordance.
- **Cross-scene context in the prompt.** The prompt sees the current scene's events only. Campaign-level context comes from the campaign description + faction/NPC catalogues. Long-arc continuity is a future-phase concern.
- **Tool use by the narrator.** No "the narrator decides to roll dice." Mechanical control stays with the player.
- **Streaming for the audit job.** Synchronous Sonnet call; structured output; no UX benefit to streaming.
- **Live update of the audit page.** Phase 8 expects the user to refresh; no Turbo Stream subscription on the audit show page.
- **Admin UI to edit narration content post-hoc.** Narration events are immutable from the admin once created. Future phase if needed.
- **Cost dashboard** for narration spend. Captured in `llm_calls` from Phase 4; visualized in a later phase.
- **Per-campaign rate limits / spend caps.** Out of scope for invite-only alpha.
- **Resume-after-disconnect with token-level continuity.** The DB carries whatever was persisted at the last flush; subsequent broadcasts resume on reconnect; partial loss between the last flush and disconnect is acceptable.
- **`Narrator::PromptBuilder` configuration / templating.** The system prompt and prompt structure are constants in code; no per-campaign customization in Phase 8.

## Future direction (captured for context, not implemented)

- **Phase 9 (asymmetry hardening + first end-to-end session).** Comprehensive asymmetry test coverage across every player-facing surface; first real campaign played end-to-end on the v2 deployment. Phase 8's `Narrator::PromptBuilder` asymmetry tests get extended; bug fixes from real play.
- **Phase 10+ (post-MVP additive features).** Faction clocks, revelations, threads, Mythic random-event composition, module/lore intake all integrate via additional Player-side context blocks in `Narrator::PromptBuilder`. The system block layout (rules / roster / scene context) gives natural slots for additional cached blocks.
- **Streaming structured output for the audit.** If audit prompts grow expensive, switch to streaming + `tool_use` output for parse robustness. Phase 8's `Llm::Call.execute_streaming` handles only text streaming; tool-streaming would be an additive method.
- **Rolling summarization of older events.** Replaces the `"[N earlier events truncated]"` marker with an LLM-generated summary, cached per-scene. Useful when scenes routinely exceed 30 events.
- **Per-campaign system prompt overrides.** Storage of campaign-specific narrator persona / tone notes; surfaced via `campaign_and_roster_text`.
- **Anthropic Sonnet 4.7 / future model upgrades.** A one-line change in `Llm::Provider::PURPOSES`. Pricing module already prices Opus 4.7 and Haiku 4.5.

## Notes for the implementation plan

- The `anthropic` SDK's streaming surface (`messages.stream`) needs verification against the locked gem version: confirm event types (`:message_start`, `:content_block_delta`, `:message_delta`, `:message_stop`), the shape of `event.delta.text`, and the location of usage data (`message_delta.usage` vs `message_stop`). Add this verification as a numbered step in the plan; provisional code in this spec assumes the most-common 1.x shape.
- `Turbo::StreamsChannel.broadcast_replace_to` rendering API: confirm the kwarg name (`renderable:` vs `partial:` vs `html:`) for ViewComponent rendering in the locked turbo-rails version. Provisional code uses `renderable:`.
- `Solid Queue` config: a new queue named `narration` is added to `config/queue.yml` (or `config/recurring.yml`-equivalent in Solid Queue's config format). Concurrency: 2 workers initially; tunable. The default queue handles `SceneAuditJob` and other one-shots.
- `Event.with_lock` is straightforward Postgres row-level lock. Test that concurrent `flush` calls serialize correctly; this is defensive insurance against Solid Queue retry semantics.
- The `scene_log_scroll_controller.js` MutationObserver test: a system spec asserting "scroll position stays at bottom while content streams" is brittle in Selenium; rely on a JS unit test (no JS test infra in v2 yet, so for Phase 8 this is a manual playtesting check rather than an automated test). The plan notes this as a known gap.
- `Narrator::SystemPrompt.text` is an opportunity to import phrasing from v1's `dm/agents/narrator/system-prompt.md` — port the asymmetry-discipline language verbatim where it still applies, since v1 spent real iteration on it. The v1 file is at `v1-final-poc:dm/agents/narrator/system-prompt.md`.
- `Narrator::AuditSystemPrompt.text` similarly draws from v1's bookkeeper-audit prompts (`v1-final-poc:dm/agents/bookkeeper/...`), restricted to the four narrator-discipline criteria (asymmetry-violation detection is structural in v2 and not part of the audit).
- `Llm::Pricing.cost_cents` is already aware of cache token rates. The streaming path does NOT need pricing changes.
- The `Play::Events::Component::REGISTRY` modification needs to load `PlayerActionComponent` when the dispatcher loads. Zeitwerk autoloading handles this as long as the constant is referenced at request time, not at boot time. Existing pattern from Phase 6 holds.
- The `compute_cost_cents` extraction from `Llm::Call.execute` is a refactor that affects Phase 4 specs minimally (the function's behavior is unchanged). The plan does the extract first, runs Phase 4 specs to confirm green, then layers `execute_streaming` on top.
- The `cache_breakpoints:` keyword on `Llm::Call.execute` is opt-in with a default of `[]` so Phase 4 callers (the diagnostics tool) keep working with no change.
- Spec performance: streaming specs that use real timer-based flushing (FLUSH_MS) should stub `Process.clock_gettime` or pass a fake clock injectable through a constructor option on `NarrationJob`. The plan resolves the cleanest approach.
- The `:bookkeeper_audit` purpose is added to `Llm::Provider::PURPOSES`. The `Llm::Provider#provider_name_for(:bookkeeper_audit)` returns `"anthropic"` and the model returns `"claude-sonnet-4-6"` (same as narration).

## Self-review notes

This spec defines the architectural commitments and detailed file inventory for Phase 8. It inherits the asymmetry-by-context-construction commitment from Phase 0 and applies it: the `Narrator::PromptBuilder`'s call graph cannot reach hidden state because its inputs are `Player::*` ViewModels by construction, and the Player-side ViewModel classes do not expose any path to the `*_secrets` tables.

The streaming implementation is intentionally scoped: chunk batching prevents browser overload; per-`(scene, user)` stream identifiers preserve forecloseability; the partial-text-on-error pattern is debuggable without being lossy. The `cache_breakpoints` first-class adapter parameter pays off real cost reductions on the rules + roster blocks, which are stable across most calls.

The session-end audit is the smallest implementation that satisfies the Phase 0 acceptance criterion ("structured audit result, reachable from the campaign") while being genuinely useful (LLM-evaluated narrator-discipline criteria with structured JSON output). Re-open semantics are deliberately deferred until the user demonstrates a need.

Phase 8 is the largest of the playing-MVP phases by file count and by architectural surface area. Phase 9 is intentionally a shake-out / hardening phase rather than another big build, because Phase 8 introduces enough new surfaces that real playtesting is needed to discover the next priorities.
