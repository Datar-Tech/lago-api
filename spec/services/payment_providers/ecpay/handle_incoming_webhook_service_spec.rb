# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::HandleIncomingWebhookService do
  let(:organization) { create(:organization) }
  let(:ecpay_provider) { create(:ecpay_provider, organization:) }

  before { ecpay_provider }

  describe "#call" do
    context "when TransCode is 1" do
      let(:body) { {TransCode: 1, Data: "encrypted"}.to_json }

      it "enqueues HandleEventJob and returns event" do
        result = described_class.call(organization_id: organization.id, body:)

        expect(result).to be_success
        expect(result.event).to eq(body)
      end

      it "enqueues the job" do
        expect do
          described_class.call(organization_id: organization.id, body:)
        end.to have_enqueued_job(PaymentProviders::Ecpay::HandleEventJob)
      end
    end

    context "when TransCode is not 1" do
      let(:body) { {TransCode: 0, Data: "encrypted"}.to_json }

      it "returns service failure" do
        result = described_class.call(organization_id: organization.id, body:)

        expect(result).not_to be_success
        expect(result.error.code).to eq("webhook_error")
      end
    end

    context "when body is invalid JSON" do
      let(:body) { "not json" }

      it "returns service failure" do
        result = described_class.call(organization_id: organization.id, body:)

        expect(result).not_to be_success
        expect(result.error.code).to eq("webhook_error")
      end
    end

    context "when provider not found" do
      it "returns failure" do
        result = described_class.call(
          organization_id: organization.id,
          body: {TransCode: 1}.to_json,
          code: "nonexistent"
        )

        expect(result).not_to be_success
      end
    end
  end
end
