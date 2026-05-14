module Play
  module Campaigns
    class ScenePickerComponentPreview < ViewComponent::Preview
      def default
        campaign = Campaign.new(id: 1, name: "Curse of Strahd")
        scenes = [
          Scene.new(id: 1, campaign: campaign, title: "Tavern at Dusk", summary: "Rainy, quiet.", position: 1),
          Scene.new(id: 2, campaign: campaign, title: "The Forest Path", summary: "Misty, cold.", position: 2),
          Scene.new(id: 3, campaign: campaign, title: "Castle Ravenloft", summary: "Empty halls.", position: 3)
        ]
        campaign.define_singleton_method(:scenes) do
          Class.new do
            def initialize(records) = @records = records
            def order(*) = @records
          end.new(scenes)
        end
        render Play::Campaigns::ScenePickerComponent.new(campaign: campaign)
      end

      def single_scene
        campaign = Campaign.new(id: 1, name: "One-shot")
        scenes = [
          Scene.new(id: 1, campaign: campaign, title: "The Only Scene", summary: "All the action.", position: 1)
        ]
        campaign.define_singleton_method(:scenes) do
          Class.new do
            def initialize(records) = @records = records
            def order(*) = @records
          end.new(scenes)
        end
        render Play::Campaigns::ScenePickerComponent.new(campaign: campaign)
      end
    end
  end
end
