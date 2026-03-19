# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::EcpayService do
  let(:organization) { create(:organization) }
  let(:ecpay_provider) { create(:ecpay_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:ecpay_customer) { create(:ecpay_customer, customer:, payment_provider: ecpay_provider) }
  let(:invoice) { create(:invoice, organization:, customer:, status: :finalized) }
  let(:payment) do
    create(:payment,
      payable: invoice,
      payment_provider: ecpay_provider,
      payment_provider_customer: ecpay_customer,
      provider_payment_id: "2403190000000001",
      amount_cents: 3200,
      amount_currency: "TWD")
  end

  before { payment }

  describe "#update_payment_status" do
    let(:ecpay_payment) do
      PaymentProviders::Ecpay::Webhooks::PaymentResultService::EcpayPayment.new(
        id: "2403190000000001",
        status: status,
        metadata: {merchant_trade_no: "INV20240319120000"}
      )
    end

    context "when status is success (1)" do
      let(:status) { "1" }

      it "updates payment to succeeded" do
        result = described_class.new.update_payment_status(
          organization_id: organization.id,
          status:,
          ecpay_payment:
        )

        expect(result).to be_success
        expect(result.payment.status).to eq("1")
        expect(result.payment.payable_payment_status).to eq("succeeded")
      end
    end

    context "when status is failed (0)" do
      let(:status) { "0" }

      it "updates payment to failed" do
        result = described_class.new.update_payment_status(
          organization_id: organization.id,
          status:,
          ecpay_payment:
        )

        expect(result).to be_success
        expect(result.payment.status).to eq("0")
        expect(result.payment.payable_payment_status).to eq("failed")
      end
    end

    context "when payment not found" do
      let(:status) { "1" }
      let(:ecpay_payment) do
        PaymentProviders::Ecpay::Webhooks::PaymentResultService::EcpayPayment.new(
          id: "nonexistent",
          status: status,
          metadata: {}
        )
      end

      it "returns not found failure" do
        result = described_class.new.update_payment_status(
          organization_id: organization.id,
          status:,
          ecpay_payment:
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
      end
    end

    context "when invoice already succeeded" do
      let(:status) { "1" }

      before do
        invoice.update!(payment_status: :succeeded)
      end

      it "returns early without updating" do
        result = described_class.new.update_payment_status(
          organization_id: organization.id,
          status:,
          ecpay_payment:
        )

        expect(result).to be_success
        expect(payment.reload.status).to eq("pending")
      end
    end
  end
end
