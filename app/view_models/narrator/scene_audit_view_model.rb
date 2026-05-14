module Narrator
  class SceneAuditViewModel < ApplicationViewModel
    expose :id, :title, :summary

    expose :events do
      @record.events.order(:occurred_at).map { Narrator::EventViewModel.new(_1) }
    end
  end
end
