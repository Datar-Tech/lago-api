# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::EcpayService do
  let(:organization) { create(:organization) }
  let(:ecpay_provider) { create(:ecpay_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:ecpay_customer) { create(:ecpay_customer, customer:, payment_provider: ecpay_provider) }

  describe "#create" do
    it "returns the ecpay_customer" do
      service = described_class.new(ecpay_customer)
      result = service.create

      expect(result).to be_success
      expect(result.ecpay_customer).to eq(ecpay_customer)
    end
  end

  describe "#update" do
    it "returns success" do
      service = described_class.new(ecpay_customer)
      result = service.update

      expect(result).to be_success
    end
  end

  describe "#generate_checkout_url" do
    it "returns not allowed failure" do
      service = described_class.new(ecpay_customer)
      result = service.generate_checkout_url

      expect(result).not_to be_success
      expect(result.error.code).to eq("feature_not_supported")
    end
  end
end
