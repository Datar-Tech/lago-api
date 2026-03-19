# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Ecpay::Customers::CreateService do
  let(:create_service) { described_class.new(customer:, payment_provider_id:, params:, async:) }

  let(:customer) { create(:customer) }
  let(:ecpay_provider) { create(:ecpay_provider, organization: customer.organization) }
  let(:payment_provider_id) { ecpay_provider.id }
  let(:params) { {sync_with_provider: true} }
  let(:async) { true }

  describe ".call" do
    it "creates a payment_provider_customer" do
      result = create_service.call

      expect(result).to be_success
      expect(result.provider_customer).to be_present
      expect(result.provider_customer).to be_a(PaymentProviderCustomers::EcpayCustomer)
      expect(result.provider_customer.provider_customer_id).to be_nil
    end

    it "sets the payment_provider_id" do
      result = create_service.call

      expect(result.provider_customer.payment_provider_id).to eq(ecpay_provider.id)
    end

    context "when ecpay_customer already exists" do
      let!(:existing) do
        create(:ecpay_customer, customer:, payment_provider: ecpay_provider)
      end

      it "reuses the existing record" do
        expect { create_service.call }.not_to change(PaymentProviderCustomers::EcpayCustomer, :count)

        result = create_service.call
        expect(result.provider_customer.id).to eq(existing.id)
      end
    end
  end
end
