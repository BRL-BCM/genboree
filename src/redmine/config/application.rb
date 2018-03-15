require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module RedmineApp
  class Application < Rails::Application
    # Implement the Rails 4 Rails::Application#initialized? method to the
    #   Redmine Application class. This lets us check whether we're running
    #   in an initialized application or not, which of interest to automation
    #   rake tasks that run outside of the Redmine web process but wish to behave
    #   much like a Controller. Specifically much like a Plugin Controller with
    #   all the productivity conveniences (before_filters) and other reusables.
    def initialized?()
      return @initialized
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    config.active_record.store_full_sti_class = true
    config.active_record.default_timezone = :local

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # BRL - TEMP OFF
    #config.asset_path = "/genboreeKB_dev%s"

    # Enable the asset pipeline
    config.assets.enabled = false
    # BRL
    # - turn on asset pipeline
    #config.assets.enabled = true
    # - don't compress (web server will do on fly, probably nginx)
    #config.assets.compress = false
    # - use digests in name
    #config.assets.digest = true
    # - expands lines that load assets
    #config.assets.debug = true
    # - don't fall back to assets pipeline if miss precompiled asset
    #config.assets.compile = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.2'
    
    #config.assets.cache_store = :null_store

    config.action_mailer.perform_deliveries = false

    # Do not include all helpers
    config.action_controller.include_all_helpers = false

    config.session_store :cookie_store, :key => '_redmine_session'

    if File.exists?(File.join(File.dirname(__FILE__), 'additional_environment.rb'))
      instance_eval File.read(File.join(File.dirname(__FILE__), 'additional_environment.rb'))
    end
  end
end
