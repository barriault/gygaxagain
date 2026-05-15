require "rails_helper"

RSpec.describe Narrator::Prompt do
  let(:prompt) {
    described_class.new(
      system: [ { type: "text", text: "rules" }, { type: "text", text: "roster" } ],
      messages: [ { role: "user", content: "hi" } ],
      cache_breakpoints: [ 0, 1 ]
    )
  }

  it "exposes system, messages, cache_breakpoints" do
    expect(prompt.system.length).to eq(2)
    expect(prompt.messages.length).to eq(1)
    expect(prompt.cache_breakpoints).to eq([ 0, 1 ])
  end

  it "renders to a string by joining all blocks" do
    str = prompt.to_s
    expect(str).to include("rules")
    expect(str).to include("roster")
    expect(str).to include("hi")
  end

  it "produces call_kwargs with the three components" do
    kwargs = prompt.to_call_kwargs
    expect(kwargs.keys).to contain_exactly(:system, :messages, :cache_breakpoints)
  end
end
