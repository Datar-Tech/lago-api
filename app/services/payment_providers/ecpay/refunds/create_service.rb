# frozen_string_literal: true

# Thin wrapper: delegates to CreditNotes::Refunds::EcpayService
# which handles the actual ECPay DoAction API call.
#
# ECPay DoAction API:
#   Endpoint: {ecpayment_base_url}/1.0.0/Credit/DoAction
#   Actions:  C=請款, R=退款, E=取消, N=放棄
#   Note:     DoAction only works in production (not sandbox)

module PaymentProviders
  module Ecpay
    module Refunds
      class CreateService < BaseService
        def initialize(credit_note:)
          @credit_note = credit_note
          super
        end

        def call
          CreditNotes::Refunds::EcpayService.new(credit_note).create
        end

        private

        attr_reader :credit_note
      end
    end
  end
end
