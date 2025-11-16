require "json"
require "faraday"

module Ai
  class OfferAnalyzer
    SUPPORTED_BACKENDS = %i[rails python].freeze
    class Error < StandardError; end

    def initialize(job_offer:, streamer: nil, client: Ai::Client.new, backend: :rails, agent_connection: nil)
      @job_offer = job_offer
      @streamer = streamer
      @client = client
      @backend = normalize_backend(backend)
      @agent_connection = agent_connection
    end

    def call
      case backend
      when :rails
        call_with_ruby_llm
      when :python
        call_with_agent_api
      else
        raise Error, "Analyse impossible: backend inconnu"
      end
    rescue RubyLLM::Error => e
      raise Error, e.message
    end

    private

    attr_reader :job_offer, :streamer, :client, :backend, :agent_connection

    def call_with_ruby_llm
      response_buffer = +""
      chat = client.chat
      chat.with_instructions(system_prompt)
      chat.with_schema(Schemas::OfferAnalysisSchema)
      chat.with_temperature(0.2)

      response = chat.ask(user_prompt) do |chunk|
        next if chunk.content.blank?

        response_buffer << chunk.content
        streamer&.call(chunk.content)
      end

      content = normalize_payload(response.content) || normalize_payload(response_buffer)

      raise Error, "Analyse impossible: réponse vide" unless content

      persist_analysis(content, :rails)
      content
    end

    def call_with_agent_api
      response = agent_http_connection.post(
        "/agent/offer_analysis",
        agent_payload.to_json,
        "Content-Type" => "application/json"
      )

      body = parse_agent_body(response.body)
      content = build_analysis_hash(body)

      persist_analysis(content, :python)
      streamer&.call("Analyse terminée via Agent API.")
      content
    rescue Faraday::Error => e
      raise Error, "Agent API indisponible : #{e.message}"
    rescue JSON::ParserError
      raise Error, "Analyse impossible: réponse JSON invalide"
    end

    def persist_analysis(content, backend)
      job_offer.update!(
        summary: content[:summary],
        tech_stack: content[:tech_stack],
        keywords: content[:keywords],
        seniority_level: content[:seniority_level],
        analyzed_at: Time.current,
        analysis_backend: backend.to_s
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
          tech_stack: normalize_array(attrs[:tech_stack]),
          keywords: normalize_array(attrs[:keywords]),
          seniority_level: attrs[:seniority_level]&.to_s
        }
      end
    end

    def parse_agent_body(payload)
      data = case payload
      when String
        JSON.parse(payload)
      when Hash
        payload
      else
        raise JSON::ParserError
      end

      data.fetch("analysis") do
        data.fetch("data") { data }
      end
    end

    def agent_payload
      {
        job_offer: {
          id: job_offer.id,
          title: job_offer.title,
          company_name: job_offer.company_name,
          location: job_offer.location,
          description: job_offer.raw_description
        }
      }
    end

    def system_prompt
      <<~PROMPT
        Tu es un assistant spécialisé dans l'analyse d'offres d'emploi techniques.
        Renvoie un JSON respectant exactement le schéma fourni avec :
        - summary : résumé concis en 2 à 3 phrases (en français) de l'offre d'emploi
        - tech_stack : liste (5 à 10 éléments) des technologies et outils mentionnés (ex: ["React", "Node.js", "PostgreSQL"])
        - keywords : liste (5 à 10 éléments) des mots-clés importants pour cette offre (soft skills, domaines, méthodologies)
        - seniority_level : niveau d'expérience requis (ex: "Junior", "Intermédiaire", "Senior", "Lead", "Staff")

        Sois précis et extrait uniquement les informations présentes dans l'offre.
      PROMPT
    end

    def user_prompt
      <<~PROMPT
        Analyse l'offre d'emploi suivante et remplis le schéma demandé.

        Titre du poste: #{job_offer.title}
        Entreprise: #{job_offer.company_name}
        Localisation: #{job_offer.location}

        Description:
        #{job_offer.raw_description}
      PROMPT
    end

    def agent_http_connection
      agent_connection || Faraday.new(url: agent_base_url) do |faraday|
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
      end
    end

    def agent_base_url
      ENV.fetch("AGENT_API_URL") do
        raise Error, "Agent API URL manquante"
      end
    end

    def normalize_backend(value)
      symbol = value.to_s.downcase.presence || "rails"
      sym = symbol.to_sym
      return sym if SUPPORTED_BACKENDS.include?(sym)

      :rails
    end
  end
end
