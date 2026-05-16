module Admin
  module SceneSecrets
    class FormComponent < ViewComponent::Base
      def initialize(campaign:, scene:, scene_secret:)
        @campaign = campaign
        @scene = scene
        @secret = scene_secret
      end

      attr_reader :campaign, :scene, :secret

      def form_url
        secret.persisted? ?
          admin_campaign_scene_scene_secret_path(campaign, scene, secret) :
          admin_campaign_scene_scene_secrets_path(campaign, scene)
      end

      def form_method = secret.persisted? ? :patch : :post
      def heading     = secret.persisted? ? "Edit scene secret" : "New scene secret"
      def submit      = secret.persisted? ? "Save" : "Create"
    end
  end
end
