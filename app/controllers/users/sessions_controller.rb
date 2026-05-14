class Users::SessionsController < Devise::SessionsController
  # The sign-in form itself must be reachable when unauthenticated.
  # ApplicationController has a default `before_action :authenticate_user!`;
  # without skipping it here we'd loop redirect-to-sign-in forever.
  skip_before_action :authenticate_user!

  # Override create to allow cross-host redirect after sign-in.
  # after_sign_in_path_for may return a URL on a different host (apex
  # play surface or admin subdomain depending on the user's campaign
  # state). Rails 8+ blocks cross-host redirects by default via
  # ActionController::Redirecting::OpenRedirectError. We must
  # explicitly pass allow_other_host: true.
  #
  # Body copied from devise-5.0.4. Re-check on Devise upgrades.
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    redirect_to after_sign_in_path_for(resource), allow_other_host: true,
                                                   status: Devise.responder.redirect_status
  end

  # Override destroy for the same reason: after_sign_out_path_for returns
  # root_url(subdomain: "") which from admin.gygaxagain.com is a cross-host
  # redirect to gygaxagain.com.
  #
  # Body copied from devise-5.0.4. Re-check on Devise upgrades.
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    redirect_to after_sign_out_path_for(resource_name),
                allow_other_host: true,
                status: Devise.responder.redirect_status
  end
end
