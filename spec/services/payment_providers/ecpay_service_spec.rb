# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::EcpayService do
  subject(:ecpay_service) { described_class.new(membership.user) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:code) { "code_1" }
  let(:name) { "Name 1" }
  let(:merchant_id) { "3002607" }
  let(:hash_key) { "pwFHCqoQZGmho4w6" }
  let(:hash_iv) { "EkRm7iFT261dpevs" }
  let(:sandbox) { true }

  describe ".create_or_update" do
    it "creates an ecpay provider" do
      expect do
        ecpay_service.create_or_update(
          organization:,
          code:,
          name:,
          merchant_id:,
          hash_key:,
          hash_iv:,
          sandbox:
        )
      end.to change(PaymentProviders::EcpayProvider, :count).by(1)
    end

    it "returns the ecpay provider in the result" do
      result = ecpay_service.create_or_update(
        organization:,
        code:,
        name:,
        merchant_id:,
        hash_key:,
        hash_iv:,
        sandbox:
      )

      expect(result).to be_success
      expect(result.ecpay_provider).to be_a(PaymentProviders::EcpayProvider)
      expect(result.ecpay_provider.merchant_id).to eq(merchant_id)
      expect(result.ecpay_provider.hash_key).to eq(hash_key)
      expect(result.ecpay_provider.hash_iv).to eq(hash_iv)
      expect(result.ecpay_provider.sandbox?).to be(true)
      expect(result.ecpay_provider.code).to eq(code)
      expect(result.ecpay_provider.name).to eq(name)
    end

    context "when code was changed" do
      let(:new_code) { "updated_code_1" }
      let(:ecpay_customer) { create(:ecpay_customer, payment_provider:, customer:) }
      let(:customer) { create(:customer, organization:) }

      let(:payment_provider) do
        create(
          :ecpay_provider,
          organization:,
          code:,
          name:
        )
      end

      before { ecpay_customer }

      it "updates payment provider codes of all customers" do
        result = ecpay_service.create_or_update(
          id: payment_provider.id,
          organization:,
          code: new_code,
          name:,
          merchant_id:,
          hash_key:,
          hash_iv:
        )

        expect(result).to be_success
        expect(result.ecpay_provider.customers.first.payment_provider_code).to eq(new_code)
      end
    end

    context "when organization already has an ecpay provider" do
      let(:ecpay_provider) do
        create(:ecpay_provider, organization:, code:)
      end

      before { ecpay_provider }

      it "updates the existing provider" do
        new_merchant_id = "9999999"
        new_hash_key = "newHashKey1234567"
        new_hash_iv = "newHashIV12345678"

        result = ecpay_service.create_or_update(
          organization:,
          code:,
          name:,
          merchant_id: new_merchant_id,
          hash_key: new_hash_key,
          hash_iv: new_hash_iv,
          sandbox: false
        )

        expect(result).to be_success
        expect(result.ecpay_provider.id).to eq(ecpay_provider.id)
        expect(result.ecpay_provider.merchant_id).to eq(new_merchant_id)
        expect(result.ecpay_provider.hash_key).to eq(new_hash_key)
        expect(result.ecpay_provider.hash_iv).to eq(new_hash_iv)
        expect(result.ecpay_provider.sandbox?).to be(false)
      end
    end

    context "with validation error" do
      it "returns an error result" do
        result = ecpay_service.create_or_update(
          organization:
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:merchant_id]).to eq(["value_is_mandatory"])
        expect(result.error.messages[:hash_key]).to eq(["value_is_mandatory"])
        expect(result.error.messages[:hash_iv]).to eq(["value_is_mandatory"])
      end
    end
  end
end
