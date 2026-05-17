require "rails_helper"

RSpec.describe "Play::DiceRolls", type: :request do
  before { host! "gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe "POST /campaigns/:campaign_id/scenes/:scene_id/dice_rolls" do
    context "authenticated" do
      before { sign_in user }

      it "creates a dice_roll event with payload (HTML format)" do
        expect {
          Dice::Random.with_fixed([ 4, 5 ]) do
            post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
                 params: { dice_roll: { expression: "2d6+3" } }
          end
        }.to change { scene.events.count }.by(1)

        event = scene.events.last
        expect(event.kind).to eq("dice_roll")
        expect(event.payload["expression"]).to eq("2d6+3")
        expect(event.payload["result"]).to eq(12) # 4 + 5 + 3
        expect(event.payload["breakdown"]).to be_an(Array)
        expect(event.payload["rolls"]).to eq([ [ 4, 5 ], [] ])
      end

      it "stamps turn_number on the dice_roll event so it's grouped with its turn in prompt history" do
        # Set up an awaiting_roll state on Turn 1
        aragorn = create(:player_character, campaign: campaign, name: "Aragorn", role: "pc")
        campaign.update!(main_character: aragorn)
        create(:event, scene: scene, kind: "narration", turn_number: 1,
               payload: { "text" => "The door creaks. [[1d20+3 — Aragorn Strength]]", "status" => "complete" })

        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
             params: { dice_roll: { expression: "1d20+3" } }

        roll = scene.events.where(kind: "dice_roll").last
        expect(roll.turn_number).to eq(1)
      end

      it "responds with redirect on HTML format" do
        Dice::Random.with_fixed([ 4, 5 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
               params: { dice_roll: { expression: "2d6" } }
        end

        expect(response).to redirect_to(play_campaign_scene_path(campaign, scene))
      end

      it "responds with Turbo Stream on turbo_stream format" do
        Dice::Random.with_fixed([ 4, 5 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
               params: { dice_roll: { expression: "2d6" } },
               as: :turbo_stream
        end

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('turbo-stream action="append"')
        expect(response.body).to include('turbo-stream action="remove"')
        expect(response.body).to include('turbo-stream action="replace"')
      end

      it "returns 422 and does not create on unparseable expression" do
        expect {
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
               params: { dice_roll: { expression: "1d6+wat" } },
               as: :turbo_stream
        }.not_to change { scene.events.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("unparseable")
      end

      it "returns 422 on empty expression" do
        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
             params: { dice_roll: { expression: "" } },
             as: :turbo_stream

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 404 on a cross-user campaign" do
        other_campaign = create(:campaign, user: other_user)
        other_scene    = create(:scene, campaign: other_campaign)

        post "/campaigns/#{other_campaign.id}/scenes/#{other_scene.id}/dice_rolls",
             params: { dice_roll: { expression: "1d6" } }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 on a cross-campaign scene" do
        other_campaign = create(:campaign, user: user)
        scene_in_other = create(:scene, campaign: other_campaign)

        post "/campaigns/#{campaign.id}/scenes/#{scene_in_other.id}/dice_rolls",
             params: { dice_roll: { expression: "1d6" } }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "unauthenticated" do
      it "redirects to sign-in" do
        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
             params: { dice_roll: { expression: "1d6" } }

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end
  end

  describe "continuation trigger" do
    include ActiveJob::TestHelper

    let(:user)     { create(:user) }
    let(:campaign) { create(:campaign, user:) }
    let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc").tap { campaign.update!(main_character: _1) } }
    let(:scene)    { create(:scene, campaign:) }

    before do
      sign_in user
      # Set up awaiting_roll state: a narration ending with an open chip
      create(:event, scene:, kind: "narration", turn_number: 1,
             payload: { "text" => "The door creaks. [[1d20+3 — Aragorn Strength]]" })
    end

    it "enqueues a continuation NarrationJob after the roll" do
      expect {
        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/dice_rolls",
             params: { dice_roll: { expression: "1d20+3" } }
      }.to have_enqueued_job(NarrationJob).with(hash_including(trigger: "continuation"))
    end
  end
end
