# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
class SuperAdmin::ApplicationController < Administrate::ApplicationController
  include ActionView::Helpers::TagHelper
  include ActionView::Context
  include SuperAdmin::NavigationHelper

  helper_method :render_vue_component, :settings_open?, :settings_pages
  # authenticiation done via devise : SuperAdmin Model
  before_action :authenticate_super_admin!, unless: :observability_token_authenticated?

  # Override this value to specify the number of elements to display at a time
  # on index pages. Defaults to 20.
  # def records_per_page
  #   params[:per_page] || 20
  # end

  def order
    @order ||= Administrate::Order.new(
      params.fetch(resource_name, {}).fetch(:order, 'id'),
      params.fetch(resource_name, {}).fetch(:direction, 'desc')
    )
  end

  private

  def observability_token_authenticated?
    request.format.json? && observability_endpoint? && valid_observability_token?
  end

  def observability_endpoint?
    controller_name == 'instance_statuses' ||
      (controller_name == 'accounts' && action_name == 'observability')
  end

  def valid_observability_token?
    configured_token = GlobalConfigService.load('OBSERVABILITY_API_TOKEN', '')
    return false if configured_token.blank?

    provided_token = observability_token_from_request
    return false if provided_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided_token, configured_token)
  end

  def observability_token_from_request
    bearer_token.presence ||
      request.headers[:'X-Observability-Token'].presence ||
      request.headers[:HTTP_X_OBSERVABILITY_TOKEN].presence
  end

  def bearer_token
    auth_header = request.authorization.to_s
    return unless auth_header.start_with?('Bearer ')

    auth_header.delete_prefix('Bearer ').strip
  end

  def render_vue_component(component_name, props = {})
    html_options = {
      id: 'app',
      data: {
        component_name: component_name,
        props: props.to_json
      }
    }
    content_tag(:div, '', html_options)
  end

  def invalid_action_perfomed
    # rubocop:disable Rails/I18nLocaleTexts
    flash[:error] = 'Invalid action performed'
    # rubocop:enable Rails/I18nLocaleTexts
    redirect_back(fallback_location: root_path)
  end
end
