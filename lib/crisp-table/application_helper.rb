require "react/rails/view_helper"

module CrispTable
  module ApplicationHelper
    def self.included(base)
      base.class_eval do
        include ::React::Rails::ViewHelper

        def render_table(table_name, user = nil)
          react_component 'CrispTable', props: table_name.constantize.new(controller: params[:controller]).build_table(current_user: user)
        end
      end
    end
  end
end
