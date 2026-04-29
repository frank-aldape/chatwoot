class SuperAdmin::InstanceStatusesController < SuperAdmin::ApplicationController
  def show
    @metrics = Monitoring::InstanceMetricsService.new.perform

    respond_to do |format|
      format.html
      format.json { render json: { metrics: @metrics } }
    end
  end
end
