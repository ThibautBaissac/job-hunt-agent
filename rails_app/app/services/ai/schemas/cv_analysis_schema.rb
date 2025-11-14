require "ruby_llm/schema"

module Ai
  module Schemas
    class CvAnalysisSchema < RubyLLM::Schema
      string :summary

      array :strengths do
        string
      end

      array :weaknesses do
        string
      end

      array :suggestions do
        string
      end
    end
  end
end
