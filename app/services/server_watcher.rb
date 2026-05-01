require "websocket-client-simple"
require "json"

class ServerWatcher
  RECONNECT_DELAY = 5
  PING_TIMEOUT = 15

  def self.start_all
    Server.find_each { |server| start(server) }
  end

  def self.start(server)
    Thread.new do
      loop do
        watch(server)
        sleep RECONNECT_DELAY
      rescue => e
        Rails.logger.error "ServerWatcher: error on server #{server.id}: #{e.message}"
        sleep RECONNECT_DELAY
      end
    end
  end

  def self.watch(server)
    token = GetRemoteJobsJob.new.ensure_authenticated(server)
    unless token
      Rails.logger.error "ServerWatcher: failed to authenticate with server #{server.id}"
      return
    end

    uri = URI(server.url)
    ws_scheme = uri.scheme == "https" ? "wss" : "ws"
    cable_url = "#{ws_scheme}://#{uri.host}/cable?token=#{URI.encode_www_form_component(token)}"
    origin = "#{uri.scheme}://#{uri.host}"

    Rails.logger.info "ServerWatcher: connecting to server #{server.id}"

    mutex = Mutex.new
    cond = ConditionVariable.new
    closed = false
    last_ping_at = Time.current

    ws = WebSocket::Client::Simple.connect(cable_url, headers: { "Origin" => origin })

    ws.on :open do
      Rails.logger.info "ServerWatcher: connected to server #{server.id}"
    end

    ws.on :message do |msg|
      next if msg.type != :text || msg.data.blank?
      begin
        data = JSON.parse(msg.data)
        case data["type"]
        when "welcome"
          ws.send(JSON.generate({
            command: "subscribe",
            identifier: JSON.generate({ channel: "LlmJobChannel" })
          }))
        when "confirm_subscription"
          Rails.logger.info "ServerWatcher: subscribed to LlmJobChannel on server #{server.id}"
          GetRemoteJobsJob.perform_later
        when "ping"
          mutex.synchronize { last_ping_at = Time.current; cond.signal }
        else
          if data["message"]&.fetch("new_jobs", false)
            Rails.logger.info "ServerWatcher: new jobs signal from server #{server.id}"
            GetRemoteJobsJob.perform_later
          end
        end
      rescue => e
        Rails.logger.error "ServerWatcher: message error on server #{server.id}: #{e.message}"
      end
    end

    ws.on :close do
      Rails.logger.info "ServerWatcher: connection closed for server #{server.id}"
      mutex.synchronize { closed = true; cond.signal }
    end

    ws.on :error do |e|
      Rails.logger.error "ServerWatcher: error on server #{server.id}: #{e.message}"
      mutex.synchronize { closed = true; cond.signal }
    end

    mutex.synchronize do
      until closed
        cond.wait(mutex, PING_TIMEOUT)
        break if closed
        if Time.current - last_ping_at > PING_TIMEOUT
          Rails.logger.warn "ServerWatcher: no ping received for #{PING_TIMEOUT}s on server #{server.id}, reconnecting"
          break
        end
      end
    end

    ws.close rescue nil
  end
end
