require "rails_helper"

RSpec.describe "Play::Narrations", type: :request do
  let(:user)     { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:scene)    { create(:scene, campaign: campaign) }

  let(:other_user)     { create(:user) }
  let(:other_campaign) { create(:campaign, user: other_user) }
  let(:other_scene)    { create(:scene, campaign: other_campaign) }

  before { sign_in user }

  describe "POST /campaigns/:cid/scenes/:sid/narrations" do
    let(:path) { campaign_scene_narrations_path(campaign, scene) }

    it "creates a player_action and a narration event in order" do
      expect {
        post path, params: { narration: { text: "I open the door." } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change(Event, :count).by(2).and change(scene.events, :count).by(2)

      events = scene.events.order(:occurred_at)
      expect(events.first.kind).to eq("player_action")
      expect(events.first.payload["text"]).to eq("I open the door.")
      expect(events.last.kind).to eq("narration")
      expect(events.last.payload["status"]).to eq("streaming")
      expect(events.last.payload["player_action_event_id"]).to eq(events.first.id)
      expect(events.first.payload["narration_event_id"]).to eq(events.last.id)
    end

    it "enqueues a NarrationJob for the new narration event" do
      expect {
        post path, params: { narration: { text: "x" } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to have_enqueued_job(NarrationJob)
    end

    it "returns turbo_stream with appends + replace + remove" do
      post path, params: { narration: { text: "x" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include('action="append"')
      expect(response.body).to include('action="replace"')
    end

    it "returns 422 with re-rendered form on empty text" do
      expect {
        post path, params: { narration: { text: "  " } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("type something")
    end

    it "rejects narrations against a closed scene" do
      scene.update!(closed_at: Time.current)
      expect {
        post path, params: { narration: { text: "x" } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.not_to change(Event, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("scene is closed")
    end

    it "returns 404 for cross-user campaign access" do
      post campaign_scene_narrations_path(other_campaign, other_scene),
           params: { narration: { text: "x" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
