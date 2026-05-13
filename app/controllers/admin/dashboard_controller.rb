module Admin
  class DashboardController < ApplicationController
    def show
      render Admin::DashboardComponent.new
    end
  end
end
