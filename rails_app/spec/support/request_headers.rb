# frozen_string_literal: true

module RequestHeaders
  MODERN_USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze

  def default_headers(overrides = {})
    { "User-Agent" => MODERN_USER_AGENT }.merge(overrides)
  end
end

RSpec.configure do |config|
  config.include RequestHeaders, type: :request
end
