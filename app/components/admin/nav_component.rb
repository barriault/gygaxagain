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
