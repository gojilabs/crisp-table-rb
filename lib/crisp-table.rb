require 'crisp-table/configuration'
require 'crisp-table/application_helper'
require 'crisp-table/controller'
require 'crisp-table/table'
require 'crisp-table/version'

module CrispTable
end

require 'crisp-table/railtie' if defined?(Rails::Railtie)