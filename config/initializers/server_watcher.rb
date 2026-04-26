Rails.application.config.after_initialize do
  next if Rails.env.test?
  next if defined?(Rails::Console)
  next if File.basename($PROGRAM_NAME) == "rake"
  next if ENV["SECRET_KEY_BASE_DUMMY"].present?

  Rails.logger.info "ServerWatcher: starting background watchers"
  ServerWatcher.start_all
end
