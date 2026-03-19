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

    render json: {
      token: result.token,
      token_url: result.token_url,
      merchant_member_id: result.merchant_member_id,
      merchant_trade_no: result.merchant_trade_no
    }
  end

  # POST /ecpay/card_bindings/:organization_id/create_bind_card
  def create_bind_card
    result = PaymentProviders::Ecpay::Customers::CreateBindCardService.call(
      payment_provider: ecpay_provider,
      bind_card_pay_token: params[:bind_card_pay_token],
      merchant_member_id: params[:merchant_member_id]
    )

    return render json: {success: false, error: result.error&.message}, status: :bad_request unless result.success?

    render json: {
      success: true,
      data: result.data,
      three_d_url: result.three_d_url
    }
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
