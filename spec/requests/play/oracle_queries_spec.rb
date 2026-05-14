require "rails_helper"

RSpec.describe "Play::OracleQueries", type: :request do
  before { host! "gygaxagain.com" }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, chaos_factor: 5) }
  let(:scene)    { create(:scene, campaign: campaign) }

  describe "POST /campaigns/:campaign_id/scenes/:scene_id/oracle_queries" do
    context "authenticated" do
      before { sign_in user }

      it "creates an oracle_query event with full payload" do
        expect {
          Mythic::Random.with_fixed_d100([ 32 ]) do
            post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
                 params: { oracle_query: { question: "Does it open?", likelihood: "50_50" } }
          end
        }.to change { scene.events.count }.by(1)

        event = scene.events.last
        expect(event.kind).to eq("oracle_query")
        expect(event.payload["question"]).to eq("Does it open?")
        expect(event.payload["answer"]).to eq("Yes")
        expect(event.payload["outcome"]).to eq("yes")
        expect(event.payload["likelihood"]).to eq("50_50")
        expect(event.payload["chaos"]).to eq(5)
        expect(event.payload["roll"]).to eq(32)
        expect(event.payload["random_event_triggered"]).to eq(false)
      end

      it "uses the campaign's chaos factor (not a query param)" do
        campaign.update!(chaos_factor: 7)

        Mythic::Random.with_fixed_d100([ 50 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "50_50", chaos_factor: 1 } }
        end

        expect(scene.events.last.payload["chaos"]).to eq(7)
      end

      it "sets random_event_triggered=true when the trigger rule fires" do
        Mythic::Random.with_fixed_d100([ 33 ]) do
          # roll=33 doubled-digit; leading 3 <= chaos 5 -> trigger
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "50_50" } }
        end

        expect(scene.events.last.payload["random_event_triggered"]).to eq(true)
      end

      it "defaults likelihood to 50_50 when not provided" do
        Mythic::Random.with_fixed_d100([ 50 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q" } }
        end

        expect(scene.events.last.payload["likelihood"]).to eq("50_50")
      end

      it "responds with Turbo Stream on turbo_stream format" do
        Mythic::Random.with_fixed_d100([ 50 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "likely" } },
               as: :turbo_stream
        end

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include('turbo-stream action="append"')
      end

      it "returns 422 on a blank question" do
        expect {
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "  ", likelihood: "50_50" } },
               as: :turbo_stream
        }.not_to change { scene.events.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("enter a question")
      end

      it "returns 404 on a cross-user campaign" do
        other_campaign = create(:campaign, user: other_user)
        other_scene    = create(:scene, campaign: other_campaign)

        post "/campaigns/#{other_campaign.id}/scenes/#{other_scene.id}/oracle_queries",
             params: { oracle_query: { question: "q", likelihood: "50_50" } }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 on a cross-campaign scene" do
        other_campaign = create(:campaign, user: user)
        scene_in_other = create(:scene, campaign: other_campaign)

        post "/campaigns/#{campaign.id}/scenes/#{scene_in_other.id}/oracle_queries",
             params: { oracle_query: { question: "q", likelihood: "50_50" } }

        expect(response).to have_http_status(:not_found)
      end

      it "falls back to default likelihood when given a bogus value (no 500)" do
        Mythic::Random.with_fixed_d100([ 50 ]) do
          post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
               params: { oracle_query: { question: "q", likelihood: "garbage" } }
        end

        expect(response).to have_http_status(:found) # redirect, not 500
        expect(scene.events.last.payload["likelihood"]).to eq("50_50")
      end
    end

    context "unauthenticated" do
      it "redirects to sign-in" do
        post "/campaigns/#{campaign.id}/scenes/#{scene.id}/oracle_queries",
             params: { oracle_query: { question: "q", likelihood: "50_50" } }

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/users/sign_in")
      end
    end
  end
end
