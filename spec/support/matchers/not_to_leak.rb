# spec/support/matchers/not_to_leak.rb
#
# Asymmetry test matchers.
#
# leak_secrets_of(*records)
#   Asserts that a subject (a String, or any object responding to #to_h) does
#   not contain any `label` or `content` value from the `secrets` association
#   of the provided records. Use it like:
#
#     expect(player_view_model).not_to leak_secrets_of(faction)
#     expect(rendered_prompt).not_to    leak_secrets_of(faction, npc)
#
#   IMPORTANT: this matcher raises ArgumentError if none of the passed records
#   have any *Secret rows. This is intentional — a vacuous "no leak detected"
#   pass is almost always a forgotten `create(:faction_secret, ...)` in the
#   test's `before` block, not a real asymmetry assertion. Seed secrets first.
#
# expose_attrs_via(association_name)
#   Asserts (as a structural check) that a ViewModel class exposes an
#   attribute whose name matches the given association. Use it like:
#
#     expect(Player::FactionViewModel).not_to expose_attrs_via(:secrets)
#
# The matchers are complementary: leak_secrets_of catches dynamic leaks
# (including ones disguised behind differently-named exposed attrs);
# expose_attrs_via catches the structural shape "you exposed :secrets" even
# when no secret content happens to exist in the test fixture.

RSpec::Matchers.define :leak_secrets_of do |*records|
  match do |subject|
    secret_strings = collect_secret_strings(records)
    if secret_strings.compact.reject(&:empty?).empty?
      raise ArgumentError,
            "leak_secrets_of: none of the passed records have any *Secret rows. " \
            "Seed at least one secret in a `before` block before calling this matcher, " \
            "or remove the assertion entirely. The matcher refuses to silently pass " \
            "with no secrets to check against."
    end

    @leaked = []
    secret_strings.each do |secret_str|
      next if secret_str.nil? || secret_str.empty?
      if render_subject(subject).include?(secret_str)
        @leaked << secret_str
      end
    end
    @leaked.any?
  end

  failure_message do |subject|
    "expected subject to leak secrets of #{records.map(&:class).join(', ')}, but found none"
  end

  failure_message_when_negated do |subject|
    "expected subject NOT to leak secrets, but found these leaked strings: #{@leaked.inspect}"
  end

  def collect_secret_strings(records)
    records.flat_map do |r|
      next [] unless r.respond_to?(:secrets)
      r.secrets.flat_map { |s| [ s.label, s.content ] }
    end
  end

  def render_subject(subject)
    return subject if subject.is_a?(String)
    return deep_stringify(subject.to_h) if subject.respond_to?(:to_h)
    subject.to_s
  end

  def deep_stringify(value)
    case value
    when Hash  then value.flat_map { |k, v| [ k.to_s, deep_stringify(v) ] }.join(" ")
    when Array then value.map { |v| deep_stringify(v) }.join(" ")
    when nil   then ""
    else            value.to_s
    end
  end
end

RSpec::Matchers.define :expose_attrs_via do |association_name|
  match do |view_model_class|
    view_model_class.respond_to?(:exposed_attrs) &&
      view_model_class.exposed_attrs.include?(association_name)
  end

  failure_message do |klass|
    "expected #{klass} to expose attrs via #{association_name.inspect}, but exposed_attrs is #{klass.exposed_attrs.inspect}"
  end

  failure_message_when_negated do |klass|
    "expected #{klass} NOT to expose attrs via #{association_name.inspect}, but :#{association_name} is in exposed_attrs"
  end
end
