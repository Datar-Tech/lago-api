# frozen_string_literal: true

module PaymentProviders
  class EcpayProvider < BaseProvider
    PRODUCTION_ECPG_URL      = "https://ecpg.ecpay.com.tw"
    STAGING_ECPG_URL         = "https://ecpg-stage.ecpay.com.tw"
    PRODUCTION_ECPAYMENT_URL = "https://ecpayment.ecpay.com.tw"
    STAGING_ECPAYMENT_URL    = "https://ecpayment-stage.ecpay.com.tw"

    PROCESSING_STATUSES = %w[].freeze
    SUCCESS_STATUSES    = %w[1].freeze
    FAILED_STATUSES     = %w[0].freeze

    validates :merchant_id, presence: true
    validates :hash_key, presence: true
    validates :hash_iv, presence: true

    secrets_accessors :hash_key, :hash_iv
    settings_accessors :merchant_id, :sandbox

    def sandbox?
      ActiveModel::Type::Boolean.new.cast(sandbox)
    end

    def ecpg_base_url
      sandbox? ? STAGING_ECPG_URL : PRODUCTION_ECPG_URL
    end

    def ecpayment_base_url
      sandbox? ? STAGING_ECPAYMENT_URL : PRODUCTION_ECPAYMENT_URL
    end

    def payment_type
      "ecpay"
    end
  end
end
