module Fraud
  class RiskAssessor # We will add "risk points" based on certain condition checks to flag fraudulant transactions
    BLOCK_THRESHOLD = 75
    HIGH_AMOUNT = 100_000
    VERY_HIGH_AMOUNT = 500_000
    VELOCITY_WINDOW = 10.minutes
    VELOCITY_THRESHOLD = 3
    DISPOSABLE_DOMAINS = %w[tempmail.com mailinator.com guerrillamail.com 10minutemail.com trashmail.com].freeze

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      @score = 0
      @reasons = []

      # Call them all one by one to check in sequence (can add more later to be more specific for use-cases)
      check_amount
      check_email_domain
      check_velocity
      check_test_card

      { score: @score, reasons: @reasons, blocked: @score >= BLOCK_THRESHOLD }
    end

    private

    attr_reader :params

    def check_amount # Amount check flag
      amount = params[:amount].to_i
      if amount > VERY_HIGH_AMOUNT
        add(50, "very_high_amount")
      elsif amount > HIGH_AMOUNT
        add(30, "high_amount")
      end
    end

    def check_email_domain # Check for disposable domains (known ones for now)
      email = params[:customer_email].to_s.downcase
      domain = email.split('@').last
      return if domain.blank?

      add(40, "disposable_email") if DISPOSABLE_DOMAINS.include?(domain)
    end

    def check_velocity # check transaction velocity of specific merchant
      email = params[:customer_email].to_s.downcase
      return if email.blank?

      recent_count = Payment.where(customer_email: email).where("created_at > ?", VELOCITY_WINDOW.ago).count

      add(50, "velocity_exceeded") if recent_count >= VELOCITY_THRESHOLD
    end

    def check_test_card # Check for testing / sandbox type card numbers
      card_number = params.dig(:payment_details, :card_number) || params.dig(:payment_details, "card_number")

      return if card_number.blank?

      add(20, "test_card_suffix") if card_number.to_s.end_with?("0000")
    end

    def add(points, reason)
      @score += points
      @reasons << reason
    end
  end
end