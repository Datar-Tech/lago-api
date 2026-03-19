# frozen_string_literal: true

class EcpayCardBindingsController < ApplicationController
  # POST /ecpay/card_bindings/:organization_id
  def create
    customer = organization.customers.find_by!(external_id: params[:external_customer_id])

    result = PaymentProviders::Ecpay::Customers::BindCardService.call(
      customer:,
      payment_provider: ecpay_provider
    )

    return head(:bad_request) unless result.success?

    render json: {token_url: result.token_url}
  end

  # POST /ecpay/card_bindings/:organization_id/callback
  def callback
    result = PaymentProviders::Ecpay::Customers::ConfirmBindService.call(
      organization:,
      result_data: params[:ResultData]
    )

    if result.success?
      redirect_to ENV.fetch("ECPAY_SUCCESS_REDIRECT_URL", "/billing?card=bound"), allow_other_host: true
    else
      redirect_to ENV.fetch("ECPAY_FAILURE_REDIRECT_URL", "/billing?card=failed"), allow_other_host: true
    end
  end

  private

  def organization
    @organization ||= Organization.find_by!(id: params[:organization_id])
  end

  def ecpay_provider
    PaymentProviders::EcpayProvider.find_by!(organization:)
  end
end
