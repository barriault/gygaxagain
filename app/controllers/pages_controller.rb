class PagesController < ApplicationController
  def home
    render Pages::HomeComponent.new
  end
end
