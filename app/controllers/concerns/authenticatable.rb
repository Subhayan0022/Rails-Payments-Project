module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_merchant!
  end

  private

  def authenticate_merchant!
    @current_api_key = ApiKey.authenticate(bearer_token)
    return if @current_api_key

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def current_api_key
    @current_api_key
  end

  def current_merchant
    @current_api_key&.merchant
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    return nil unless header.start_with?("Bearer ")

    header.sub(/\ABearer\s+/, "").strip.presence
  end
end
