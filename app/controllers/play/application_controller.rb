module Play
  class ApplicationController < ::ApplicationController
    # Play-surface controllers inherit from here. No authentication
    # requirement at this level — campaign-scoped auth comes in Phase 3.
  end
end
