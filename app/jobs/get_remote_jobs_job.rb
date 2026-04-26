class GetRemoteJobsJob < ApplicationJob
  queue_as :default

  # Ensure only one GetRemoteJobsJob runs at a time
  limits_concurrency to: 1, key: -> { "api_consumer_job" }

  def perform
    servers = Server.all

    if servers.none?
      Rails.logger.info "No servers configured"
      return
    end

    servers.find_each do |server|
      Rails.logger.info "Fetching jobs from server #{server.id} (#{server.url})"
      token = ensure_authenticated(server)

      if token
        fetch_llm_jobs(server, token)
      else
        Rails.logger.error "Failed to authenticate with server #{server.id} (#{server.url})"
      end
    end
  end

  def push_available_models(models)
    Server.find_each do |server|
      token = ensure_authenticated(server)
      unless token
        Rails.logger.error "Cannot push available models to server #{server.id}: authentication failed"
        next
      end

      response = make_request(:post, server, "/available_models", token: token, body: { models: models }.to_json)
      if response&.code.to_i == 200
        Rails.logger.info "Updated available models on server #{server.id}"
      else
        Rails.logger.error "Failed to update available models on server #{server.id}: #{response&.code} #{response&.body}"
      end
    end
  end

  def update_llm_job(server, remote_job_id, llm_response:, seconds: nil, token: nil)
    Rails.logger.info "Updating remote llm_job #{remote_job_id} on server #{server.id}"

    token ||= ensure_authenticated(server)
    return false unless token

    payload = { result: llm_response }
    payload[:seconds] = seconds if seconds
    http_response = make_request(:put, server, "/llm_jobs/#{remote_job_id}", token: token, body: payload.to_json)

    if http_response && http_response.code.to_i == 200
      Rails.logger.info "Successfully updated remote llm_job #{remote_job_id}"
      true
    else
      Rails.logger.error "Failed to update remote llm_job #{remote_job_id}: #{http_response&.code} - #{http_response&.body}"
      false
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Error parsing update response for llm_job #{remote_job_id}: #{e.message}"
    false
  end

  def ensure_authenticated(server)
    Rails.logger.info "Checking authentication for server #{server.id}"

    if current_token(server) && logged_in?(server, current_token(server))
      Rails.logger.info "Already authenticated with server #{server.id}"
      return current_token(server)
    end

    Rails.logger.info "Not authenticated, attempting login to server #{server.id}"
    login(server)
  end

  private

  def logged_in?(server, token)
    response = make_request(:get, server, "/current_user", token: token)

    if response && response.code.to_i == 200
      data = JSON.parse(response.body)
      logged_in = data["logged_in"] == true
      Rails.logger.info "Login status check for server #{server.id}: #{logged_in}"
      logged_in
    else
      Rails.logger.warn "Failed to check login status for server #{server.id}: #{response&.code}"
      false
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Error parsing current_user response: #{e.message}"
    false
  end

  def login(server)
    Rails.logger.info "Attempting to login to server #{server.id}"

    credentials = {
      email_address: server.login,
      password: server.password
    }

    response = make_request(:post, server, "/login", body: credentials.to_json)

    if response && response.code.to_i == 200
      data = JSON.parse(response.body)
      token = data["api_token"] || data["token"] || data["access_token"] || data["auth_token"]

      if token
        Rails.logger.info "Login successful for server #{server.id}"
        store_token(server, token)
        token
      else
        Rails.logger.error "Login response missing token for server #{server.id}: #{data}"
        nil
      end
    else
      Rails.logger.error "Login failed for server #{server.id}: #{response&.code} - #{response&.body}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Error parsing login response: #{e.message}"
    nil
  end

  def fetch_llm_jobs(server, token)
    Rails.logger.info "Fetching llm_jobs from server #{server.id}"

    # Step 1: GET /api/llm_jobs → list of new jobs
    response = make_request(:get, server, "/llm_jobs", token: token)

    unless response && response.code.to_i == 200
      Rails.logger.error "Failed to fetch llm_jobs from server #{server.id}: #{response&.code} - #{response&.body}"
      return nil
    end

    data = JSON.parse(response.body)
    llm_jobs = data["llm_jobs"]

    if llm_jobs.blank?
      Rails.logger.info "No new llm_jobs from server #{server.id}"
      return data
    end

    # Step 2: Download all prompts locally
    jobs_by_remote_id = {}
    llm_jobs.each do |llm_job|
      jobs_by_remote_id[llm_job["id"]] = llm_job
    end

    # Step 3: POST /api/llm_jobs/claim with { ids: [...] }
    ids_to_claim = llm_jobs.map { |j| j["id"] }
    Rails.logger.info "Claiming #{ids_to_claim.size} jobs from server #{server.id}: #{ids_to_claim}"

    claim_response = make_request(:post, server, "/llm_jobs/claim", token: token, body: { ids: ids_to_claim }.to_json)

    unless claim_response && claim_response.code.to_i == 200
      Rails.logger.error "Failed to claim jobs from server #{server.id}: #{claim_response&.code} - #{claim_response&.body}"
      return nil
    end

    claim_data = JSON.parse(claim_response.body)
    claimed_ids = claim_data["claimed_ids"]

    Rails.logger.info "Claimed #{claimed_ids.size} of #{ids_to_claim.size} jobs from server #{server.id}"

    claimed_ids.size.times { RunLlmJob.perform_later }

    # Step 4: Process only the IDs in claimed_ids
    claimed_ids.each do |remote_id|
      llm_job = jobs_by_remote_id[remote_id]
      next unless llm_job

      job = Job.create(prompt: llm_job["prompt"], model: llm_job["model"], status: "unprocessed", remote_job_id: llm_job["id"], server: server)
      if job.persisted?
        Rails.logger.info "Created local job #{job.id} for remote llm_job #{llm_job["id"]} on server #{server.id}"
      else
        Job.create!(prompt: llm_job["prompt"], model: llm_job["model"], status: "error", remote_job_id: llm_job["id"], server: server, error_text: job.errors.full_messages.join(", "))
        Rails.logger.error "Saved remote llm_job #{llm_job["id"]} from server #{server.id} with error status: #{job.errors.full_messages.join(", ")}"
      end
    rescue => e
      Job.create(prompt: nil, status: "error", remote_job_id: remote_id, server: server, error_text: e.message)
      Rails.logger.error "Error creating job for remote llm_job #{remote_id} from server #{server.id}: #{e.message}"
    end

    data
  rescue JSON::ParserError => e
    Rails.logger.error "Error parsing llm_jobs response: #{e.message}"
    nil
  end

  def make_request(method, server, path, token: nil, body: nil)
    require "net/http"
    require "uri"

    uri = URI("#{server.url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"

    case method
    when :get
      request = Net::HTTP::Get.new(uri)
    when :post
      request = Net::HTTP::Post.new(uri)
      request.body = body if body
    when :put
      request = Net::HTTP::Put.new(uri)
      request.body = body if body
    end

    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{token}" if token

    Rails.logger.debug "Making #{method.upcase} request to #{uri}"

    http.request(request)
  rescue => e
    Rails.logger.error "HTTP request error: #{e.message}"
    nil
  end

  def current_token(server)
    Rails.cache.read("api_auth_token_server_#{server.id}")
  end

  def store_token(server, token)
    Rails.cache.write("api_auth_token_server_#{server.id}", token, expires_in: 24.hours)
    Rails.logger.info "Token stored for server #{server.id}"
  end
end
