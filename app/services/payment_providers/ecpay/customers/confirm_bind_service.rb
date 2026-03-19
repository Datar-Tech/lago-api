# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    module Customers
      class ConfirmBindService < BaseService
        def initialize(organization:, result_data:)
          @organization = organization
          @result_data = result_data
          super
        end

        def call
          parsed_outer = JSON.parse(result_data)
          payment_provider = find_payment_provider

          parsed = Lago::EcpayAes.parse_response(
            parsed_outer,
            payment_provider.hash_key, payment_provider.hash_iv
          )

          return result.service_failure!(code: "bind_failed", message: parsed[:rtn_msg]) unless parsed[:success]

          data = parsed[:data]

          ecpay_customer = PaymentProviderCustomers::EcpayCustomer
            .where(payment_provider:)
            .where("settings @> ?", {merchant_member_id: data["MerchantMemberID"]}.to_json)
            .first!

          ecpay_customer.card_id = data["BindCardID"]
          ecpay_customer.card_last_four = data["Card4No"]
          ecpay_customer.card_first_six = data["Card6No"]
          ecpay_customer.merchant_member_id = data["MerchantMemberID"]
          ecpay_customer.save!

          result.ecpay_customer = ecpay_customer
          result
        end

        private

        attr_reader :organization, :result_data

        def find_payment_provider
          PaymentProviders::EcpayProvider.find_by!(organization:)
        end
      end
    end
  end
end
