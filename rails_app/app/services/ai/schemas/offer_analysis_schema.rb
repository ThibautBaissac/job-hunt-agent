require "ruby_llm/schema"

module Ai
  module Schemas
    class OfferAnalysisSchema < RubyLLM::Schema
      string :summary

      array :tech_stack do
        string
      end

      array :keywords do
        string
      end

      string :seniority_level
    end
  end
end
