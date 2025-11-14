module Ai
  class Client
    class Error < StandardError; end

    def initialize(model: default_model, provider: configured_provider)
      @model = model
      @provider = provider
    end

    def chat
      chat = RubyLLM.chat
      chat = chat.with_model(model, provider: provider.presence) if model.present? || provider.present?
      chat
    rescue RubyLLM::Error => e
      raise Error, e.message
    end

    private

    attr_reader :model, :provider

    def default_model
      ENV.fetch("LLM_MODEL", RubyLLM.config.default_model)
    end

    def configured_provider
      ENV["LLM_PROVIDER"].presence
    end
  end
end
