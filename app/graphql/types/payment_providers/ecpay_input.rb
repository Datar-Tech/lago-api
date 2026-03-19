# frozen_string_literal: true

module Types
  module PaymentProviders
    class EcpayInput < BaseInputObject
      description "ECPay input arguments"

      argument :code, String, required: true
      argument :hash_iv, String, required: true
      argument :hash_key, String, required: true
      argument :merchant_id, String, required: true
      argument :name, String, required: true
      argument :sandbox, Boolean, required: false, default_value: false
    end
  end
end
