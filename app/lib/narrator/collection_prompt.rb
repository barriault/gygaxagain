module Narrator
  module CollectionPrompt
    module_function

    def companion_check(names)
      [
        "Anything for #{format_names(names)}, or shall I run them?",
        "What about #{format_names(names)}?",
        "Anything from #{format_names(names)}?"
      ].sample
    end

    def next_pc(names)
      case names.size
      when 1 then [ "And #{names.first}?", "What about #{names.first}?" ].sample
      else        [ "What about #{format_names(names)}?", "And #{format_names(names)}?" ].sample
      end
    end

    def short_circuit_decline(names)
      "Wait — I still need #{format_names(names)}. Even 'they hold' is fine."
    end

    def no_focus_no_main = "For which PC?"

    def unknown_pc(name) = "I don't see #{name} in the party."

    def format_names(names)
      case names.size
      when 0 then ""
      when 1 then names.first
      when 2 then "#{names.first} and #{names.last}"
      else        "#{names[0..-2].join(', ')}, and #{names.last}"
      end
    end
  end
end
