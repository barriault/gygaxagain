module Player
  class SceneViewModel < ApplicationViewModel
    expose :id, :title, :summary

    expose :events do
      @record.events.order(:occurred_at).map { Player::EventViewModel.new(_1) }
    end
  end
end
