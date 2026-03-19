# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lago::EcpayAes do
  # ECPay ECPG 測試帳號
  let(:hash_key) { "pwFHCqoQZGmho4w6" }
  let(:hash_iv) { "EkRm7iFT261dpevs" }

  describe ".url_encode" do
    it "encodes spaces as +" do
      expect(described_class.url_encode("hello world")).to include("+")
      expect(described_class.url_encode("hello world")).not_to include("%20")
    end

    it "percent-encodes special characters" do
      result = described_class.url_encode("key=value&foo=bar")
      expect(result).to include("%3D")
      expect(result).to include("%26")
    end

    it "does not lowercase percent-encoded characters" do
      result = described_class.url_encode("test@email.com")
      expect(result).to include("%40")
    end
  end

  describe ".encrypt and .decrypt" do
    it "round-trips correctly" do
      plain_text = '{"MerchantID":"3002607","RtnCode":1}'
      encrypted = described_class.encrypt(plain_text, hash_key, hash_iv)
      decrypted = described_class.decrypt(encrypted, hash_key, hash_iv)
      expect(decrypted).to eq(plain_text)
    end

    it "produces standard Base64 output (not URL-safe)" do
      plain_text = '{"test":"data"}'
      encrypted = described_class.encrypt(plain_text, hash_key, hash_iv)
      # Standard Base64 uses +/= not -_
      expect(encrypted).not_to match(/[-_]/)
      expect(encrypted).to match(%r{\A[A-Za-z0-9+/]+=*\z})
    end

    it "handles unicode characters" do
      plain_text = '{"TradeDesc":"VelaOrdo 綁定信用卡"}'
      encrypted = described_class.encrypt(plain_text, hash_key, hash_iv)
      decrypted = described_class.decrypt(encrypted, hash_key, hash_iv)
      expect(decrypted).to eq(plain_text)
    end

    it "handles empty JSON object" do
      plain_text = "{}"
      encrypted = described_class.encrypt(plain_text, hash_key, hash_iv)
      decrypted = described_class.decrypt(encrypted, hash_key, hash_iv)
      expect(decrypted).to eq(plain_text)
    end
  end

  describe ".build_request" do
    it "returns the correct three-layer structure" do
      data = {MerchantID: "3002607", OrderInfo: {TotalAmount: 100}}

      result = described_class.build_request("3002607", data, hash_key, hash_iv)

      expect(result).to have_key(:MerchantID)
      expect(result[:MerchantID]).to eq("3002607")
      expect(result).to have_key(:RqHeader)
      expect(result[:RqHeader]).to have_key(:Timestamp)
      expect(result[:RqHeader][:Timestamp]).to be_a(Integer)
      expect(result).to have_key(:Data)
      expect(result[:Data]).to be_a(String)
    end

    it "encrypts Data that can be decrypted back" do
      data = {MerchantID: "3002607", TotalAmount: 500}
      result = described_class.build_request("3002607", data, hash_key, hash_iv)

      decrypted = described_class.decrypt(result[:Data], hash_key, hash_iv)
      parsed = JSON.parse(decrypted)

      expect(parsed["MerchantID"]).to eq("3002607")
      expect(parsed["TotalAmount"]).to eq(500)
    end
  end

  describe ".parse_response" do
    it "parses a successful response (TransCode=1, RtnCode=1)" do
      inner_data = {"RtnCode" => 1, "RtnMsg" => "Success", "TradeNo" => "T20260319000001"}
      encrypted_data = described_class.encrypt(inner_data.to_json, hash_key, hash_iv)

      response = {
        "MerchantID" => "3002607",
        "TransCode" => 1,
        "Data" => encrypted_data
      }

      result = described_class.parse_response(response, hash_key, hash_iv)

      expect(result[:success]).to be true
      expect(result[:rtn_code]).to eq(1)
      expect(result[:rtn_msg]).to eq("Success")
      expect(result[:data]["TradeNo"]).to eq("T20260319000001")
    end

    it "returns failure when TransCode is not 1" do
      response = {
        "MerchantID" => "3002607",
        "TransCode" => 0,
        "Data" => "irrelevant"
      }

      result = described_class.parse_response(response, hash_key, hash_iv)

      expect(result[:success]).to be false
      expect(result[:error]).to eq("TransCode=0")
    end

    it "returns failure when TransCode is string '1' (not integer)" do
      response = {
        "MerchantID" => "3002607",
        "TransCode" => "1",
        "Data" => "irrelevant"
      }

      result = described_class.parse_response(response, hash_key, hash_iv)

      expect(result[:success]).to be false
      expect(result[:error]).to eq("TransCode=1")
    end

    it "returns success=false when RtnCode is not 1" do
      inner_data = {"RtnCode" => 0, "RtnMsg" => "Payment Failed"}
      encrypted_data = described_class.encrypt(inner_data.to_json, hash_key, hash_iv)

      response = {
        "MerchantID" => "3002607",
        "TransCode" => 1,
        "Data" => encrypted_data
      }

      result = described_class.parse_response(response, hash_key, hash_iv)

      expect(result[:success]).to be false
      expect(result[:rtn_code]).to eq(0)
      expect(result[:rtn_msg]).to eq("Payment Failed")
    end

    it "returns success=false when RtnCode is string '1' (not integer)" do
      inner_data = {"RtnCode" => "1", "RtnMsg" => "Success"}
      encrypted_data = described_class.encrypt(inner_data.to_json, hash_key, hash_iv)

      response = {
        "MerchantID" => "3002607",
        "TransCode" => 1,
        "Data" => encrypted_data
      }

      result = described_class.parse_response(response, hash_key, hash_iv)

      expect(result[:success]).to be false
      expect(result[:rtn_code]).to eq("1")
    end
  end
end
