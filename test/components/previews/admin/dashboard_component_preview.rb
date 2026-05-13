module Admin
  class DashboardComponentPreview < ViewComponent::Preview
    def default
      render Admin::DashboardComponent.new
    end
  end
end
