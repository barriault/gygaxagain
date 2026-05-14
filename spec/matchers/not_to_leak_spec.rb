require "rails_helper"

RSpec.describe "leak_secrets_of matcher" do
  let(:campaign) { create(:campaign) }
  let(:faction)  { create(:faction, campaign: campaign) }

  describe "with a String subject" do
    it "matches when the string contains a secret's content" do
      create(:faction_secret, faction: faction, content: "the hidden temple is in the swamp")
      expect("Some text mentioning the hidden temple is in the swamp.").to leak_secrets_of(faction)
    end

    it "matches when the string contains a secret's label" do
      create(:faction_secret, faction: faction, label: "true leader identity", content: "irrelevant")
      expect("This text mentions the true leader identity in passing.").to leak_secrets_of(faction)
    end

    it "does NOT match when the string contains no secret content or label" do
      create(:faction_secret, faction: faction, label: "hidden temple", content: "in the swamp")
      expect("This text is innocuous and reveals nothing.").not_to leak_secrets_of(faction)
    end

    it "does NOT match when the faction has no secrets at all" do
      # No secrets created.
      expect("Any string here.").not_to leak_secrets_of(faction)
    end
  end

  describe "with multiple records" do
    let(:npc) { create(:npc, campaign: campaign) }

    it "collects secrets across all records" do
      create(:faction_secret, faction: faction, content: "faction secret content")
      create(:npc_secret,     npc: npc,         content: "npc secret content")

      expect("This leaks faction secret content.").to     leak_secrets_of(faction, npc)
      expect("This leaks npc secret content.").to         leak_secrets_of(faction, npc)
      expect("This text is innocuous.").not_to            leak_secrets_of(faction, npc)
    end
  end

  describe "failure message" do
    it "names the secret that leaked" do
      create(:faction_secret, faction: faction, content: "the hidden temple")
      matcher = leak_secrets_of(faction)
      matcher.matches?("This mentions the hidden temple.")
      expect(matcher.failure_message_when_negated).to include("the hidden temple")
    end
  end

  describe "with a ViewModel subject (via to_h)" do
    let(:safe_vm_class) do
      Class.new(ApplicationViewModel) { expose :name }
    end

    let(:leaky_vm_class) do
      Class.new(ApplicationViewModel) do
        expose :name
        expose :everything do
          @record.secrets.map { |s| s.content }
        end
      end
    end

    it "does NOT match a ViewModel that only exposes public attrs" do
      create(:faction_secret, faction: faction, content: "hidden")
      vm = safe_vm_class.new(faction)
      expect(vm).not_to leak_secrets_of(faction)
    end

    it "matches a ViewModel that exposes a secret-traversing attr" do
      create(:faction_secret, faction: faction, content: "the hidden temple")
      vm = leaky_vm_class.new(faction)
      expect(vm).to leak_secrets_of(faction)
    end
  end
end

RSpec.describe "expose_attrs_via matcher" do
  let(:player_vm_class) do
    Class.new(ApplicationViewModel) { expose :id, :name }
  end

  let(:narrator_vm_class) do
    Class.new(ApplicationViewModel) do
      expose :id, :name
      expose :secrets do
        []
      end
    end
  end

  let(:disguised_leaker_class) do
    Class.new(ApplicationViewModel) do
      expose :hidden_facts do
        @record.secrets.map(&:content)
      end
    end
  end

  it "matches a class with :secrets in exposed_attrs" do
    expect(narrator_vm_class).to expose_attrs_via(:secrets)
  end

  it "does NOT match a class whose exposed_attrs excludes :secrets" do
    expect(player_vm_class).not_to expose_attrs_via(:secrets)
  end

  it "documented limitation: does NOT match a disguised leaker (caught dynamically by leak_secrets_of)" do
    expect(disguised_leaker_class).not_to expose_attrs_via(:secrets)
    # And here's the dynamic catch:
    campaign = create(:campaign)
    faction = create(:faction, campaign: campaign)
    create(:faction_secret, faction: faction, content: "leaked content")
    vm = disguised_leaker_class.new(faction)
    expect(vm).to leak_secrets_of(faction)
  end
end
