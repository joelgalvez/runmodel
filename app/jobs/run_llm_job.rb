require "net/http"
require "json"

class RunLlmJob < ApplicationJob
  queue_as :llm

  limits_concurrency to: 1, key: -> { "run_llm_job" }

  LLAMA_SERVER_URL = ENV.fetch("LLAMA_SERVER_URL", "http://172.17.0.1:8080")

  def perform
    sync_models_if_changed

    job = Job.unprocessed.order(created_at: :asc).first
    return Rails.logger.info "No unprocessed jobs" unless job

    job.update!(status: "pending")
    Rails.logger.info "Running LLM on job #{job.id}"

    start_time = Time.now
    output = run_llama(job.prompt, job.model)
    elapsed_seconds = (Time.now - start_time).round

    if output
      if job.server && job.remote_job_id
        remote_updated = GetRemoteJobsJob.new.update_llm_job(job.server, job.remote_job_id, llm_response: output, seconds: elapsed_seconds)
        unless remote_updated
          error_message = "Failed to update remote job #{job.remote_job_id} on server #{job.server.id}"
          job.update!(status: "error", error_text: error_message)
          Rails.logger.error "Job #{job.id} failed: #{error_message}"
          return
        end
      end
      job.update!(result: output, status: "processed", seconds: elapsed_seconds)
      Rails.logger.info "Job #{job.id} completed"
    else
      error_message = "No output from llama"
      job.update!(status: "error", error_text: error_message)
      Rails.logger.error "Job #{job.id} failed: #{error_message}"
    end
  rescue => e
    job&.update!(status: "error", error_text: e.message)
    Rails.logger.error "Job #{job&.id} error: #{e.message}"
    raise
  end

  def sync_models_if_changed
    llama_models = fetch_llama_models
    return false unless llama_models

    current_names = AvailableModel.pluck(:name).sort
    return false if llama_models.sort == current_names

    Rails.logger.info "Available models changed, updating"
    AvailableModel.delete_all
    AvailableModel.insert_all(llama_models.map { |name| { name: name, created_at: Time.current, updated_at: Time.current } })
    GetRemoteJobsJob.new.push_available_models(llama_models)
    true
  end

  def fetch_llama_models
    uri = URI("#{LLAMA_SERVER_URL}/v1/models")
    response = Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 10) do |http|
      http.request(Net::HTTP::Get.new(uri, "Content-Type" => "application/json"))
    end

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body).dig("data")&.map { |m| m["id"] }
    else
      Rails.logger.error "Failed to fetch models from llama-server: #{response.code}"
      nil
    end
  rescue => e
    Rails.logger.error "Error fetching llama models: #{e.message}"
    nil
  end

  JSON_GRAMMAR = <<~'GBNF'
    root   ::= object
    value  ::= object | array | string | number | ("true" | "false" | "null") ws

    object ::=
      "{" ws (
                string ":" ws value
        ("," ws string ":" ws value)*
      )? "}" ws

    array  ::=
      "[" ws (
                value
        ("," ws value)*
      )? "]" ws

    string ::=
      "\"" (
        [^"\\\x7F\x00-\x1F] |
        "\\" (["\\bfnrt] | "u" [0-9a-fA-F]{4}) # escapes
      )* "\"" ws

    number ::= ("-"? ([0-9] | [1-9] [0-9]{0,15})) ("." [0-9]+)? ([eE] [-+]? [0-9] [1-9]{0,15})? ws

    # Optional space: by convention, applied in this grammar after literal chars when allowed
    ws ::= | " " | "\n" [ \t]{0,20}
  GBNF

  DEFAULT_MODEL = "Qwen3.5-27B-UD-Q4_K_XL"

  def run_llama(prompt, model = nil)
    uri = URI("#{LLAMA_SERVER_URL}/v1/chat/completions")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = {
      model: model.presence || DEFAULT_MODEL,
      messages: [ { role: "user", content: prompt } ],
      temperature: 0.0,
      top_p: 1.0,
      repeat_penalty: 1.0,
      max_tokens: -1,
      n_ctx: 20000,
      chat_template_kwargs: { enable_thinking: false },
      grammar: JSON_GRAMMAR
    }.to_json

    response = Net::HTTP.start(uri.host, uri.port, read_timeout: 600, open_timeout: 10) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body).dig("choices", 0, "message", "content")&.strip
    else
      Rails.logger.error "llama-server error: #{response.code} #{response.body}"
      nil
    end
  end
end
