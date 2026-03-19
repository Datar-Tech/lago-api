# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    module Customers
      class BindCardService < BaseService
        def initialize(customer:, payment_provider:)
          @customer = customer
          @payment_provider = payment_provider
          super
        end

        def call
          merchant_member_id = "M-#{customer.external_id.first(8)}"

          ecpay_customer = PaymentProviderCustomers::EcpayCustomer.find_by!(
            customer:, payment_provider: payment_provider
          )
          ecpay_customer.update!(merchant_member_id: merchant_member_id)

          data = {
            MerchantID: payment_provider.merchant_id,
            MerchantMemberID: merchant_member_id,
            OrderInfo: {
              MerchantTradeNo: generate_trade_no("BND"),
              MerchantTradeDate: taiwan_datetime_now,
              TotalAmount: 0,
              ReturnURL: bind_card_return_url,
              TradeDesc: "VelaOrdo 綁定信用卡"
            },
            CardInfo: {},
            ConsumerInfo: {
              MerchantMemberID: merchant_member_id,
              Email: customer.email,
              Phone: customer.phone.presence || ""
            }
          }

          request_body = Lago::EcpayAes.build_request(
            payment_provider.merchant_id, data,
            payment_provider.hash_key, payment_provider.hash_iv
          )

          response = http_client.post_with_response(
            request_body.to_json,
            {"Content-Type" => "application/json"}
          )

          parsed = Lago::EcpayAes.parse_response(
            JSON.parse(response.body),
            payment_provider.hash_key, payment_provider.hash_iv
          )

          return result.service_failure!(code: "bind_card_error", message: parsed[:rtn_msg]) unless parsed[:success]

          result.token = parsed[:data]["Token"]
          result.token_url = parsed[:data]["TokenURL"]
          result.merchant_member_id = merchant_member_id
          result.merchant_trade_no = data[:OrderInfo][:MerchantTradeNo]
          result
        rescue LagoHttpClient::HttpError => e
          result.third_party_failure!(third_party: "ECPay", error_code: e.error_code, error_message: e.error_body)
        end

        private

        attr_reader :customer, :payment_provider

        def http_client
          LagoHttpClient::Client.new("#{payment_provider.ecpg_base_url}/Merchant/GetTokenbyBindingCard")
        end

        def taiwan_datetime_now
          Time.now.in_time_zone("Taipei").strftime("%Y/%m/%d %H:%M:%S")
        end

        def generate_trade_no(prefix)
          "#{prefix}#{Time.now.strftime('%Y%m%d%H%M%S%3N')}"[0, 20]
        end

        def bind_card_return_url
          base = ENV.fetch("ECPAY_ORDER_RESULT_URL_BASE", "https://api.velaordo.com/ecpay/card_bindings")
          "#{base}/#{payment_provider.organization_id}/callback"
        end
      end
    end
  end
end
