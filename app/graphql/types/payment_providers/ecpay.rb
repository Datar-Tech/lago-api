# frozen_string_literal: true

module Types
  module PaymentProviders
    class Ecpay < Types::BaseObject
      graphql_name "EcpayProvider"

      field :code, String, null: false
      field :id, ID, null: false
      field :name, String, null: false

      field :merchant_id, String, null: false, permission: "organization:integrations:view"
      field :sandbox, Boolean, null: true, permission: "organization:integrations:view"
    end
  end
end
