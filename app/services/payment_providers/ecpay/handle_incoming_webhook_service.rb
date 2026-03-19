# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    class HandleIncomingWebhookService < BaseService
      Result = BaseResult[:event]

      def initialize(organization_id:, body:, code: nil)
        @organization_id = organization_id
        @body = body
        @code = code
        super
      end

      def call
        payment_provider_result = PaymentProviders::FindService.call(
          organization_id:,
          code:,
          payment_provider_type: "ecpay"
        )
        return payment_provider_result unless payment_provider_result.success?

        parsed = JSON.parse(body)
        unless parsed["TransCode"] == 1
          return result.service_failure!(code: "webhook_error", message: "TransCode != 1")
        end

        PaymentProviders::Ecpay::HandleEventJob.perform_later(
          organization: Organization.find(organization_id),
          event: body
        )

        result.event = body
        result
      rescue JSON::ParserError
        result.service_failure!(code: "webhook_error", message: "Invalid JSON")
      end

      private

      attr_reader :organization_id, :body, :code
    end
  end
end
