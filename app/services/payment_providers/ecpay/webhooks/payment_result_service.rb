# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    module Webhooks
      class PaymentResultService < BaseService
        def initialize(organization_id:, event_json:)
          @organization = Organization.find(organization_id)
          @event_json = event_json
          super
        end

        def call
          payment_provider = PaymentProviders::EcpayProvider.find_by!(organization:)

          parsed = Lago::EcpayAes.parse_response(
            JSON.parse(event_json),
            payment_provider.hash_key,
            payment_provider.hash_iv
          )

          data = parsed[:data]
          rtn_code = parsed[:rtn_code]

          payment = Payment.find_by(provider_payment_id: data["TradeNo"])
          return result unless payment

          Invoices::Payments::EcpayService
            .new.update_payment_status(
              organization_id: organization.id,
              status: rtn_code.to_s,
              ecpay_payment: EcpayPayment.new(
                id: data["TradeNo"],
                status: rtn_code.to_s,
                metadata: {merchant_trade_no: data["MerchantTradeNo"]}
              )
            ).raise_if_error!

          result
        end

        private

        attr_reader :organization, :event_json

        EcpayPayment = Data.define(:id, :status, :metadata)
      end
    end
  end
end
