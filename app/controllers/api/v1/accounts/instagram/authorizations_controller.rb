class Api::V1::Accounts::Instagram::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include InstagramConcern
  include Instagram::IntegrationHelper

  def create
    managed_company_id = params[:managed_company_id].presence
    inbox_name = params[:inbox_name].to_s.strip.presence

    # https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/business-login#step-1--get-authorization
    redirect_url = instagram_client.auth_code.authorize_url(
      {
        redirect_uri: "#{base_url}/instagram/callback",
        scope: REQUIRED_SCOPES.join(','),
        enable_fb_login: '0',
        force_authentication: '1',
        response_type: 'code',
        state: generate_instagram_token(
          Current.account.id,
          managed_company_id: managed_company_id,
          inbox_name: inbox_name
        )
      }
    )
    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end
end
