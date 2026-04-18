class ServiceResult
  attr_reader :payload, :errors, :type

  def initialize(type:, payload: nil, errors:[])
    @type = type
    @payload = payload
    @errors = errors
  end

  def self.success(payload)
    new(type: :success, payload: payload)
  end

  def self.failure(errors)
    new(type: :failure, errors: Array(errors))
  end

  def self.cached(payload)
    new(type: :cached, payload: payload)
  end

  def success? = type == :success
  def failure? = type == :failure
  def cached? = type == :cached
end