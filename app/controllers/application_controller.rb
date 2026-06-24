class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include Pundit::Authorization
  include SwitchLocale

  skip_before_action :verify_authenticity_token

  before_action :set_current_user, unless: :devise_controller?
  after_action :touch_current_auth_client, unless: :devise_controller?
  around_action :switch_locale
  around_action :handle_with_exception, unless: :devise_controller?

  private

  def set_current_user
    @user ||= current_user
    Current.user = @user
  end

  def pundit_user
    {
      user: Current.user,
      account: Current.account,
      account_user: Current.account_user
    }
  end

  def touch_current_auth_client
    return unless @resource.is_a?(User) && @token&.client.present?

    @resource.touch_auth_client!(@token.client, request)
  end
end
ApplicationController.include_mod_with('Concerns::ApplicationControllerConcern')
