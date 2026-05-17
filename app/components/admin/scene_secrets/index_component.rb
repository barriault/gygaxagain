module Admin
  module SceneSecrets
    class IndexComponent < ViewComponent::Base
      def initialize(campaign:, scene:, scene_secrets:)
        @campaign = campaign
        @scene = scene
        @scene_secrets = scene_secrets
      end

      attr_reader :campaign, :scene, :scene_secrets
    end
  end
end
