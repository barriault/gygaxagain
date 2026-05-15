require "rails_helper"

RSpec.describe Admin::SceneAudits::ShowComponent, type: :component do
  let(:scene) { create(:scene) }

  it "renders the running placeholder when audit is nil" do
    rendered = render_inline(described_class.new(scene: scene, audit: nil))
    expect(rendered.text).to include("Audit running")
  end

  it "renders verdict, criteria, summary when audit is present" do
    audit = create(:scene_audit, scene: scene)
    rendered = render_inline(described_class.new(scene: scene, audit: audit))
    expect(rendered.text).to include("PASS")
    expect(rendered.text).to include("player_agency")
    expect(rendered.text).to include("Looks good.")
  end

  it "renders an error block when result has an error key" do
    audit = create(:scene_audit, :failed, scene: scene,
                   result: { "error" => "audit_parse_failed", "raw" => "garbage" })
    rendered = render_inline(described_class.new(scene: scene, audit: audit))
    expect(rendered.text).to include("Audit error: audit_parse_failed")
    expect(rendered.text).to include("garbage")
  end
end
