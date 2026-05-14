module Narrator
  class FactionViewModel < ApplicationViewModel
    expose :id, :name, :public_description

    expose :secrets do
      @record.secrets.map { |s| Narrator::FactionSecretViewModel.new(s) }
    end
  end
end
