# frozen_string_literal: true

namespace :ecpay do
  desc "Setup E2E test data: Organization + EcpayProvider (sandbox) + Customer + EcpayCustomer"
  task setup_e2e: :environment do
    puts "=== ECPay E2E Setup ==="

    # 1. Find or create organization
    org = Organization.find_or_create_by!(name: "ECPay E2E Test") do |o|
      puts "  Creating organization..."
    end
    puts "  Organization: #{org.id} (#{org.name})"

    # Ensure BillingEntity exists
    BillingEntity.find_or_create_by!(id: org.id, organization: org) do |be|
      be.name = org.name
      be.code = "ecpay-e2e-test"
    end

    # 2. Create API key
    api_key = ApiKey.find_or_create_by!(organization: org)
    puts "  API Key: #{api_key.value}"

    # 3. Create EcpayProvider (sandbox)
    provider = PaymentProviders::EcpayProvider.find_or_initialize_by(organization: org)
    provider.code = "ecpay_sandbox" if provider.new_record?
    provider.name = "ECPay Sandbox"
    provider.merchant_id = "3002607"
    provider.hash_key = "pwFHCqoQZGmho4w6"
    provider.hash_iv = "EkRm7iFT261dpevs"
    provider.sandbox = true
    provider.save!
    puts "  EcpayProvider: #{provider.id} (sandbox=#{provider.sandbox?})"

    # 4. Create test customer
    customer = Customer.find_or_initialize_by(organization: org, external_id: "e2e_test_customer")
    customer.name = "E2E Test Customer"
    customer.email = "e2e@test.com"
    customer.currency = "TWD"
    customer.payment_provider = "ecpay"
    customer.payment_provider_code = provider.code
    customer.save!
    puts "  Customer: #{customer.id} (external_id: #{customer.external_id})"

    # 5. Create EcpayCustomer
    ecpay_customer = PaymentProviderCustomers::EcpayCustomer.find_or_initialize_by(customer: customer)
    ecpay_customer.payment_provider = provider
    ecpay_customer.organization_id = org.id
    ecpay_customer.save!
    puts "  EcpayCustomer: #{ecpay_customer.id}"

    puts ""
    puts "=== Ready for E2E Testing ==="
    puts "  Organization ID: #{org.id}"
    puts "  Customer external_id: e2e_test_customer"
    puts "  Card bound: #{ecpay_customer.card_bound? ? 'YES (' + ecpay_customer.card_id.to_s + ')' : 'NO'}"
    puts ""
    puts "  Test page URL: http://localhost:3000/ecpay_test.html"
    puts "  Or via ngrok:  <ngrok-url>/ecpay_test.html"
  end

  desc "Verify ECPay sandbox API connectivity by calling GetTokenbyBindingCard"
  task verify_connection: :environment do
    puts "=== ECPay Sandbox Connectivity Test ==="

    provider = PaymentProviders::EcpayProvider.find_by(sandbox: "true")
    unless provider
      puts "  ERROR: No sandbox EcpayProvider found. Run `rake ecpay:setup_e2e` first."
      exit 1
    end

    customer = Customer.find_by(organization: provider.organization, external_id: "e2e_test_customer")
    unless customer
      puts "  ERROR: No test customer found. Run `rake ecpay:setup_e2e` first."
      exit 1
    end

    puts "  Provider: #{provider.merchant_id} (sandbox)"
    puts "  Endpoint: #{provider.ecpg_base_url}/Merchant/GetTokenbyBindingCard"
    puts "  Calling ECPay API..."

    data = {
      MerchantID: provider.merchant_id,
      MerchantMemberID: "M-#{customer.external_id.first(8)}",
      OrderInfo: {
        MerchantTradeNo: "TST#{Time.now.strftime('%Y%m%d%H%M%S%3N')}"[0, 20],
        MerchantTradeDate: Time.now.in_time_zone("Taipei").strftime("%Y/%m/%d %H:%M:%S"),
        TotalAmount: 0,
        ReturnURL: ENV.fetch("ECPAY_ORDER_RESULT_URL_BASE", "https://example.com/ecpay/card_bindings") + "/#{provider.organization_id}/callback",
        TradeDesc: "Connectivity Test"
      },
      CardInfo: {},
      ConsumerInfo: {
        MerchantMemberID: "M-#{customer.external_id.first(8)}",
        Email: customer.email,
        Phone: ""
      }
    }

    request_body = Lago::EcpayAes.build_request(
      provider.merchant_id, data,
      provider.hash_key, provider.hash_iv
    )

    uri = URI("#{provider.ecpg_base_url}/Merchant/GetTokenbyBindingCard")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 30

    req = Net::HTTP::Post.new(uri.path, {"Content-Type" => "application/json"})
    req.body = request_body.to_json

    response = http.request(req)
    puts "  HTTP Status: #{response.code}"

    parsed = Lago::EcpayAes.parse_response(
      JSON.parse(response.body),
      provider.hash_key, provider.hash_iv
    )

    if parsed[:success]
      puts "  SUCCESS! TransCode=1, RtnCode=1"
      puts "  TokenURL: #{parsed[:data]['TokenURL']}"
      puts ""
      puts "  ✓ ECPay sandbox connectivity verified!"
    else
      puts "  FAILED: #{parsed[:error] || parsed[:rtn_msg]}"
      puts "  Response: #{parsed.inspect}"
    end
  end

  desc "Show current E2E test data status"
  task status: :environment do
    puts "=== ECPay E2E Status ==="

    provider = PaymentProviders::EcpayProvider.find_by(sandbox: "true")
    unless provider
      puts "  No sandbox EcpayProvider found. Run `rake ecpay:setup_e2e` first."
      exit 0
    end

    org = provider.organization
    puts "  Organization: #{org.id} (#{org.name})"
    puts "  Provider: #{provider.id} (MerchantID: #{provider.merchant_id}, sandbox=#{provider.sandbox?})"

    customer = Customer.find_by(organization: org, external_id: "e2e_test_customer")
    if customer
      puts "  Customer: #{customer.id} (#{customer.external_id})"

      ecpay_customer = PaymentProviderCustomers::EcpayCustomer.find_by(customer: customer)
      if ecpay_customer
        puts "  EcpayCustomer: #{ecpay_customer.id}"
        puts "    merchant_member_id: #{ecpay_customer.merchant_member_id || '(not set)'}"
        puts "    card_bound: #{ecpay_customer.card_bound?}"
        puts "    card_id: #{ecpay_customer.card_id || '(none)'}"
        puts "    card_last_four: #{ecpay_customer.card_last_four || '(none)'}"
        puts "    card_first_six: #{ecpay_customer.card_first_six || '(none)'}"
      else
        puts "  EcpayCustomer: NOT FOUND"
      end

      # Check invoices
      invoices = customer.invoices.order(created_at: :desc).limit(5)
      if invoices.any?
        puts ""
        puts "  Recent Invoices:"
        invoices.each do |inv|
          payment = inv.payments.last
          payment_info = payment ? "payment_status=#{payment.status}, provider_id=#{payment.provider_payment_id}" : "no payment"
          puts "    #{inv.number} | #{inv.payment_status} | #{inv.total_amount_cents}c | #{payment_info}"
        end
      else
        puts "  Invoices: none"
      end
    else
      puts "  Customer: NOT FOUND"
    end
  end
end
