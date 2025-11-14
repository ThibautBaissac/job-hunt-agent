require "json"

class CvAnalysisJob < ApplicationJob
  queue_as :default

  include ActionView::RecordIdentifier

  def perform(cv_id)
    @cv = Cv.find(cv_id)
    @stream_buffer = +""

    Ai::CvAnalyzer.new(cv: @cv, streamer: ->(chunk) { handle_stream(chunk) }).call
    @cv.reload

    broadcast_panel(@cv)
  rescue Ai::CvAnalyzer::Error => e
    broadcast_error(@cv, e.message)
  end

  private

  def stream_name(cv)
    "cv_analysis_#{cv.id}"
  end

  def handle_stream(chunk)
    return if chunk.blank?

    @stream_buffer << chunk
    analysis = extract_analysis(@stream_buffer)

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(@cv),
      target: dom_id(@cv, :analysis_stream),
      html: ApplicationController.render(
        partial: "cvs/analysis_stream",
        locals: {
          target_id: dom_id(@cv, :analysis_stream),
          raw_content: sanitized_stream(@stream_buffer, analysis&.dig(:raw)),
          analysis: analysis&.dig(:parsed)
        }
      )
    )
  end

  def broadcast_panel(cv)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(cv),
      target: dom_id(cv, :analysis),
      html: ApplicationController.render(
        partial: "cvs/analysis_panel",
        locals: { cv: cv }
      )
    )
  end

  def broadcast_error(cv, message)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name(cv),
      target: dom_id(cv, :analysis),
      html: ApplicationController.render(
        partial: "cvs/analysis_error",
        locals: { message: message, cv: cv }
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
      hash["strengths"] = Array(hash["strengths"])
      hash["weaknesses"] = Array(hash["weaknesses"])
      hash["suggestions"] = Array(hash["suggestions"])
      hash["summary"] = hash["summary"].to_s
    end
  end
end
