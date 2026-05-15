require "rails_helper"

# Asymmetry coverage meta-spec.
#
# Walks the player-facing namespaces at load time and asserts every
# non-exempt class has a leak_secrets_of assertion in its spec file.
# String-matches the spec file (not eval) — a coverage floor, not a
# correctness check. Code review still catches assertions that are
# present but written incorrectly.
RSpec.describe "Asymmetry coverage", type: :meta do
  before(:all) { Rails.application.eager_load! }

  EXEMPT_COMPONENTS = {
    "Play::HomeComponent" => "static landing, no ViewModel input"
  }.freeze

  # Returns the absolute spec path for a given player-facing class.
  # Mirrors Rails conventions:
  #   Player::FactionViewModel    -> spec/view_models/player/faction_view_model_spec.rb
  #   Play::Events::NarrationComponent -> spec/components/play/events/narration_component_spec.rb
  #   Narrator::PromptBuilder     -> spec/lib/narrator/prompt_builder_spec.rb
  def spec_file_for(klass)
    underscored = klass.name.underscore
    case klass.name
    when /\APlayer::.+ViewModel\z/   then Rails.root.join("spec/view_models/#{underscored}_spec.rb")
    when /\APlay::.+Component\z/     then Rails.root.join("spec/components/#{underscored}_spec.rb")
    when /\ANarrator::.+\z/          then Rails.root.join("spec/lib/#{underscored}_spec.rb")
    end
  end

  # Walks a module recursively, collecting all constants it owns
  # (transitively). Returns Class AND Module objects — callers must
  # apply `.select { |c| c.is_a?(Class) && ... }` before passing
  # results to assert_coverage_for, or modules like Play::Events::Component
  # will match a path regex and fail with "spec missing".
  def descendants_of(mod)
    return [] unless mod.is_a?(Module)
    collected = []
    walk = ->(m) do
      m.constants.each do |sym|
        c = m.const_get(sym)
        next unless c.is_a?(Module) && c.name&.start_with?(m.name + "::")
        collected << c
        walk.call(c) unless c.is_a?(Class)
      end
    end
    walk.call(mod)
    collected
  end

  def assert_coverage_for(klass)
    path = spec_file_for(klass)
    return "#{klass.name}: spec_file_for returned nil — naming convention mismatch?" unless path
    return "#{klass.name}: spec file missing at #{path}" unless path.exist?
    return "#{klass.name}: spec at #{path} does not contain `leak_secrets_of`" unless path.read.include?("leak_secrets_of")
    nil
  end

  describe "Player::*ViewModel coverage" do
    it "every Player::*ViewModel has a leak_secrets_of assertion in its spec" do
      view_models = descendants_of(Player)
        .select { |c| c.is_a?(Class) && c.name.end_with?("ViewModel") }

      expect(view_models).not_to be_empty,
        "Sanity: no Player::*ViewModel classes were discovered. " \
          "Did Rails.application.eager_load! actually run?"

      problems = view_models.map { |vm| assert_coverage_for(vm) }.compact

      expect(problems).to be_empty,
        -> { "Player ViewModel coverage gaps:\n" + problems.map { |p| "  - #{p}" }.join("\n") }
    end
  end

  describe "Play::*Component coverage" do
    it "every non-exempt Play::*Component has a leak_secrets_of assertion in its spec" do
      components = descendants_of(Play)
        .select { |c| c.is_a?(Class) && c < ViewComponent::Base }

      expect(components).not_to be_empty,
        "Sanity: no Play::*Component classes were discovered."

      non_exempt = components.reject { |c| EXEMPT_COMPONENTS.key?(c.name) }
      problems   = non_exempt.map { |c| assert_coverage_for(c) }.compact

      expect(problems).to be_empty,
        -> {
          "Play component coverage gaps:\n" +
            problems.map { |p| "  - #{p}" }.join("\n") +
            "\n\nAdd asymmetry coverage or — if intentionally exempt — " \
              "extend EXEMPT_COMPONENTS in spec/asymmetry/coverage_spec.rb with a reason."
        }
    end
  end

  describe "Narrator::*PromptBuilder coverage" do
    it "every Narrator::*PromptBuilder has a leak_secrets_of assertion in its spec" do
      builders = descendants_of(Narrator)
        .select { |c| c.is_a?(Class) && c.name.end_with?("PromptBuilder") }

      expect(builders).not_to be_empty,
        "Sanity: no Narrator::*PromptBuilder classes were discovered."

      problems = builders.map { |b| assert_coverage_for(b) }.compact

      expect(problems).to be_empty,
        -> { "Narrator PromptBuilder coverage gaps:\n" + problems.map { |p| "  - #{p}" }.join("\n") }
    end
  end
end
