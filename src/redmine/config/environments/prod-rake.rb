# Settings specified here will take precedence over those in config/application.rb
RedmineApp::Application.configure do
  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = false

  #####
  # Customize the default logger (http://ruby-doc.org/core/classes/Logger.html)
  #
  # Use a different logger for distributed setups
  # config.logger        = SyslogLogger.new
  #
  # Rotate logs bigger than 1MB, keeps no more than 7 rotated logs around.
  # When setting a new Logger, make sure to set it's log level too.
  #
  # config.logger = Logger.new(config.log_path, 7, 1048576)
  # config.logger.level = Logger::INFO

  # Full error reports are disabled and caching is turned on
  #config.action_controller.perform_caching = true
  config.action_controller.perform_caching = false

  # BRL: Turn on concurrency?
  #config.allow_concurrency = false

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host                  = "http://assets.example.com"

  # Disable delivery errors if you bad email addresses should just be ignored
  config.action_mailer.raise_delivery_errors = false

  # No email in production log
  config.action_mailer.logger = nil

  config.active_support.deprecation = :log

  # BRL: X-Accel-Redirect direct-file-sending support via nginx:
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'
  
  #BRL: Activate additional debug dumping to logs
  #config.log_level = :debug

  # BRL: rake tasks should log elsewhere NOT to redmine's production.log or development.log!
  # - rake task can log to STDERR
  config.logger = Logger.new(STDERR)
  config.logger.level = Logger::ERROR # instead of Logger::INFO
end

I18n.enforce_available_locales = false

