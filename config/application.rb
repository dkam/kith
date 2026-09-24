require_relative "boot"
# Loaded here rather than as an initializer so Kith::VERSION exists before
# config/initializers/* run — initializers load alphabetically, so "version"
# would otherwise arrive too late for half of them.
require_relative "version"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Define Kith::VERSION before the Application class and all initializers, so
# anything that loads at boot can name the release it is part of.
require_relative "version"

module Kith
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Never hand out a blob URL. Every attachment is served by MediaController,
    # which re-checks the post's audience at request time.
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # Variants are generated on demand by MediaController, not in the request
    # that renders the page.
    config.active_storage.variant_processor = :vips

    config.generators do |g|
      g.test_framework :test_unit, fixture: true
      g.system_tests nil
      g.helper false
      g.jbuilder false
    end
  end
end
