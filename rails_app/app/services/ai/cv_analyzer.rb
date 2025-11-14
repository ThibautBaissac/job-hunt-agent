require "json"

module Ai
  class CvAnalyzer
    class Error < StandardError; end

    def initialize(cv:, streamer: nil, client: Ai::Client.new)
      @cv = cv
      @streamer = streamer
      @client = client
    end

    def call
      response_buffer = +""
      chat = client.chat
      chat.with_instructions(system_prompt)
      chat.with_schema(Schemas::CvAnalysisSchema)
      chat.with_temperature(0.2)

      response = chat.ask(user_prompt) do |chunk|
        next if chunk.content.blank?

        response_buffer << chunk.content
        streamer&.call(chunk.content)
      end

      content = normalize_payload(response.content) || normalize_payload(response_buffer)

      raise Error, "Analyse impossible: réponse vide" unless content

      persist_analysis(content)
      content
    rescue RubyLLM::Error => e
      raise Error, e.message
    end

    private

    attr_reader :cv, :streamer, :client

    def persist_analysis(content)
      cv.update!(
        analysis_summary: content[:summary],
        analysis_forces: content[:strengths],
        analysis_weaknesses: content[:weaknesses],
        analysis_suggestions: content[:suggestions],
        analyzed_at: Time.current
      )
    end

    def normalize_payload(raw)
      payload = unwrap_payload(raw)

      case payload
      when Hash
        build_analysis_hash(payload)
      when String
        parsed = JSON.parse(extract_json_fragment(payload), symbolize_names: true)
        build_analysis_hash(parsed)
      else
        nil
      end
    rescue JSON::ParserError, Error
      nil
    end

    def normalize_array(value)
      Array(value).flatten.compact_blank.map(&:strip)
    end

    def strip_code_fences(text)
      text.gsub(/```(?:json)?/i, "")
    end

    def extract_json_fragment(text)
      sanitized = strip_code_fences(text.to_s)
      start_idx = sanitized.index("{")
      end_idx = sanitized.rindex("}")

      raise Error, "Analyse impossible: réponse JSON introuvable" unless start_idx && end_idx && end_idx > start_idx

      sanitized[start_idx..end_idx]
    end

    def unwrap_payload(raw)
      return if raw.respond_to?(:blank?) && raw.blank?

      return raw if raw.is_a?(Hash) || raw.is_a?(String)

      if raw.respond_to?(:to_h)
        value = raw.to_h
        return value if value.present?
      end

      if raw.respond_to?(:to_hash)
        value = raw.to_hash
        return value if value.present?
      end

      if raw.respond_to?(:to_s)
        value = raw.to_s
        return value if value.present?
      end

      raw
    end

    def build_analysis_hash(hash)
      hash.transform_keys(&:to_sym).yield_self do |attrs|
        {
          summary: attrs[:summary]&.to_s,
          strengths: normalize_array(attrs[:strengths]),
          weaknesses: normalize_array(attrs[:weaknesses]),
          suggestions: normalize_array(attrs[:suggestions])
        }
      end
    end

    def system_prompt
      <<~PROMPT
        Tu es un assistant spécialisé dans l'analyse de CV de développeurs.
        Renvoie un JSON respectant exactement le schéma fourni avec :
        - summary : résumé concis en 2 à 3 phrases (en français) des points clés du CV
        - strengths : liste (3 à 5 éléments) des forces principales
        - weaknesses : liste (3 à 5 éléments) des axes d'amélioration
        - suggestions : liste (3 à 5 recommandations actionnables) pour optimiser le CV
        Chaque élément doit être une phrase courte, précise et orientée candidature technique.
      PROMPT
    end

    def user_prompt
      <<~PROMPT
        Analyse le CV suivant et remplis le schéma demandé.

        CV:
        #{cv.body_text}
      PROMPT
    end
  end
end
