# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::Payments::CreateService do
  let(:organization) { create(:organization) }
  let(:ecpay_provider) { create(:ecpay_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:ecpay_customer) do
    create(:ecpay_customer, customer:, payment_provider: ecpay_provider).tap do |ec|
      ec.merchant_member_id = "M-test1234"
      ec.card_id = "BIND123456"
      ec.save!
    end
  end

  let(:invoice) { create(:invoice, organization:, customer:, invoice_type: :subscription) }
  let(:payment) do
    create(:payment,
      payable: invoice,
      payment_provider: ecpay_provider,
      payment_provider_customer: ecpay_customer,
      provider_payment_id: nil)
  end

  let(:reference) { "ref_123" }
  let(:metadata) { {} }

  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:response) { instance_double(Net::HTTPOK) }
  let(:endpoint) { "#{ecpay_provider.ecpg_base_url}/Merchant/CreatePaymentWithCardID" }

  let(:trade_no) { "2403190000000001" }

  let(:ecpay_success_response) do
    encrypted_data = Lago::EcpayAes.encrypt(
      {
        "RtnCode" => 1,
        "RtnMsg" => "Success",
        "TradeNo" => trade_no
      }.to_json,
      ecpay_provider.hash_key,
      ecpay_provider.hash_iv
    )

    {"TransCode" => 1, "Data" => encrypted_data}
  end

  let(:ecpay_3ds_response) do
    encrypted_data = Lago::EcpayAes.encrypt(
      {
        "RtnCode" => 1,
        "RtnMsg" => "Success",
        "TradeNo" => trade_no,
        "ThreeDURL" => "https://ecpay.com.tw/3ds/verify"
      }.to_json,
      ecpay_provider.hash_key,
      ecpay_provider.hash_iv
    )

    {"TransCode" => 1, "Data" => encrypted_data}
  end

  let(:ecpay_failure_response) do
    encrypted_data = Lago::EcpayAes.encrypt(
      {
        "RtnCode" => 10100058,
        "RtnMsg" => "Insufficient balance"
      }.to_json,
      ecpay_provider.hash_key,
      ecpay_provider.hash_iv
    )

    {"TransCode" => 1, "Data" => encrypted_data}
  end

  describe "#call" do
    before do
      allow(LagoHttpClient::Client).to receive(:new).with(endpoint).and_return(lago_client)
    end

    context "when payment succeeds" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_success_response.to_json)
      end

      it "returns success and updates payment" do
        result = described_class.call(payment:, reference:, metadata:)

        expect(result).to be_success
        expect(result.payment.provider_payment_id).to eq(trade_no)
        expect(result.payment.status).to eq("1")
      end

      it "persists the payment" do
        described_class.call(payment:, reference:, metadata:)

        payment.reload
        expect(payment.provider_payment_id).to eq(trade_no)
      end

      it "sends correct request with BindCardID" do
        described_class.call(payment:, reference:, metadata:)

        expect(lago_client).to have_received(:post_with_response) do |body, headers|
          data_json = Lago::EcpayAes.decrypt(body[:Data], ecpay_provider.hash_key, ecpay_provider.hash_iv)
          data = JSON.parse(data_json)
          expect(data["CardInfo"]["BindCardID"]).to eq("BIND123456")
          expect(data["OrderInfo"]["TotalAmount"]).to be_a(Integer)
          expect(data["OrderInfo"]["MerchantTradeNo"]).to start_with("INV")
          expect(headers["Content-Type"]).to eq("application/json")
        end
      end
    end

    context "when 3DS is triggered" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_3ds_response.to_json)
      end

      it "returns three_d_url" do
        result = described_class.call(payment:, reference:, metadata:)

        expect(result).to be_success
        expect(result.three_d_url).to eq("https://ecpay.com.tw/3ds/verify")
      end
    end

    context "when card is not bound" do
      let(:ecpay_customer) do
        create(:ecpay_customer, customer:, payment_provider: ecpay_provider).tap do |ec|
          ec.merchant_member_id = "M-test1234"
          ec.save!
        end
      end

      it "returns without calling ECPay API" do
        result = described_class.call(payment:, reference:, metadata:)

        expect(result).to be_success
        expect(result.payment).to eq(payment)
        expect(lago_client).not_to have_received(:post_with_response) if lago_client.respond_to?(:post_with_response)
      end

      it "enqueues error webhook" do
        expect { described_class.call(payment:, reference:, metadata:) }
          .to have_enqueued_job(SendWebhookJob)
          .with("payment_provider.error_occurred", invoice, hash_including(provider_error: hash_including(error_code: "card_not_bound")))
      end
    end

    context "when ECPay returns failure" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_failure_response.to_json)
      end

      it "saves the failed status" do
        result = described_class.call(payment:, reference:, metadata:)

        expect(result).to be_success
        expect(result.payment.status).to eq("10100058")
      end
    end

    context "when HTTP request fails" do
      before do
        allow(lago_client).to receive(:post_with_response)
          .and_raise(LagoHttpClient::HttpError.new(500, "Server Error", ""))
      end

      it "returns third party failure" do
        result = described_class.call(payment:, reference:, metadata:)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ThirdPartyFailure)
      end
    end
  end
end
