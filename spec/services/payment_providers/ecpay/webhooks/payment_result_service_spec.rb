# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::Webhooks::PaymentResultService do
  let(:organization) { create(:organization) }
  let(:ecpay_provider) { create(:ecpay_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:ecpay_customer) { create(:ecpay_customer, customer:, payment_provider: ecpay_provider) }
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:payment) do
    create(:payment,
      payable: invoice,
      payment_provider: ecpay_provider,
      payment_provider_customer: ecpay_customer,
      provider_payment_id: "2403190000000001")
  end

  let(:trade_no) { "2403190000000001" }
  let(:merchant_trade_no) { "INV20240319120000" }

  def build_event_json(rtn_code:)
    data = {
      "RtnCode" => rtn_code,
      "RtnMsg" => rtn_code == 1 ? "Success" : "Failed",
      "TradeNo" => trade_no,
      "MerchantTradeNo" => merchant_trade_no
    }

    encrypted = Lago::EcpayAes.encrypt(
      data.to_json,
      ecpay_provider.hash_key,
      ecpay_provider.hash_iv
    )

    {"TransCode" => 1, "Data" => encrypted}.to_json
  end

  before { payment }

  describe "#call" do
    context "when payment succeeds" do
      it "updates payment status to succeeded" do
        result = described_class.call(
          organization_id: organization.id,
          event_json: build_event_json(rtn_code: 1)
        )

        expect(result).to be_success

        payment.reload
        expect(payment.status).to eq("1")
        expect(payment.payable_payment_status).to eq("succeeded")
      end
    end

    context "when payment fails" do
      it "updates payment status to failed" do
        result = described_class.call(
          organization_id: organization.id,
          event_json: build_event_json(rtn_code: 0)
        )

        expect(result).to be_success

        payment.reload
        expect(payment.status).to eq("0")
        expect(payment.payable_payment_status).to eq("failed")
      end
    end

    context "when payment not found" do
      let(:trade_no) { "nonexistent" }

      it "returns success without updating" do
        result = described_class.call(
          organization_id: organization.id,
          event_json: build_event_json(rtn_code: 1)
        )

        expect(result).to be_success
      end
    end
  end
end
