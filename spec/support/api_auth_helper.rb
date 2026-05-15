module ApiAuthHelper
  def auth_headers(plaintext_token, extra = {})
    { "Authorization" => "Bearer #{plaintext_token}" }.merge(extra)
  end

  def merchant_with_key
    merchant = create(:merchant)
    generated = ApiKey.generate!(merchant: merchant)
    [merchant, generated.plaintext]
  end
end
