# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::EcpayProvider do
  subject(:ecpay_provider) { build(:ecpay_provider, attributes) }

  let(:attributes) { {} }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:merchant_id) }
  it { is_expected.to validate_presence_of(:hash_key) }
  it { is_expected.to validate_presence_of(:hash_iv) }

  describe "validations" do
    it "validates uniqueness of the code" do
      expect(ecpay_provider).to validate_uniqueness_of(:code).scoped_to(:organization_id)
    end
  end

  describe "#hash_key" do
    let(:hash_key) { "pwFHCqoQZGmho4w6" }

    before { ecpay_provider.hash_key = hash_key }

    it "returns the hash key" do
      expect(ecpay_provider.hash_key).to eq(hash_key)
    end
  end

  describe "#hash_iv" do
    let(:hash_iv) { "EkRm7iFT261dpevs" }

    before { ecpay_provider.hash_iv = hash_iv }

    it "returns the hash iv" do
      expect(ecpay_provider.hash_iv).to eq(hash_iv)
    end
  end

  describe "#merchant_id" do
    let(:merchant_id) { "3002607" }

    before { ecpay_provider.merchant_id = merchant_id }

    it "returns the merchant id" do
      expect(ecpay_provider.merchant_id).to eq(merchant_id)
    end
  end

  describe "#sandbox?" do
    context "when sandbox is true" do
      before { ecpay_provider.sandbox = true }

      it "returns true" do
        expect(ecpay_provider.sandbox?).to be(true)
      end
    end

    context "when sandbox is false" do
      before { ecpay_provider.sandbox = false }

      it "returns false" do
        expect(ecpay_provider.sandbox?).to be(false)
      end
    end

    context "when sandbox is string 'true'" do
      before { ecpay_provider.sandbox = "true" }

      it "casts to true" do
        expect(ecpay_provider.sandbox?).to be(true)
      end
    end

    context "when sandbox is nil" do
      before { ecpay_provider.sandbox = nil }

      it "returns falsy" do
        expect(ecpay_provider.sandbox?).to be_falsey
      end
    end
  end

  describe "#ecpg_base_url" do
    context "when sandbox" do
      before { ecpay_provider.sandbox = true }

      it "returns staging URL" do
        expect(ecpay_provider.ecpg_base_url).to eq("https://ecpg-stage.ecpay.com.tw")
      end
    end

    context "when production" do
      before { ecpay_provider.sandbox = false }

      it "returns production URL" do
        expect(ecpay_provider.ecpg_base_url).to eq("https://ecpg.ecpay.com.tw")
      end
    end
  end

  describe "#ecpayment_base_url" do
    context "when sandbox" do
      before { ecpay_provider.sandbox = true }

      it "returns staging URL" do
        expect(ecpay_provider.ecpayment_base_url).to eq("https://ecpayment-stage.ecpay.com.tw")
      end
    end

    context "when production" do
      before { ecpay_provider.sandbox = false }

      it "returns production URL" do
        expect(ecpay_provider.ecpayment_base_url).to eq("https://ecpayment.ecpay.com.tw")
      end
    end
  end

  describe "#payment_type" do
    it "returns ecpay" do
      expect(ecpay_provider.payment_type).to eq("ecpay")
    end
  end

  describe "#determine_payment_status" do
    it "returns :succeeded for status '1'" do
      expect(ecpay_provider.determine_payment_status("1")).to eq(:succeeded)
    end

    it "returns :failed for status '0'" do
      expect(ecpay_provider.determine_payment_status("0")).to eq(:failed)
    end

    it "returns the raw status for unknown values" do
      expect(ecpay_provider.determine_payment_status("unknown")).to eq("unknown")
    end
  end
end
