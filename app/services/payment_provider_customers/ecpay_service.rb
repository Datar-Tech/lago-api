# frozen_string_literal: true

module PaymentProviderCustomers
  class EcpayService < BaseService
    include Customers::PaymentProviderFinder

    def initialize(ecpay_customer = nil)
      @ecpay_customer = ecpay_customer
      super(nil)
    end

    def create
      result.ecpay_customer = ecpay_customer
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      result.not_allowed_failure!(code: "feature_not_supported")
    end

    private

    attr_accessor :ecpay_customer

    delegate :customer, to: :ecpay_customer
  end
end
