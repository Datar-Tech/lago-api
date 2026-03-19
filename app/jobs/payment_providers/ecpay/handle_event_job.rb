# frozen_string_literal: true

module PaymentProviders
  module Ecpay
    class HandleEventJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :providers
        end
      end

      def perform(organization:, event:)
        PaymentProviders::Ecpay::HandleEventService.call!(
          organization:,
          event_json: event
        )
      end
    end
  end
end
