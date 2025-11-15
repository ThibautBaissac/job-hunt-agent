require "json"

class OfferAnalysisJob < ApplicationJob
  queue_as :default

  include ActionView::RecordIdentifier

  def perform(job_offer_id)
    @job_offer = JobOffer.find(job_offer_id)
    @stream_buffer = +""

    Ai::OfferAnalyzer.new(job_offer: @job_offer, streamer: ->(chunk) { handle_stream(chunk) }).call
    @job_offer.reload

    broadcast_panel(@job_offer)
  rescue Ai::OfferAnalyzer::Error => e
    broadcast_error(@job_offer, e.message)
  end

  private

  def stream_name(job_offer)
    "job_offer_analysis_#{job_offer.id}"
  end

  def handle_stream(chunk)
    return if chunk.blank?

    @stream_buffer << chunk
    analysis = extract_analysis(@stream_buffer)

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(@job_offer),
      target: dom_id(@job_offer, :analysis_stream),
      html: ApplicationController.render(
        partial: "job_offers/analysis_stream",
        locals: {
          target_id: dom_id(@job_offer, :analysis_stream),
          raw_content: sanitized_stream(@stream_buffer, analysis&.dig(:raw)),
          analysis: analysis&.dig(:parsed)
        }
      )
    )
  end

  def broadcast_panel(job_offer)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(job_offer),
      target: dom_id(job_offer, :analysis),
      html: ApplicationController.render(
        partial: "job_offers/analysis_panel",
        locals: { job_offer: job_offer }
      )
    )
  end

  def broadcast_error(job_offer, message)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(job_offer),
      target: dom_id(job_offer, :analysis),
      html: ApplicationController.render(
        partial: "job_offers/analysis_error",
        locals: { message: message, job_offer: job_offer }
      )
    )
  end

  def extract_analysis(buffer)
    json_segment = capture_json_segment(buffer)
    return unless json_segment

    parsed = JSON.parse(json_segment)

    return unless parsed.is_a?(Hash)

    {
      raw: json_segment,
      parsed: normalize_analysis_hash(parsed)
    }
  rescue JSON::ParserError
    nil
  end

  def capture_json_segment(buffer)
    start_idx = buffer.index("{")
    end_idx = buffer.rindex("}")

    return unless start_idx && end_idx && end_idx > start_idx

    buffer[start_idx..end_idx]
  end

  def sanitized_stream(buffer, json_segment)
    sanitized = buffer.gsub(/```(?:json)?/i, "")
    sanitized = sanitized.gsub(json_segment, "") if json_segment
    sanitized.strip.presence
  end

  def normalize_analysis_hash(parsed)
    parsed.transform_keys(&:to_s).tap do |hash|
      hash["tech_stack"] = Array(hash["tech_stack"])
      hash["keywords"] = Array(hash["keywords"])
      hash["summary"] = hash["summary"].to_s
      hash["seniority_level"] = hash["seniority_level"].to_s
    end
  end
end
