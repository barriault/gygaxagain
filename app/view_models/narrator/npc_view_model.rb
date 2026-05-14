module Narrator
  class NpcViewModel < ApplicationViewModel
    expose :id, :name, :public_description, :location

    expose :secrets do
      @record.secrets.map { |s| Narrator::NpcSecretViewModel.new(s) }
    end
  end
end
