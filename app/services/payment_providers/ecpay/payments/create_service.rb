# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    module Payments
      class CreateService < BaseService
        include ::Customers::PaymentProviderFinder

        def initialize(payment:, reference:, metadata:)
          @payment = payment
          @reference = reference
          @metadata = metadata
          @invoice = payment.payable
          @provider_customer = payment.payment_provider_customer
          super
        end

        def call
          result.payment = payment

          unless provider_customer.card_bound?
            SendWebhookJob.perform_later("payment_provider.error_occurred", invoice,
              provider_customer_id: provider_customer.id,
              provider_error: {message: "No card bound", error_code: "card_not_bound"})
            return result
          end

          data = {
            PlatformID: "",
            MerchantID: ecpay_provider.merchant_id,
            BindCardID: provider_customer.card_id,
            OrderInfo: {
              MerchantTradeDate: taiwan_datetime_now,
              MerchantTradeNo: generate_trade_no("INV"),
              TotalAmount: amount_ntd,
              ReturnURL: payment_return_url,
              TradeDesc: "VelaOrdo Subscription",
              ItemName: "VelaOrdo #{invoice.number}"
            },
            ConsumerInfo: {
              MerchantMemberID: provider_customer.merchant_member_id,
              Email: customer.email,
              Phone: customer.phone.presence || ""
            },
            CustomField: ""
          }

          request_body = Lago::EcpayAes.build_request(
            ecpay_provider.merchant_id, data,
            ecpay_provider.hash_key, ecpay_provider.hash_iv
          )

          response = http_client.post_with_response(
            request_body,
            {"Content-Type" => "application/json"}
          )

          parsed = Lago::EcpayAes.parse_response(
            JSON.parse(response.body),
            ecpay_provider.hash_key, ecpay_provider.hash_iv
          )

          payment.provider_payment_id = parsed.dig(:data, "TradeNo")
          payment.status = parsed[:rtn_code].to_s
          payment.save!

          if parsed.dig(:data, "ThreeDURL").present?
            result.three_d_url = parsed.dig(:data, "ThreeDURL")
          end

          result
        rescue LagoHttpClient::HttpError => e
          result.third_party_failure!(third_party: "ECPay", error_code: e.error_code, error_message: e.error_body)
        end

        private

        attr_reader :payment, :reference, :metadata, :invoice, :provider_customer

        delegate :customer, to: :provider_customer

        def ecpay_provider
          @ecpay_provider ||= provider_customer.payment_provider
        end

        def http_client
          LagoHttpClient::Client.new("#{ecpay_provider.ecpg_base_url}/Merchant/CreatePaymentWithCardID")
        end

        def amount_ntd
          if invoice.currency == "TWD"
            # TWD: amount_cents is already in TWD sub-units
            [invoice.total_due_amount_cents, 1].max
          else
            # USD → NTD conversion, ceil rounding
            rate = ENV.fetch("USD_TO_NTD_RATE", "32").to_f
            [(invoice.total_due_amount_cents / 100.0 * rate).ceil, 1].max
          end
        end

        def taiwan_datetime_now
          Time.now.in_time_zone("Taipei").strftime("%Y/%m/%d %H:%M:%S")
        end

        def generate_trade_no(prefix)
          "#{prefix}#{Time.now.strftime('%Y%m%d%H%M%S%3N')}"[0, 20]
        end

        def payment_return_url
          base = ENV.fetch("ECPAY_RETURN_URL_BASE", "https://api.velaordo.com/webhooks/ecpay")
          "#{base}/#{ecpay_provider.organization_id}"
        end
      end
    end
  end
end
