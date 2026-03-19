# frozen_string_literal: true

module CreditNotes
  module Refunds
    class EcpayService < BaseService
      include Customers::PaymentProviderFinder

      def initialize(credit_note = nil)
        @credit_note = credit_note
        super
      end

      def create
        result.credit_note = credit_note
        return result unless should_process_refund?

        ecpay_result = create_ecpay_refund

        refund = Refund.new(
          organization_id: credit_note.organization_id,
          credit_note:,
          payment:,
          payment_provider: payment.payment_provider,
          payment_provider_customer: payment_provider_customer(customer),
          amount_cents: credit_note.refund_amount_cents,
          amount_currency: credit_note.credit_amount_currency,
          status: ecpay_result[:success] ? "succeeded" : "failed",
          provider_refund_id: ecpay_result.dig(:data, "TradeNo") || payment.provider_payment_id
        )
        refund.save!

        update_credit_note_status(refund.status)
        Utils::SegmentTrack.refund_status_changed(refund.status, credit_note.id, organization.id)

        if refund.status == "failed"
          deliver_error_webhook(
            message: ecpay_result[:rtn_msg] || "ECPay refund failed",
            code: ecpay_result[:rtn_code]&.to_s
          )
        end

        result.refund = refund
        result
      rescue => e
        deliver_error_webhook(message: e.message, code: "ecpay_refund_error")
        update_credit_note_status(:failed)
        raise
      end

      def update_status(provider_refund_id:, status:, metadata: {})
        refund = Refund.find_by(provider_refund_id:)
        return result.not_found_failure!(resource: "ecpay_refund") unless refund

        result.refund = refund
        @credit_note = result.credit_note = refund.credit_note
        return result if refund.credit_note.succeeded?

        refund.update!(status:)
        update_credit_note_status(status)

        if status.to_sym == :failed
          deliver_error_webhook(message: "Payment refund failed", code: nil)
          result.service_failure!(code: "refund_failed", message: "Refund failed to perform")
        end

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_accessor :credit_note

      delegate :organization, :customer, :invoice, to: :credit_note

      def should_process_refund?
        return false if !credit_note.refunded? || credit_note.succeeded? || invoice.payment_dispute_lost_at?

        payment.present?
      end

      def payment
        @payment ||= credit_note.invoice.payments.order(created_at: :desc).first
      end

      def ecpay_provider
        @ecpay_provider ||= payment.payment_provider
      end

      # Call ECPay DoAction API (Action=R for refund)
      # Endpoint: ecpayment domain /1.0.0/Credit/DoAction
      def create_ecpay_refund
        data = {
          PlatformID: ecpay_provider.merchant_id,
          MerchantID: ecpay_provider.merchant_id,
          MerchantTradeNo: payment.provider_payment_id,
          TradeNo: payment.provider_payment_id,
          Action: "R",
          TotalAmount: credit_note.refund_amount_cents,
          CustomField: ""
        }

        request_body = Lago::EcpayAes.build_request(
          ecpay_provider.merchant_id, data,
          ecpay_provider.hash_key, ecpay_provider.hash_iv
        )

        response = http_client.post_with_response(
          request_body,
          {"Content-Type" => "application/json"}
        )

        Lago::EcpayAes.parse_response(
          JSON.parse(response.body),
          ecpay_provider.hash_key, ecpay_provider.hash_iv
        )
      rescue LagoHttpClient::HttpError => e
        {success: false, rtn_code: e.error_code, rtn_msg: e.error_body}
      end

      def http_client
        LagoHttpClient::Client.new("#{ecpay_provider.ecpayment_base_url}/1.0.0/Credit/DoAction")
      end

      def deliver_error_webhook(message:, code:)
        SendWebhookJob.perform_later(
          "credit_note.provider_refund_failure",
          credit_note,
          provider_customer_id: payment_provider_customer(customer)&.provider_customer_id,
          provider_error: {message:, error_code: code}
        )
      end

      def update_credit_note_status(status)
        credit_note.refund_status = status
        credit_note.refunded_at = Time.current if credit_note.succeeded?
        credit_note.save!
      end
    end
  end
end
