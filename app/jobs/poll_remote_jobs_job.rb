class PollRemoteJobsJob < ApplicationJob
  queue_as :default

  def perform
    servers = Server.all

    if servers.none?
      Rails.logger.info "No servers configured for polling"
      return
    end

    servers.find_each do |server|
      WatchServerJob.perform_later(server.id)
    end
  end
end
