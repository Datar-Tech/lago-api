# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    module Customers
      class CreateBindCardService < BaseService
        def initialize(payment_provider:, bind_card_pay_token:, merchant_member_id:)
          @payment_provider = payment_provider
          @bind_card_pay_token = bind_card_pay_token
          @merchant_member_id = merchant_member_id
          super
        end

        def call
          data = {
            MerchantID: payment_provider.merchant_id,
            BindCardPayToken: bind_card_pay_token,
            MerchantMemberID: merchant_member_id
          }

          request_body = Lago::EcpayAes.build_request(
            payment_provider.merchant_id, data,
            payment_provider.hash_key, payment_provider.hash_iv
          )

          response = http_client.post_with_response(
            request_body,
            {"Content-Type" => "application/json"}
          )

          parsed = Lago::EcpayAes.parse_response(
            JSON.parse(response.body),
            payment_provider.hash_key, payment_provider.hash_iv
          )

          return result.service_failure!(code: "create_bind_card_error", message: parsed[:rtn_msg]) unless parsed[:success]

          result.data = parsed[:data]
          result.three_d_url = parsed[:data].dig("ThreeDInfo", "ThreeDURL")
          result
        rescue LagoHttpClient::HttpError => e
          result.third_party_failure!(third_party: "ECPay", error_code: e.error_code, error_message: e.error_body)
        end

        private

        attr_reader :payment_provider, :bind_card_pay_token, :merchant_member_id

        def http_client
          LagoHttpClient::Client.new("#{payment_provider.ecpg_base_url}/Merchant/CreateBindCard")
        end
      end
    end
  end
end
