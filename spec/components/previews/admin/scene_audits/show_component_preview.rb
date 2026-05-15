module Admin
  module SceneAudits
    class ShowComponentPreview < ViewComponent::Preview
      def pass
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        audit = SceneAudit.new(scene: scene, verdict: "pass",
                               result: pass_result)
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: audit))
      end

      def concerns
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        audit = SceneAudit.new(scene: scene, verdict: "concerns",
                               result: concerns_result)
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: audit))
      end

      def failed
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        audit = SceneAudit.new(scene: scene, verdict: "fail",
                               result: { "error" => "audit_parse_failed", "raw" => "definitely not json" })
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: audit))
      end

      def running
        scene = Scene.new(id: 1, title: "The Tavern", campaign: Campaign.new(id: 1, name: "Demo"))
        render(Admin::SceneAudits::ShowComponent.new(scene: scene, audit: nil))
      end

      private

      def pass_result
        {
          "verdict" => "pass",
          "criteria" => [
            { "name" => "player_agency",            "status" => "pass", "note" => "Players were given clear choices." },
            { "name" => "follow_through",           "status" => "pass", "note" => "Player declarations were honored." },
            { "name" => "over_narration_of_intent", "status" => "pass", "note" => "Narrator stayed external." },
            { "name" => "mechanical_handoff",       "status" => "pass", "note" => "Dice prompted at the right beats." }
          ],
          "summary" => "A clean turn. Narrator framed choices and let the player drive."
        }
      end

      def concerns_result
        {
          "verdict" => "concerns",
          "criteria" => [
            { "name" => "player_agency",            "status" => "pass",     "note" => "Choices were offered." },
            { "name" => "follow_through",           "status" => "concerns", "note" => "Two declarations went unaddressed." },
            { "name" => "over_narration_of_intent", "status" => "pass",     "note" => "—" },
            { "name" => "mechanical_handoff",       "status" => "pass",     "note" => "—" }
          ],
          "summary" => "Mostly clean. Watch for dropped player declarations."
        }
      end
    end
  end
end
