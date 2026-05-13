require "rails_helper"
require "rake"

RSpec.describe "users.rake" do
  before(:all) do
    Rails.application.load_tasks
  end

  let(:task) { Rake::Task["users:create"] }

  before { task.reenable }

  describe "users:create" do
    let(:email) { "rake-test@example.test" }
    let(:password) { "correct horse battery staple" }

    after do
      ENV.delete("EMAIL")
      ENV.delete("PASSWORD")
    end

    it "creates a user from EMAIL/PASSWORD env vars" do
      ENV["EMAIL"] = email
      ENV["PASSWORD"] = password

      expect { task.invoke }.to change(User, :count).by(1)
      expect(User.find_by(email: email)).to be_present
    end

    it "aborts when EMAIL is missing" do
      ENV["PASSWORD"] = password

      expect { task.invoke }.to raise_error(SystemExit, /EMAIL required/)
    end

    it "aborts when PASSWORD is missing" do
      ENV["EMAIL"] = email

      expect { task.invoke }.to raise_error(SystemExit, /PASSWORD required/)
    end
  end
end
