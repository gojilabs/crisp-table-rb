require 'react/rails/controller_lifecycle'
require 'react/rails/view_helper'
require 'base64'

module CrispTable
  module Controller
    extend ActiveSupport::Concern

    ACCEPTABLE_SEARCH_PARAMS = %W(
      limit
      like
      order_field
      order_reverse
      class
      table_class
      parent_id
      page
      id
      uuid
      search_params
    ).freeze

    class BulkEditError < StandardError; end

    class InvalidTableError < BulkEditError
      def initialize
        super('Invalid table')
      end
    end

    class IllegalColumnUpdateError < BulkEditError
      def initialize
        super('One of the columns you attempted to bulk edit is not allowed to be changed en masse.')
      end
    end

    included do
      include ::React::Rails::ControllerLifecycle
      include ::React::Rails::ViewHelper

      helper_method :render_table

      def render_table(table_name, user = nil)
        react_component 'CrispTable', table_name.constantize.new(controller: params[:controller]).build_table(current_user: user)
      end

      def search
        table = search_params['table_class'].constantize
        head :not_found and return unless table.ancestors.include?(CrispTable::Table)

        render json: table.new(controller: params[:controller]).request_page(search_params)
      end

      def bulk_update
        updates = {}
        table = params[:table]&.classify&.safe_constantize
        raise InvalidTableError unless table

        klass = table.starting_class
        raise UnpermittedBulkEditError unless !current_user.respond_to?(:can_commit?) || current_user.can_commit?(klass)

        params[:changed_fields].each do |column_name, value|
          column = table.bulk_editable_columns.find do |col|
            col[:field] == column_name
          end
          raise IllegalColumnUpdateError unless column

          value = Date.parse(value) if column[:type] == Table::DATE_TYPE && column[:omit_timezone]

          updates[column_name.split('.').last] = value
        end

        ApplicationRecord.transaction do
          klass.where(id: params[:ids]).find_each do |entity|
            entity.update!(updates)
          end

          klass.refresh! if klass.respond_to?(:refresh!)
        end

        msg = respond_to?(:bulk_update_success_message) ? send(:bulk_update_success_message) : 'Record(s) updated successfully'

        flash.notice = msg
        head :ok
      rescue StandardError => e
        render status: :bad_request, plain: e.message
      end

      private

      def search_params
        return @search_params if defined?(@search_params)

        @search_params = JSON.parse(
          Base64.urlsafe_decode64(
            params['q']
          )
        )

        @search_params.slice!(*ACCEPTABLE_SEARCH_PARAMS)
        @search_params = @search_params.with_indifferent_access
        @search_params
      end
    end
  end
end
