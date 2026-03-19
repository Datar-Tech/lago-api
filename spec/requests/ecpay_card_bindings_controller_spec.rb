# frozen_string_literal: true

require "rails_helper"

RSpec.describe EcpayCardBindingsController do
  let(:organization) { create(:organization) }
  let(:ecpay_provider) { create(:ecpay_provider, organization:) }
  let(:customer) { create(:customer, organization:, external_id: "cust_123") }
  let(:ecpay_customer) { create(:ecpay_customer, customer:, payment_provider: ecpay_provider) }

  before { ecpay_provider }

  describe "POST /ecpay/card_bindings/:organization_id" do
    let(:bind_result) { BaseService::Result.new }

    before do
      customer
      bind_result.token_url = "https://ecpay.example.com/token"

      allow(PaymentProviders::Ecpay::Customers::BindCardService)
        .to receive(:call)
        .and_return(bind_result)
    end

    it "returns token_url" do
      post(
        "/ecpay/card_bindings/#{organization.id}",
        params: {external_customer_id: "cust_123"}
      )

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["token_url"]).to eq("https://ecpay.example.com/token")
    end

    context "when service fails" do
      before do
        bind_result.service_failure!(code: "bind_error", message: "failed")
      end

      it "returns bad_request" do
        post(
          "/ecpay/card_bindings/#{organization.id}",
          params: {external_customer_id: "cust_123"}
        )

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "POST /ecpay/card_bindings/:organization_id/callback" do
    let(:confirm_result) { BaseService::Result.new }

    before do
      allow(PaymentProviders::Ecpay::Customers::ConfirmBindService)
        .to receive(:call)
        .and_return(confirm_result)
    end

    it "redirects to success URL on success" do
      post(
        "/ecpay/card_bindings/#{organization.id}/callback",
        params: {ResultData: "encrypted_data"}
      )

      expect(response).to have_http_status(:redirect)
    end

    context "when confirm fails" do
      before do
        confirm_result.service_failure!(code: "confirm_error", message: "failed")
      end

      it "redirects to failure URL" do
        post(
          "/ecpay/card_bindings/#{organization.id}/callback",
          params: {ResultData: "encrypted_data"}
        )

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
