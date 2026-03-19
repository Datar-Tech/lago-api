# frozen_string_literal: true

module Lago
  class EcpayAes
    # ECPG 專用 URL encode（不做 toLowerCase、不做 .NET 字元還原）
    # 與 AIO 的 ecpay_url_encode 行為不同，不可混用
    def self.url_encode(input)
      ERB::Util.url_encode(input)
        .gsub("%20", "+")
    end

    def self.encrypt(plain_text, hash_key, hash_iv)
      cipher = OpenSSL::Cipher.new("AES-128-CBC")
      cipher.encrypt
      cipher.key = hash_key.encode("UTF-8")
      cipher.iv = hash_iv.encode("UTF-8")
      encrypted = cipher.update(url_encode(plain_text)) + cipher.final
      Base64.strict_encode64(encrypted)
    end

    def self.decrypt(cipher_text, hash_key, hash_iv)
      cipher = OpenSSL::Cipher.new("AES-128-CBC")
      cipher.decrypt
      cipher.key = hash_key.encode("UTF-8")
      cipher.iv = hash_iv.encode("UTF-8")
      decrypted = cipher.update(Base64.strict_decode64(cipher_text)) + cipher.final
      URI.decode_www_form_component(decrypted)
    end

    # 建構 AES-JSON 三層請求結構
    def self.build_request(merchant_id, data, hash_key, hash_iv)
      {
        MerchantID: merchant_id,
        RqHeader: {Timestamp: Time.now.to_i},
        Data: encrypt(data.to_json, hash_key, hash_iv)
      }
    end

    # 解析回應：TransCode 必須是整數 1，才解密 Data
    def self.parse_response(response, hash_key, hash_iv)
      trans_code = response["TransCode"]
      return {success: false, error: "TransCode=#{trans_code}"} unless trans_code == 1

      json_str = decrypt(response["Data"], hash_key, hash_iv)
      data = JSON.parse(json_str)
      rtn_code = data["RtnCode"]

      {
        success: rtn_code == 1,
        data: data,
        rtn_code: rtn_code,
        rtn_msg: data["RtnMsg"]
      }
    end
  end
end
