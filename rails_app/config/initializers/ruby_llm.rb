RubyLLM.configure do |config|
  config.logger = Rails.logger
  config.log_level = Rails.logger.level

  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"] if ENV["ANTHROPIC_API_KEY"].present?
  config.openai_api_key = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"].present?
  config.gemini_api_key = ENV["GEMINI_API_KEY"] if ENV["GEMINI_API_KEY"].present?
  config.deepseek_api_key = ENV["DEEPSEEK_API_KEY"] if ENV["DEEPSEEK_API_KEY"].present?
  config.perplexity_api_key = ENV["PERPLEXITY_API_KEY"] if ENV["PERPLEXITY_API_KEY"].present?
  config.mistral_api_key = ENV["MISTRAL_API_KEY"] if ENV["MISTRAL_API_KEY"].present?
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"] if ENV["OPENROUTER_API_KEY"].present?

  config.default_model = if ENV["LLM_MODEL"].present?
                           ENV["LLM_MODEL"]
  elsif config.anthropic_api_key.present?
                           "claude-3-sonnet-20240229"
  else
                           config.default_model
  end

  config.request_timeout = ENV.fetch("LLM_TIMEOUT", config.request_timeout).to_i if ENV["LLM_TIMEOUT"].present?
end
