# frozen_string_literal: true

module PaymentProviders
  class EcpayService < BaseService
    def create_or_update(**args)
      payment_provider_result = PaymentProviders::FindService.call(
        organization_id: args[:organization].id,
        code: args[:code],
        id: args[:id],
        payment_provider_type: "ecpay"
      )

      ecpay_provider = if payment_provider_result.success?
        payment_provider_result.payment_provider
      else
        PaymentProviders::EcpayProvider.new(
          organization_id: args[:organization].id,
          code: args[:code]
        )
      end

      old_code = ecpay_provider.code

      ecpay_provider.merchant_id = args[:merchant_id] if args.key?(:merchant_id)
      ecpay_provider.hash_key = args[:hash_key] if args.key?(:hash_key)
      ecpay_provider.hash_iv = args[:hash_iv] if args.key?(:hash_iv)
      ecpay_provider.sandbox = args[:sandbox] if args.key?(:sandbox)
      ecpay_provider.code = args[:code] if args.key?(:code)
      ecpay_provider.name = args[:name] if args.key?(:name)
      ecpay_provider.save!

      if payment_provider_code_changed?(ecpay_provider, old_code, args)
        ecpay_provider.customers.update_all(payment_provider_code: args[:code]) # rubocop:disable Rails/SkipsModelValidations
      end

      result.ecpay_provider = ecpay_provider
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end
  end
end
