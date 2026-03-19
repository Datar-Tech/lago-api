# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::Customers::CreateBindCardService do
  subject(:service) do
    described_class.new(
      payment_provider:,
      bind_card_pay_token: "test_pay_token_abc123",
      merchant_member_id: "M-cust_abc"
    )
  end

  let(:organization) { create(:organization) }
  let(:payment_provider) { create(:ecpay_provider, organization:) }

  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:response) { instance_double(Net::HTTPOK) }
  let(:endpoint) { "#{payment_provider.ecpg_base_url}/Merchant/CreateBindCard" }

  let(:ecpay_success_response) do
    encrypted_data = Lago::EcpayAes.encrypt(
      {
        "RtnCode" => 1,
        "RtnMsg" => "Success",
        "BindCardID" => "bind_card_id_123",
        "ThreeDInfo" => {
          "ThreeDURL" => "https://ecpg-stage.ecpay.com.tw/3d/verify?token=xyz"
        }
      }.to_json,
      payment_provider.hash_key,
      payment_provider.hash_iv
    )

    {
      "TransCode" => 1,
      "Data" => encrypted_data
    }
  end

  let(:ecpay_success_no_3d_response) do
    encrypted_data = Lago::EcpayAes.encrypt(
      {
        "RtnCode" => 1,
        "RtnMsg" => "Success",
        "BindCardID" => "bind_card_id_456",
        "ThreeDInfo" => {
          "ThreeDURL" => ""
        }
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
        "RtnMsg" => "BindCardPayToken is invalid"
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
    allow(LagoHttpClient::Client).to receive(:new).with(endpoint).and_return(lago_client)
  end

  describe "#call" do
    context "when create bind card succeeds with 3D" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_success_response.to_json)
      end

      it "returns success with three_d_url" do
        result = service.call

        expect(result).to be_success
        expect(result.three_d_url).to eq("https://ecpg-stage.ecpay.com.tw/3d/verify?token=xyz")
        expect(result.data["BindCardID"]).to eq("bind_card_id_123")
      end
    end

    context "when create bind card succeeds without 3D" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_success_no_3d_response.to_json)
      end

      it "returns success with empty three_d_url" do
        result = service.call

        expect(result).to be_success
        expect(result.three_d_url).to eq("")
        expect(result.data["BindCardID"]).to eq("bind_card_id_456")
      end
    end

    context "when ECPay returns failure" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(ecpay_failure_response.to_json)
      end

      it "returns service failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("create_bind_card_error")
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
  end
end
