# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::Customers::BindCardService do
  subject(:service) { described_class.new(customer:, payment_provider:) }

  let(:organization) { create(:organization) }
  let(:payment_provider) { create(:ecpay_provider, organization:) }
  let(:customer) { create(:customer, organization:, external_id: "cust_abc12345") }
  let(:ecpay_customer) { create(:ecpay_customer, customer:, payment_provider:) }

  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:response) { instance_double(Net::HTTPOK) }
  let(:endpoint) { "#{payment_provider.ecpg_base_url}/Merchant/GetTokenbyBindingCard" }

  let(:token_value) { "abc123def456" }
  let(:token_url) { "https://ecpg-stage.ecpay.com.tw/Merchant/BindingCard?token=abc123" }

  let(:ecpay_success_response) do
    encrypted_data = Lago::EcpayAes.encrypt(
      {
        "RtnCode" => 1,
        "RtnMsg" => "Success",
        "Token" => token_value,
        "TokenURL" => token_url
      }.to_json,
      payment_provider.hash_key,
      payment_provider.hash_iv
    )

    {
      "TransCode" => 1,
      "Data" => encrypted_data
    }
  end

  let(:ecpay_failure_response) do
    encrypted_data = Lago::EcpayAes.encrypt(
      {
        "RtnCode" => 10200095,
        "RtnMsg" => "MerchantID is not valid"
      }.to_json,
      payment_provider.hash_key,
      payment_provider.hash_iv
    )

    {
      "TransCode" => 1,
      "Data" => encrypted_data
    }
  end

  before do
    ecpay_customer
    allow(LagoHttpClient::Client).to receive(:new).with(endpoint).and_return(lago_client)
  end

  describe "#call" do
    context "when bind card succeeds" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_success_response.to_json)
      end

      it "returns success with token and token_url" do
        result = service.call

        expect(result).to be_success
        expect(result.token).to eq(token_value)
        expect(result.token_url).to eq(token_url)
        expect(result.merchant_member_id).to eq("M-cust_abc")
        expect(result.merchant_trade_no).to start_with("BND")
      end

      it "updates ecpay_customer with merchant_member_id" do
        service.call

        ecpay_customer.reload
        expect(ecpay_customer.merchant_member_id).to eq("M-cust_abc")
      end

      it "sends correct request structure" do
        service.call

        expect(lago_client).to have_received(:post_with_response) do |body, headers|
          expect(body).to have_key(:MerchantID)
          expect(body).to have_key(:RqHeader)
          expect(body).to have_key(:Data)
          expect(headers["Content-Type"]).to eq("application/json")
        end
      end
    end

    context "when ECPay returns failure RtnCode" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_failure_response.to_json)
      end

      it "returns service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("bind_card_error")
      end
    end

    context "when HTTP request fails" do
      before do
        allow(lago_client).to receive(:post_with_response)
          .and_raise(LagoHttpClient::HttpError.new(500, "Internal Server Error", ""))
      end

      it "returns third party failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ThirdPartyFailure)
      end
    end

    context "when generate_trade_no" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_success_response.to_json)
      end

      it "generates a trade number with BND prefix and max 20 chars" do
        service.call

        expect(lago_client).to have_received(:post_with_response) do |body, _|
          data_json = Lago::EcpayAes.decrypt(body[:Data], payment_provider.hash_key, payment_provider.hash_iv)
          data = JSON.parse(data_json)
          trade_no = data["OrderInfo"]["MerchantTradeNo"]
          expect(trade_no).to start_with("BND")
          expect(trade_no.length).to be <= 20
        end
      end
    end
  end
end
