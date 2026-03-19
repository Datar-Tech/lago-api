# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::Customers::ConfirmBindService do
  let(:organization) { create(:organization) }
  let(:payment_provider) { create(:ecpay_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:ecpay_customer) do
    create(:ecpay_customer, customer:, payment_provider:).tap do |ec|
      ec.merchant_member_id = "M-test1234"
      ec.save!
    end
  end

  let(:merchant_member_id) { "M-test1234" }
  let(:bind_card_id) { "12345678" }
  let(:card_4no) { "1234" }
  let(:card_6no) { "123456" }

  let(:success_data) do
    {
      "RtnCode" => 1,
      "RtnMsg" => "Success",
      "MerchantMemberID" => merchant_member_id,
      "BindCardID" => bind_card_id,
      "Card4No" => card_4no,
      "Card6No" => card_6no
    }
  end

  let(:failure_data) do
    {
      "RtnCode" => 10200095,
      "RtnMsg" => "Binding failed"
    }
  end

  def build_result_data(data, trans_code: 1)
    encrypted = Lago::EcpayAes.encrypt(
      data.to_json,
      payment_provider.hash_key,
      payment_provider.hash_iv
    )

    {
      "TransCode" => trans_code,
      "Data" => encrypted
    }.to_json
  end

  before { ecpay_customer }

  describe "#call" do
    context "when bind succeeds" do
      subject(:service) do
        described_class.new(organization:, result_data: build_result_data(success_data))
      end

      it "stores card info on ecpay_customer" do
        result = service.call

        expect(result).to be_success
        expect(result.ecpay_customer.card_id).to eq(bind_card_id)
        expect(result.ecpay_customer.card_last_four).to eq(card_4no)
        expect(result.ecpay_customer.card_first_six).to eq(card_6no)
        expect(result.ecpay_customer.merchant_member_id).to eq(merchant_member_id)
      end

      it "persists the card info" do
        service.call

        ecpay_customer.reload
        expect(ecpay_customer.card_id).to eq(bind_card_id)
        expect(ecpay_customer.card_bound?).to be(true)
      end
    end

    context "when TransCode fails" do
      subject(:service) do
        described_class.new(organization:, result_data: build_result_data(success_data, trans_code: 0))
      end

      it "returns service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("bind_failed")
      end
    end

    context "when RtnCode fails" do
      subject(:service) do
        described_class.new(organization:, result_data: build_result_data(failure_data))
      end

      it "returns service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("bind_failed")
      end
    end

    context "when merchant_member_id not found" do
      subject(:service) do
        wrong_data = success_data.merge("MerchantMemberID" => "M-notfound")
        described_class.new(organization:, result_data: build_result_data(wrong_data))
      end

      it "raises ActiveRecord::RecordNotFound" do
        expect { service.call }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
