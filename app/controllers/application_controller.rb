class ApplicationController < ActionController::Base
  # Default-deny: every controller authenticates unless it explicitly skips.
  # Public surfaces use `skip_before_action :authenticate_user!`.
  before_action :authenticate_user!

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def after_sign_in_path_for(user)
    if user.last_played_campaign_id && user.campaigns.exists?(id: user.last_played_campaign_id)
      play_campaign_url(user.last_played_campaign_id, subdomain: "")
    elsif user.campaigns.any?
      campaigns_url(subdomain: "")
    else
      new_admin_campaign_url(subdomain: "admin")
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_url(subdomain: "")
  end
end
