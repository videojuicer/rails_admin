require 'rails_admin/config/sections/list'
require 'rails_admin/abstract_object'

module RailsAdmin
  module Adapters
    module DataMapper
      def get(id)
        if object = model.get(id)
          RailsAdmin::AbstractObject.new object
        end
      end

      def get_bulk(ids, scope = nil)
        scope ||= model
        scope.all(:id => ids)
      end

      def count(options = {}, scope = nil)
        scope ||= model
        scope.count(options.except(:sort, :sort_reverse))
      end

      def first(options = {}, scope = nil)
        scope ||= model
        scope.first(merge_order(options.dup))
      end

      def all(options = {}, scope = nil)
        scope ||= model
        scope.all(merge_order(options.dup))
      end

      def paginated(options = {}, scope = nil)
        scope   ||= model
        options   = options.dup

        page       = options.delete(:page) || 1
        per_page   = options.delete(:per_page) || RailsAdmin::Config::Sections::List.default_items_per_page
        page_count = (count(options, scope).to_f / per_page).ceil

        options.update(
          :limit  => per_page,
          :offset => (page - 1) * per_page
        )

        [ page_count, all(options, scope) ]
      end

      def create(params = {})
        model.create(params)
      end

      def new(params = {})
        RailsAdmin::AbstractObject.new(model.new(params))
      end

      def destroy(ids, scope = nil)
        scope ||= model
        collection = scope.all(:id => ids)
        collection.destroy ? collection : []
      end

      def destroy_all!
        model.destroy ? model : []
      end

      def has_and_belongs_to_many_associations
        associations.select do |association|
          association[:type] == :has_and_belongs_to_many
        end
      end

      def has_many_associations
        associations.select do |association|
          association[:type] == :has_many
        end
      end

      def has_one_associations
        associations.select do |association|
          association[:type] == :has_one
        end
      end

      def belongs_to_associations
        associations.select do |association|
          association[:type] == :belongs_to
        end
      end

      def associations
        model.relationships.map do |relationship|
          {
            :name         => relationship.name,
            :pretty_name  => relationship.name.to_s.tr('_', ' ').capitalize,
            :type         => relationship_type_for(relationship),
            :parent_model => relationship.parent_model,
            :parent_key   => relationship.parent_key.map { |property| property.name },
            :child_model  => relationship.child_model,
            :child_key    => relationship.child_key.map { |property| property.name },
            :options      => {},
          }
        end
      end

      def properties
        model.properties.map do |property|
          length = property.length if property.respond_to?(:length)

          if length.kind_of?(Range)
            length = length.exclude_end? ? length.last.pred : length.last
          end

          {
            :name        => property.name,
            :pretty_name => property.name.to_s.tr('_', ' ').capitalize,
            :type        => property_type_for(property),
            :length      => length,
            :nullable?   => !property.required?,
            :serial?     => property.serial?,
          }
        end
      end

      def model_store_exists?
        true  # TODO: determine if storage exists
      end

    private

      def merge_order(options)
        # TODO: handle other PKs
        sort = (options.delete(:sort) || :id).to_sym
        sort = sort.desc if options.delete(:sort_reverse) == 'desc'
        options.update(:order => [ sort ])
      end

      def relationship_type_for(relationship)
        case relationship
        when ::DataMapper::Associations::ManyToMany::Relationship then :has_and_belongs_to_many
        when ::DataMapper::Associations::OneToMany::Relationship  then :has_many
        when ::DataMapper::Associations::OneToOne::Relationship   then :has_one
        when ::DataMapper::Associations::ManyToOne::Relationship  then :belongs_to
        end
      end

      def property_type_for(property)
        case property
        when ::DataMapper::Property::Binary   then :binary
        when ::DataMapper::Property::Boolean  then :boolean
        when ::DataMapper::Property::Class    then :string
        when ::DataMapper::Property::Date     then :date
        when ::DataMapper::Property::DateTime then :datetime
        when ::DataMapper::Property::Decimal  then :decimal
        when ::DataMapper::Property::Float    then :float
        when ::DataMapper::Property::Integer  then :integer
        when ::DataMapper::Property::Text     then :text
        when ::DataMapper::Property::Time     then :time
        else
          :string
        end
      end

    end
  end
end
