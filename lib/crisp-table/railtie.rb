module CrispTable
  class Railtie < Rails::Railtie
    config.to_prepare do
      CrispTable::Configuration.timezone ||= (
        Rails.application.config.time_zone ||
        ENV.fetch('TZ') do
          ENV.fetch('TIMEZONE') do
            'Etc/UTC'
          end
        end
      )
    end
  end
end
