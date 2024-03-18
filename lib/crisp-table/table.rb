module CrispTable
  class Table

    BOOLEAN_TYPE = 'Boolean'.freeze
    INTEGER_TYPE = 'Integer'.freeze
    STRING_TYPE = 'String'.freeze
    TIME_TYPE = 'Time'.freeze
    DATE_TYPE = 'Date'.freeze
    MONEY_TYPE = 'Money'.freeze
    USD_MONEY_TYPE = 'UsdMoney'.freeze

    RANGED_TYPES = [
      INTEGER_TYPE,
      TIME_TYPE,
      DATE_TYPE,
      MONEY_TYPE,
      USD_MONEY_TYPE,
    ].freeze

    TIMEZONED_TYPES = [
      TIME_TYPE,
      DATE_TYPE
    ].freeze

    def initialize(*args)
      opts = args.extract_options!
      @attachment_values = (args || []).flatten
      @attachments = {}
      @attachment_values.each_with_index do |attachment_value, index|
        @attachments[self.class.attach[index]] = attachment_value
      end

      @base_query = opts[:base_query]
      @entity_search_id = opts[:parent_id]
      @search_path = opts[:search_path]
      controller = opts[:controller]
      if controller
        @plural_route_root = controller.to_s.underscore.remove('_controller').gsub(/\//, '_')
        @singular_route_root = @plural_route_root.singularize
      end
    end

    def self.starting_class(activerecord_class = nil)
      @starting_class ||= (activerecord_class || name.underscore[0...-6].split('::').last.singularize.classify.constantize)
    end

    def self.columns(descriptor = nil)
      @columns ||= descriptor.map do |column|
        column[:table] ||= column[:association]&.to_s&.pluralize || starting_class.table_name
        if column.key?(:name)
          column[:field] = "#{column[:table]}.#{column[:name]}" if column[:field].blank?
          column[:title] = column[:name].to_s.titleize if column[:title].blank?
        end
        column[:field] = column[:field].to_s if column.key?(:field)
        column[:value_type] ||= column[:type]
        column[:sortable] = true unless column.key?(:sortable)
        column[:searchable] = true unless column.key?(:searchable)

        column[:bulk_editable] = true unless column.key?(:bulk_editable)
        column[:bulk_editable] = bulk_update_path.present? if column[:name] == :created_at || column[:name] == :updated_at || column[:association] || column[:join] || column[:left_join]

        column[:range] = RANGED_TYPES.include?(column[:type]) unless column.key?(:range)
        column[:timezone] = (column[:timezone].presence || CrispTable::Configuration.timezone) if TIMEZONED_TYPES.include?(column[:type])
        column
      end
    end

    def self.disable_routes(*args)
      if args.present? && !defined?(@disabled_routes)
        @disabled_routes = [args]
        @disabled_routes.flatten!
        @disabled_routes.compact!
        @disabled_routes.uniq!
      end

      @disabled_routes
    end

    def self.route_disabled?(route)
      disable_routes.present? && (disable_routes.include?(route) || disable_routes.include?(route.to_s))
    end

    def self.new_route_disabled?
      route_disabled?(:new)
    end

    def self.search_route_disabled?
      route_disabled?(:search)
    end

    def self.show_route_disabled?
      route_disabled?(:show)
    end

    def self.update_route_disabled?
      route_disabled?(:update)
    end

    def self.destroy_route_disabled?
      route_disabled?(:destroy)
    end

    def self.query_columns
      @query_columns ||= columns.select do |column|
        column.key?(:name) || column.key?(:field) || column.key?(:view_field) || column.key?(:column)
      end
    end

    def self.hide_when_empty(default = false)
      @hide_when_empty = default unless defined?(@hide_when_empty)
      @hide_when_empty
    end

    def self.query_column_name(column)
      (column[:name] || column[:field] || column[:view_field] || column[:column]).to_s
    end

    def self.bulk_editable_columns
      @bulk_editable_columns ||= query_columns.select { |column| column[:bulk_editable] }
    end

    def self.query_column_names
      @query_column_names ||= query_columns.map { |column| query_column_name(column) }
    end

    def self.title(name = nil)
      @title ||= (name || starting_class.to_s.titleize)
    end

    def self.attach(fields = [])
      @attach ||= [fields].flatten
    end

    def self.id_column(column_name = nil)
      @id_column ||= (column_name || "#{starting_class.table_name}.#{starting_class.primary_key}")
    end

    def self.query(sql = nil)
      @query ||= sql
    end

    def self.distinct(option = false)
      @distinct ||= option
    end

    # expecting order to be a string of format "field (ASC | DESC)"
    def self.default_order(order = nil)
      @default_order ||= order
    end

    def self.rows_per_page(count = nil)
      @rows_per_page ||= (count || 25)
    end

    def self.show_path(path = nil)
      @show_path ||= path
    end

    def self.update_path(path = nil)
      @update_path ||= path
    end

    def self.delete_path(path = nil)
      @delete_path ||= path
    end

    def self.new_path(path = nil)
      @new_path ||= path
    end

    def self.search_path(path = nil)
      @search_path ||= path
    end

    def self.bulk_update_path(path = nil)
      @bulk_update_path ||= path || (@plural_route_root && path_for(@plural_route_root, :bulk_update))
    end

    def self.column_search_field(column)
      "#{column[:table]}.#{column[:foreign_key] || column[:name] || column[:view_field] || column[:field]}"
    end

    def self.generate_range_search_clause(column, min, max)
      select_column = column_search_field(column)
      formatted_max = format_search_param(column, max) if max
      formatted_min = format_search_param(column, min) if min

      if formatted_max && formatted_min
        "#{select_column} BETWEEN #{formatted_min} AND #{formatted_max}"
      elsif formatted_max
        "#{select_column} <= #{formatted_max}"
      elsif formatted_min
        "#{select_column} >= #{formatted_min}"
      else
        "#{selected_column} IS NULL"
      end
    end

    def self.generate_exact_match_clause(column, value)
      formatted_field = column_search_field(column)


      return "#{formatted_field} = '#{value ? 't' : 'f'}'" if column[:type] == BOOLEAN_TYPE
      return "#{formatted_field} IS NULL" if value.blank?

      formatted_value = format_search_param(column, value)

      return "LOWER(#{formatted_field}) = LOWER(#{formatted_value})" if column[:type] == STRING_TYPE && (!column[:value_type] || column[:value_type] == STRING_TYPE)
      "#{formatted_field} = #{formatted_value}"
    end

    def self.generate_fuzzy_match_clause(column, value)
      "#{column_search_field(column)} ILIKE #{format_search_param(column, value.gsub('*', '%'))}"
    end

    def self.generate_match_clause(column, value)
      return generate_fuzzy_match_clause(column, value) if column[:type] == STRING_TYPE && value.include?('*')
      generate_exact_match_clause(column, value)
    end

    def self.generate_search_clause(column, value, max = nil)
      if max || column[:range]
        column_min = column[:min]
        column_max = column[:max]

        min = value if value && (!column_min || value > column_min) && (!column_max || value < column_max)
        min ||= column_min

        max = max if max && (!column_max || max < column_max) && (!min || max > min)
        max ||= column_max

        generate_range_search_clause(column, min, max)
      elsif column[:select_options]
        generate_exact_match_clause(column, value)
      else
        generate_match_clause(column, value)
      end
    end

    def self.format_search_param(column, value)
      case column[:value_type]
      when STRING_TYPE
        "'#{value}'"
      when DATE_TYPE, TIME_TYPE
        opts = {
          year: value[0...4].to_i,
          month: value[5...7].to_i,
          day: value[8...10].to_i,
          hour: 0,
          min: 0,
          sec: 0
        }
        if column[:value_type] == TIME_TYPE
          opts[:hour] = value[11...13].to_i
          opts[:min] = value[14...16].to_i
          opts[:sec] = value[17...19].to_i
        end
        timestamp = DateTime.new.in_time_zone(column[:timezone]).change(opts)
        "'#{timestamp.to_s(:db)}'::timestamptz"
      when BOOLEAN_TYPE
        "'#{value ? 't' : 'f'}'"
      when INTEGER_TYPE, MONEY_TYPE, USD_MONEY_TYPE
        (value.to_f * 100).to_i
      else
        raise "Invalid column value type '#{column[:value_type]}' on '#{column[:field]}"
      end
    end

    def self.search_statements(search)
      search.map do |column_key, value|
        column = columns.detect { |col| col[:field] == column_key}

        if column
          if value.is_a?(Hash)
            generate_search_clause(column, value['from'], value['to'])
          else
            generate_search_clause(column, value)
          end
        end

      end.compact
    end

    def self.like_statement(like_value)
      return nil if like_value.blank? || like_value == ''
      searchable_columns.map do |column|
        "CAST(#{column[:field]} AS text) ILIKE '%#{like_value}%'"
      end.join(' OR ')
    end

    def self.where_statement(search, like)
      search_clause = search_statements(search).join(' AND ') if search.present?
      like_clause = like_statement(like) if like.present?

      search_clause = search_clause.gsub(/orders\.total/, 'pricing.total') if search_clause&.include?('orders.total')

      if search_clause && like_clause
        "#{search_clause} AND (#{like_clause})"
      elsif search_clause
        search_clause
      elsif like_clause
        like_clause
      else
        ''
      end
    end

    def self.activerecord_like_statement(like)
      return nil if like.blank?

      like_value = like_clause(like)
      [like_statement('?')] + searchable_columns.length.times.map { like_value }
    end

    def self.select_statement
      [id_column] + query_columns.map { |column| [column[:view_field], column[:field]].compact }.flatten
    end

    def self.joins_statement
      query_columns.map { |column| column[:association] || column[:join] }.compact.uniq
    end

    def self.left_joins_statement
      query_columns.map { |column| column[:left_join] }.compact.uniq
    end

    # expecting new_order to be of format {field: FIELDNAME, reverse: BOOLEAN}
    def self.order_statement(field, reverse)
      has_field = field.present?
      field_added = false
      query_columns.inject([default_order].compact) do |acc, column|
        if !column.key?(:sortable) || column[:sortable]
          string_type = column[:type] == STRING_TYPE
          current_field = column[:field]
          if has_field && !field_added && field == current_field
            direction =
              if column[:type] == BOOLEAN_TYPE
                reverse ? 'ASC NULLS FIRST' : 'DESC NULLS LAST'
              elsif string_type
                reverse ? 'DESC' : 'ASC'
              else
                reverse ? 'ASC' : 'DESC'
              end
            acc.unshift("#{current_field} #{direction}")
            field_added = true
          else
            direction = string_type ? 'ASC' : 'DESC'
            acc.push("#{current_field} #{direction}")
          end
        end
        acc
      end.join(', ')
    end

    def self.searchable_columns
      query_columns.select { |column| !column.key?(:searchable) || column[:searchable] }
    end

    def self.path_for(route_root, path_method = nil, id = nil)
      return nil unless route_root
      route_method = path_method ? "#{path_method}_#{route_root}" : route_root.to_s
      route_method << '_path' unless route_method.ends_with?('_path')
      args = [route_method, id].compact
      Rails.application.routes.url_helpers.try(*args)
    end

    def build_page
      @page ||= {
        columns: decorate_columns,
        attachments: @attachments,
        records: [],
        records_count: 0,
        results_count: 0
      }

      @page
    end

    def decorate_columns
      self.class.columns.map do |column|
        edit_descriptor = column[:editable]
        if edit_descriptor
          options_generator = edit_descriptor[:options_generator]
          if options_generator
            column[:editable][:options] = options_generator.call
          end
        end

        select_options = column[:select_options]
        if select_options && select_options.is_a?(Hash)
          column[:select_options] = select_options[:generator].call.map do |label_and_value|
            if label_and_value.is_a?(Array) && label_and_value.length == 2
              { label: label_and_value.first, value: label_and_value.last }
            elsif label_and_value.is_a?(Hash) && label_and_value.key?(:label) && label_and_value.key?(:value)
              label_and_value
            else
              { label: label_and_value, value: label_and_value }
            end
          end
          column[:foreign_key] = select_options[:foreign_key] if select_options[:foreign_key].present?
        end
        column
      end
    end

    def build_table(opts = {})
      klass = self.class
      title = klass.title
      current_user = opts[:current_user]
      entity_class = klass.starting_class
      page = request_page(opts)
      page[:page_length] = klass.rows_per_page
      page[:table_class] = klass.name
      page[:page] = 1
      page[:new_path] = generate_new_path
      page[:search_path] = generate_search_path
      page[:bulk_update_path] = klass.path_for(@plural_route_root, :bulk_update) if klass.bulk_editable_columns.present? && (current_user.respond_to?(:can_commit) ? current_user.can_commit?(entity_class) : true)
      page[:table_name] = title.underscore
      page[:title] = title
      page[:prefix] = "#{klass.name.underscore}_"
      page[:can_save] = opts[:current_user] && (!current_user.respond_to?(:can_save?) || current_user.can_save?(entity_class))
      page
    end

    def search_params(options = {})
      options[:search_params]
    end

    def request_page(opts = {})
      records_list = records(opts)
      return build_page if records_list.blank? && self.class.hide_when_empty

      build_page.merge(
        records: records_list,
        records_count: records_count,
        results_count: results_count(search_params(opts), opts[:like])
      )
    end

    private

    def generate_new_path
      return nil if self.class.new_route_disabled?

      self.class.path_for(self.class.new_path, nil, @entity_search_id) ||
      self.class.path_for(@singular_route_root, :new, @entity_search_id)
    end

    def generate_search_path
      return nil if self.class.search_route_disabled?
      @search_path ||
      self.class.path_for(self.class.search_path, nil, @entity_search_id) ||
      self.class.path_for(@plural_route_root, :search, @entity_search_id)
    end

    def generate_show_path(id)
      return nil if self.class.show_route_disabled?

      self.class.path_for(self.class.show_path, nil, id) ||
      self.class.path_for(@singular_route_root, nil, id)
    end

    def generate_update_path(id)
      return nil if self.class.update_route_disabled?

      self.class.path_for(self.class.update_path, nil, id) ||
      self.class.path_for(@singular_route_root, nil, id)
    end

    def generate_destroy_path(id)
      return nil if self.class.destroy_route_disabled?

      self.class.path_for(self.class.delete_path, nil, id) ||
      self.class.path_for(@singular_route_root, nil, id)
    end

    def records_count
      return results_count(nil, nil) if self.class.query.present?
      ActiveRecord::Base.connection.exec_query("SELECT COUNT(id) FROM (#{(@base_query || self.class.starting_class.all).to_sql}) crisp_table").first.first
    end

    def results_count(search, like)
      return sql_count_query(search, like) if self.class.query.present?
      activerecord_count_query(search, like)
    end

    def records(opts = {})
      klass = self.class
      if opts[:limit] != 'All'
        limit = opts[:limit].to_i
        limit = limit > 0 && limit <= 1000 ? limit : klass.rows_per_page

        cursor = opts[:page].to_i - 1
        cursor = cursor < 0 ? 0 : cursor
        offset = cursor * limit
      end

      order = klass.order_statement(opts[:order_field], opts[:order_reverse].to_s.casecmp('true') == 0)
      query_function = klass.query.present? ? :sql_query : :activerecord_query
      column_count = klass.query_columns.length
      like = opts[:like] if opts[:like].present?

      send(query_function, search_params(opts), like, order, limit, offset).rows.map do |row|
        id = row[0]
        {
          show_path: generate_show_path(id),
          update_path: generate_update_path(id),
          delete_path: generate_destroy_path(id),
          id: id,
          record: (1..column_count).map do |column_index|
                    field = row[column_index]
                    klass.query_columns[column_index]&.[](:filter)&.call(row, field) || field
                  end
        }
      end
    end

    def sql_count_query(search, like)
      where_statement = self.class.where_statement(search, like) if search.present? || like.present?
      row_query = self.class.query.dup % @attachment_values
      row_query << " WHERE #{where_statement}" if where_statement.present?
      count_query = "SELECT COUNT(id) FROM (#{row_query}) temp"
      ActiveRecord::Base.connection.exec_query(count_query.split.join(' ')).first['count']
    end

    def sql_query(search, like, order, limit, offset)
      where_statement = self.class.where_statement(search, like) if search.present? || like.present?
      query = self.class.query.dup
      query = query % @attachment_values if @attachment_values.present?
      query << "\nWHERE #{where_statement}" if where_statement.present?
      query << "\nORDER BY #{order}"
      query << "\nLIMIT #{limit}" unless limit.nil?
      query << "\nOFFSET #{offset}" unless offset.nil?
      @sql_query = query.split.join(' ')
      ActiveRecord::Base.connection.exec_query(@sql_query)
    end

    def activerecord_count_query(search, like)
      joins_statement = self.class.joins_statement
      left_joins_statement = self.class.left_joins_statement
      where_statement = self.class.where_statement(search, like)

      query = @base_query || self.class.starting_class.all
      query = query.joins(*joins_statement) if joins_statement.present?
      query = query.left_joins(*left_joins_statement) if left_joins_statement.present?
      query = query.where(where_statement) if where_statement.present?
      query = query.distinct if self.class.distinct

      count_query = "SELECT COUNT(id) FROM (#{query.to_sql}) temp"
      ActiveRecord::Base.connection.exec_query(count_query.split.join(' ')).first['count']
    end

    def activerecord_query(search, like, order, limit, offset)
      select_statement = self.class.select_statement
      joins_statement = self.class.joins_statement
      left_joins_statement = self.class.left_joins_statement
      where_statement = self.class.where_statement(search, like)

      query = @base_query || self.class.starting_class
      query = query.select(select_statement) if select_statement.present?
      query = query.joins(*joins_statement) if joins_statement.present?
      query = query.left_joins(*left_joins_statement) if left_joins_statement.present?
      query = query.where(where_statement) if where_statement.present?
      query = query.order(order)
      query = query.limit(limit) unless limit.nil?
      query = query.offset(offset) unless offset.nil?
      query = query.distinct if self.class.distinct
      @sql_query = query.to_sql.split.join(' ')
      ActiveRecord::Base.connection.exec_query(@sql_query)
    end
  end
end
