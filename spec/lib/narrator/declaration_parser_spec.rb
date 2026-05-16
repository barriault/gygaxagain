require "rails_helper"

RSpec.describe Narrator::DeclarationParser do
  let(:campaign) { create(:campaign) }
  let!(:aragorn) { create(:player_character, campaign:, name: "Aragorn", role: "pc") }
  let!(:caine)   { create(:player_character, campaign:, name: "Caine",   role: "companion") }
  let!(:fred)    { create(:player_character, campaign:, name: "Fred",    role: "companion") }
  let!(:patric)  { create(:player_character, campaign:, name: "Patric",  role: "companion") }
  before         { campaign.update!(main_character: aragorn) }
  let(:scene)    { create(:scene, campaign:) }

  def parse(text, focus: nil, undeclared_pcs: [ aragorn ], undeclared_companions: [ caine, fred, patric ])
    described_class.call(
      text: text,
      campaign: campaign,
      focus_pc: focus,
      undeclared_pcs: undeclared_pcs,
      undeclared_companions: undeclared_companions
    )
  end

  context "dice-only input" do
    it "returns a DiceRoll with main PC as default" do
      result = parse("1d20+3")
      expect(result).to be_a(Narrator::DeclarationParser::DiceRoll)
      expect(result.expression).to eq("1d20+3")
      expect(result.pc).to eq(aragorn)
    end
  end

  context "unattributed declaration with main PC set" do
    it "routes to main PC" do
      result = parse("I push the door open")
      expect(result).to be_a(Narrator::DeclarationParser::Success)
      expect(result.declarations).to eq([ { pc: aragorn, text: "I push the door open" } ])
    end
  end

  context "explicit name" do
    it "attributes to the named PC" do
      result = parse("Caine listens at the door")
      expect(result.declarations).to eq([ { pc: caine, text: "Caine listens at the door" } ])
    end

    it "splits multiple names with sentence delimiters" do
      result = parse("Aragorn looks. Caine listens.")
      pcs = result.declarations.map { _1[:pc] }
      expect(pcs).to contain_exactly(aragorn, caine)
    end
  end

  context "group/anaphoric words" do
    it "attributes 'the rest' to all undeclared companions" do
      result = parse("The rest hang back",
                     undeclared_pcs: [], undeclared_companions: [ caine, fred, patric ])
      pcs = result.declarations.map { _1[:pc] }
      expect(pcs).to contain_exactly(caine, fred, patric)
    end

    it "attributes 'they' similarly" do
      result = parse("They follow Aragorn",
                     undeclared_pcs: [], undeclared_companions: [ caine, fred, patric ])
      expect(result.declarations.size).to eq(3)
    end

    it "attributes 'Everyone' to all undeclared (PCs + companions)" do
      result = parse("Everyone walks to the cemetery.",
                     undeclared_pcs: [ aragorn ], undeclared_companions: [ caine, fred, patric ])
      pcs = result.declarations.map { _1[:pc] }
      expect(pcs).to contain_exactly(aragorn, caine, fred, patric)
    end

    it "attributes 'We' to all undeclared" do
      result = parse("We approach the gate.",
                     undeclared_pcs: [ aragorn ], undeclared_companions: [ caine, fred, patric ])
      expect(result.declarations.size).to eq(4)
    end
  end

  context "unknown PC" do
    it "fails with unknown_pc message" do
      result = parse("Boromir charges in")
      expect(result).to be_a(Narrator::DeclarationParser::Failure)
      expect(result.reason).to include("Boromir")
    end
  end

  context "no focus, no main, unattributed" do
    it "fails with no_focus_no_main" do
      campaign.update!(main_character: nil)
      result = parse("opens the door", focus: nil, undeclared_pcs: [ aragorn ], undeclared_companions: [])
      expect(result).to be_a(Narrator::DeclarationParser::Failure)
      expect(result.reason).to include("which PC")
    end
  end

  context "focus override" do
    it "routes to focus PC when no name and main set" do
      result = parse("listens", focus: caine,
                     undeclared_pcs: [], undeclared_companions: [ caine, fred, patric ])
      expect(result.declarations).to eq([ { pc: caine, text: "listens" } ])
    end
  end

  context "short-circuit attempt" do
    it "fails when PCs undeclared and player says 'resolve'" do
      result = parse("resolve", undeclared_pcs: [ aragorn ])
      expect(result).to be_a(Narrator::DeclarationParser::Failure)
      expect(result.reason).to include("Aragorn")
    end
  end
end
