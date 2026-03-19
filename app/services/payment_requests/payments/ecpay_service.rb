# frozen_string_literal: true

module PaymentRequests
  module Payments
    class EcpayService < BaseService
      include Customers::PaymentProviderFinder
      include Updatable

      PROVIDER_NAME = "ECPay"

      def initialize(payable = nil)
        @payable = payable

        super(nil)
      end

      def create
        result.payable = payable
        return result.not_found_failure!(resource: "ecpay_customer") if customer&.ecpay_customer&.provider_customer_id.blank?
        return result unless should_process_payment?

        unless payable.total_amount_cents.positive?
          update_payable_payment_status(payment_status: :succeeded)
          return result
        end

        payable.increment_payment_attempts!

        payment = Payment.new(
          organization_id: payable.organization_id,
          payable: payable,
          customer: customer,
          payment_provider_id: ecpay_payment_provider.id,
          payment_provider_customer_id: customer.ecpay_customer.id,
          amount_cents: payable.total_amount_cents,
          amount_currency: payable.currency&.upcase
        )

        create_result = PaymentProviders::Ecpay::Payments::CreateService.call(
          payment: payment,
          reference: "Overdue invoices",
          metadata: {
            lago_customer_id: customer.id,
            lago_payable_id: payable.id,
            lago_payable_type: payable.class.name,
            payment_type: "one-time"
          }
        )

        payment = create_result.payment

        payable_payment_status = ecpay_payment_provider.determine_payment_status(payment.status)
        update_payable_payment_status(payment_status: payable_payment_status)
        update_invoices_payment_status(payment_status: payable_payment_status)
        update_invoices_paid_amount_cents(payment_status: payable_payment_status)
        reset_customer_dunning_campaign_status(payable_payment_status)

        result.payment = payment
        result
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      def update_payment_status(provider_payment_id:, status:, metadata: {})
        payment = if metadata[:payment_type] == "one-time"
          create_payment(provider_payment_id:, metadata:)
        else
          Payment.find_by(provider_payment_id:)
        end
        return result.not_found_failure!(resource: "ecpay_payment") unless payment

        result.payment = payment
        result.payable = payment.payable
        return result if payment.payable.payment_succeeded?

        payment.status = status

        payable_payment_status = payment.payment_provider&.determine_payment_status(payment.status)
        payment.payable_payment_status = payable_payment_status
        payment.save!

        update_payable_payment_status(payment_status: payable_payment_status)
        update_invoices_payment_status(payment_status: payable_payment_status)
        update_invoices_paid_amount_cents(payment_status: payable_payment_status)
        reset_customer_dunning_campaign_status(payable_payment_status)

        PaymentRequestMailer.with(payment_request: payment.payable).requested.deliver_later if result.payable.payment_failed?

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue BaseService::FailedResult => e
        result.fail_with_error!(e)
      end

      private

      attr_accessor :payable

      delegate :organization, :customer, to: :payable

      def should_process_payment?
        return false if payable.payment_succeeded?
        return false if ecpay_payment_provider.blank?

        !!customer&.ecpay_customer&.provider_customer_id
      end

      def ecpay_payment_provider
        @ecpay_payment_provider ||= payment_provider(customer)
      end

      def update_payable_payment_status(payment_status:, deliver_webhook: true)
        UpdateService.call(
          payable: result.payable,
          params: {
            payment_status:,
            ready_for_payment_processing: !payment_status_succeeded?(payment_status)
          },
          webhook_notification: deliver_webhook
        ).raise_if_error!
      end

      def update_invoices_payment_status(payment_status:, deliver_webhook: true)
        result.payable.invoices.each do |invoice|
          Invoices::UpdateService.call(
            invoice: invoice,
            params: {
              payment_status:,
              ready_for_payment_processing: !payment_status_succeeded?(payment_status)
            },
            webhook_notification: deliver_webhook
          ).raise_if_error!
        end
      end

      def payment_status_succeeded?(payment_status)
        payment_status.to_sym == :succeeded
      end

      def create_payment(provider_payment_id:, metadata:)
        @payable = PaymentRequest.find(metadata[:lago_payable_id])

        payable.increment_payment_attempts!

        Payment.new(
          organization_id: payable.organization_id,
          payable: payable,
          customer: customer,
          payment_provider_id: ecpay_payment_provider.id,
          payment_provider_customer_id: customer.ecpay_customer.id,
          amount_cents: payable.total_amount_cents,
          amount_currency: payable.currency&.upcase,
          provider_payment_id: provider_payment_id
        )
      end

      def deliver_error_webhook(ecpay_error)
        DeliverErrorWebhookService.call_async(payable, {
          provider_customer_id: customer.ecpay_customer.provider_customer_id,
          provider_error: {
            message: ecpay_error.message,
            error_code: ecpay_error.error_code
          }
        })
      end

      def reset_customer_dunning_campaign_status(payment_status)
        return unless payment_status_succeeded?(payment_status)
        return unless payable.try(:dunning_campaign)

        customer.reset_dunning_campaign!
      end
    end
  end
end
