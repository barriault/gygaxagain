module Admin
  module SceneSecrets
    class RowComponent < ViewComponent::Base
      def initialize(campaign:, scene:, scene_secret:)
        @campaign = campaign
        @scene = scene
        @secret = scene_secret
      end

      attr_reader :campaign, :scene, :secret
    end
  end
end
