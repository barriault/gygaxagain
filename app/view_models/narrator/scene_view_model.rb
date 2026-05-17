module Narrator
  class SceneViewModel < ApplicationViewModel
    expose :title
    expose :summary

    expose :scene_secrets do
      @record.scene_secrets.order(:label).map { Narrator::SceneSecretViewModel.new(_1) }
    end
  end
end
