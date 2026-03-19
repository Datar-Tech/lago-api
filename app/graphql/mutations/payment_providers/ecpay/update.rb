# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Ecpay
      class Update < Base
        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateEcpayPaymentProvider"
        description "Update ECPay payment provider"

        input_object_class Types::PaymentProviders::UpdateInput

        type Types::PaymentProviders::Ecpay
      end
    end
  end
end
