module Admin
  class DashboardController < Admin::ApplicationController
    def show
      render Admin::DashboardComponent.new
    end
  end
end
