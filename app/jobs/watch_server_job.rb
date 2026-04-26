require "websocket-client-simple"
require "json"

class WatchServerJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(server_id) { "watch_server_job_#{server_id}" }

  MAX_DURATION = 5.minutes

  def perform(server_id)
    server = Server.find_by(id: server_id)
    unless server
      Rails.logger.error "WatchServerJob: server #{server_id} not found"
      return
    end

    token = GetRemoteJobsJob.new.ensure_authenticated(server)
    unless token
      Rails.logger.error "WatchServerJob: failed to authenticate with server #{server.id}"
      return
    end

    cable_url = build_cable_url(server.url, token)
    Rails.logger.info "WatchServerJob: connecting to #{cable_url.sub(/token=\S+/, 'token=[REDACTED]')}"
    connect_and_watch(server, cable_url)
  end

  private

  def build_cable_url(base_url, token)
    uri = URI(base_url)
    ws_scheme = uri.scheme == "https" ? "wss" : "ws"
    "#{ws_scheme}://#{uri.host}/cable?token=#{URI.encode_www_form_component(token)}"
  end

  def connect_and_watch(server, cable_url)
    mutex = Mutex.new
    cond = ConditionVariable.new
    closed = false

    uri = URI(cable_url)
    origin = "#{uri.scheme == 'wss' ? 'https' : 'http'}://#{uri.host}"
    ws = WebSocket::Client::Simple.connect(cable_url, headers: { "Origin" => origin })
    job = self

    ws.on :open do
      Rails.logger.info "WatchServerJob: connected to server #{server.id}"
    end

    ws.on :message do |msg|
      next if msg.type != :text || msg.data.blank?
      begin
        data = JSON.parse(msg.data)
        job.send(:handle_message, server, ws, data)
      rescue => e
        Rails.logger.error "WatchServerJob: message error on server #{server.id}: #{e.message} (data: #{msg.data.inspect})"
      end
    end

    ws.on :close do
      Rails.logger.info "WatchServerJob: connection closed for server #{server.id}"
      mutex.synchronize { closed = true; cond.signal }
    end

    ws.on :error do |e|
      Rails.logger.error "WatchServerJob: error on server #{server.id}: #{e.class} - #{e.message}"
      mutex.synchronize { closed = true; cond.signal }
    end

    deadline = Time.current + MAX_DURATION
    mutex.synchronize do
      until closed || Time.current >= deadline
        cond.wait(mutex, deadline - Time.current)
      end
    end

    ws.close rescue nil
  end

  def handle_message(server, ws, data)
    case data["type"]
    when "welcome"
      ws.send(JSON.generate({
        command: "subscribe",
        identifier: JSON.generate({ channel: "LlmJobChannel" })
      }))
    when "confirm_subscription"
      Rails.logger.info "WatchServerJob: subscribed to LlmJobChannel on server #{server.id}"
    when "ping"
      # keep-alive, ignore
    else
      if data["message"]&.fetch("new_jobs", false)
        Rails.logger.info "WatchServerJob: new jobs signal from server #{server.id}"
        GetRemoteJobsJob.perform_later
      end
    end
  end
end
