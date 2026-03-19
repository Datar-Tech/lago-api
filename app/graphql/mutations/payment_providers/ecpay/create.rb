# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Ecpay
      class Create < Base
        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "AddEcpayPaymentProvider"
        description "Add ECPay payment provider"

        input_object_class Types::PaymentProviders::EcpayInput

        type Types::PaymentProviders::Ecpay
      end
    end
  end
end
