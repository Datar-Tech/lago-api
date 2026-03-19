# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::EcpayCustomer do
  subject(:ecpay_customer) { described_class.new(attributes) }

  let(:attributes) { {} }

  describe "#require_provider_payment_id?" do
    it { expect(ecpay_customer).not_to be_require_provider_payment_id }
  end

  describe "settings_accessors" do
    describe "#merchant_member_id" do
      before { ecpay_customer.merchant_member_id = "MEM123" }

      it "stores and retrieves merchant_member_id" do
        expect(ecpay_customer.merchant_member_id).to eq("MEM123")
      end
    end

    describe "#card_id" do
      before { ecpay_customer.card_id = "BIND_CARD_001" }

      it "stores and retrieves card_id" do
        expect(ecpay_customer.card_id).to eq("BIND_CARD_001")
      end
    end

    describe "#card_last_four" do
      before { ecpay_customer.card_last_four = "4242" }

      it "stores and retrieves card_last_four" do
        expect(ecpay_customer.card_last_four).to eq("4242")
      end
    end

    describe "#card_first_six" do
      before { ecpay_customer.card_first_six = "424242" }

      it "stores and retrieves card_first_six" do
        expect(ecpay_customer.card_first_six).to eq("424242")
      end
    end

    describe "#card_type" do
      before { ecpay_customer.card_type = "VISA" }

      it "stores and retrieves card_type" do
        expect(ecpay_customer.card_type).to eq("VISA")
      end
    end
  end

  describe "#card_bound?" do
    context "when card_id is present" do
      before { ecpay_customer.card_id = "BIND_CARD_001" }

      it "returns true" do
        expect(ecpay_customer.card_bound?).to be(true)
      end
    end

    context "when card_id is nil" do
      it "returns false" do
        expect(ecpay_customer.card_bound?).to be(false)
      end
    end

    context "when card_id is blank" do
      before { ecpay_customer.card_id = "" }

      it "returns false" do
        expect(ecpay_customer.card_bound?).to be(false)
      end
    end
  end
end
