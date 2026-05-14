require "rails_helper"

RSpec.describe ApplicationViewModel, type: :view_model do
  let(:record_class) do
    Struct.new(:name, :email, :secret, keyword_init: true)
  end

  let(:record) { record_class.new(name: "Ada", email: "ada@example.test", secret: "hidden") }

  describe "attr-list expose" do
    let(:vm_class) do
      Class.new(described_class) do
        expose :name, :email
      end
    end

    it "auto-defines readers that delegate to the record" do
      vm = vm_class.new(record)
      expect(vm.name).to eq("Ada")
      expect(vm.email).to eq("ada@example.test")
    end

    it "records exposed attrs on the class" do
      expect(vm_class.exposed_attrs).to eq([ :name, :email ])
    end

    it "does NOT expose attrs that weren't declared" do
      vm = vm_class.new(record)
      expect { vm.secret }.to raise_error(NoMethodError)
    end
  end

  describe "block-form expose" do
    let(:vm_class) do
      Class.new(described_class) do
        expose :name
        expose :greeting do
          "Hello, #{@record.name}"
        end
      end
    end

    it "defines the reader from the block" do
      vm = vm_class.new(record)
      expect(vm.greeting).to eq("Hello, Ada")
    end

    it "records the block-form attr in exposed_attrs" do
      expect(vm_class.exposed_attrs).to eq([ :name, :greeting ])
    end

    it "raises if a block is given with multiple attr names" do
      expect {
        Class.new(described_class) do
          expose(:foo, :bar) { 42 }
        end
      }.to raise_error(ArgumentError, /exactly one attr name/)
    end
  end

  describe "#to_h" do
    let(:vm_class) do
      Class.new(described_class) do
        expose :name, :email
      end
    end

    it "returns a hash of exposed attrs and their values" do
      vm = vm_class.new(record)
      expect(vm.to_h).to eq(name: "Ada", email: "ada@example.test")
    end

    it "recursively unwraps nested ViewModels" do
      inner_class = Class.new(described_class) { expose :name }
      outer_class = Class.new(described_class) do
        nested = inner_class
        expose :friend do
          nested.new(@record.friend)
        end
      end

      friend_record = record_class.new(name: "Grace", email: nil, secret: nil)
      record_with_friend = Struct.new(:friend, keyword_init: true).new(friend: friend_record)

      vm = outer_class.new(record_with_friend)
      expect(vm.to_h).to eq(friend: { name: "Grace" })
    end

    it "recursively unwraps arrays of nested ViewModels" do
      inner_class = Class.new(described_class) { expose :name }
      outer_class = Class.new(described_class) do
        nested = inner_class
        expose :friends do
          @record.friends.map { |f| nested.new(f) }
        end
      end

      friends = [
        record_class.new(name: "Grace", email: nil, secret: nil),
        record_class.new(name: "Linus", email: nil, secret: nil)
      ]
      record_with_friends = Struct.new(:friends, keyword_init: true).new(friends: friends)

      vm = outer_class.new(record_with_friends)
      expect(vm.to_h).to eq(friends: [ { name: "Grace" }, { name: "Linus" } ])
    end
  end
end
