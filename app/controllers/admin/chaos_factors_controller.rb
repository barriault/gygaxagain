module Admin
  class ChaosFactorsController < Admin::ApplicationController
    before_action :load_campaign

    def update
      delta =
        case params[:direction]
        when "up"   then  1
        when "down" then -1
        else 0
        end

      new_value = (@campaign.chaos_factor + delta).clamp(1, 9)
      @campaign.update!(chaos_factor: new_value)

      redirect_to admin_campaign_path(@campaign),
                  notice: "Chaos factor set to #{new_value}."
    end

    private

    def load_campaign
      @campaign = current_user.campaigns.find(params[:campaign_id])
    end
  end
end
