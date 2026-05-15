module Admin
  module SceneAudits
    class ShowComponent < ViewComponent::Base
      def initialize(scene:, audit:)
        @scene = scene
        @audit = audit
      end

      attr_reader :scene, :audit

      def running?
        audit.nil?
      end

      def verdict_label
        audit&.verdict&.upcase
      end

      def verdict_classes
        case audit&.verdict
        when "pass"     then "bg-emerald-900/40 border-emerald-700 text-emerald-200"
        when "concerns" then "bg-amber-900/40 border-amber-700 text-amber-200"
        when "fail"     then "bg-rose-900/40 border-rose-700 text-rose-200"
        else                 "bg-slate-800 border-slate-700 text-slate-300"
        end
      end

      def criteria
        audit&.result&.fetch("criteria", []) || []
      end

      def summary
        audit&.result&.fetch("summary", "")
      end
    end
  end
end
