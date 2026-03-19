# frozen_string_literal: true

module PaymentProviderCustomers
  class EcpayCustomer < BaseCustomer
    # card_id = BindCardID (ECPay token after card binding)
    settings_accessors :card_id, :card_last_four, :card_first_six,
      :card_type, :merchant_member_id

    def require_provider_payment_id?
      false
    end

    def card_bound?
      card_id.present?
    end
  end
end
