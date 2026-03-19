# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::HandleEventJob do
  let(:result) { BaseService::Result.new }
  let(:organization) { create(:organization) }

  let(:ecpay_event) do
    {}
  end

  before do
    allow(PaymentProviders::Ecpay::HandleEventService)
      .to receive(:call)
      .and_return(result)
  end

  it "calls the handle event service" do
    described_class.perform_now(
      organization:,
      event: ecpay_event
    )

    expect(PaymentProviders::Ecpay::HandleEventService).to have_received(:call)
  end
end
