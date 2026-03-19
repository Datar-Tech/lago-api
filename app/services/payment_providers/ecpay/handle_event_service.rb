# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    class HandleEventService < BaseService
      def initialize(organization:, event_json:)
        @organization = organization
        @event_json = event_json
        super
      end

      def call
        PaymentProviders::Ecpay::Webhooks::PaymentResultService.call!(
          organization_id: organization.id,
          event_json:
        )

        result
      end

      private

      attr_reader :organization, :event_json
    end
  end
end
