# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::HandleEventService do
  let(:organization) { create(:organization) }
  let(:ecpay_provider) { create(:ecpay_provider, organization:) }
  let(:event_json) { {TransCode: 1, Data: "encrypted"}.to_json }

  before { ecpay_provider }

  describe "#call" do
    it "delegates to PaymentResultService" do
      allow(PaymentProviders::Ecpay::Webhooks::PaymentResultService).to receive(:call!)
        .and_return(BaseService::Result.new)

      result = described_class.call(organization:, event_json:)

      expect(result).to be_success
      expect(PaymentProviders::Ecpay::Webhooks::PaymentResultService).to have_received(:call!)
        .with(organization_id: organization.id, event_json:)
    end
  end
end
