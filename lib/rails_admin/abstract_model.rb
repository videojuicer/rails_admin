require 'active_support/core_ext/string/inflections'
require 'rails_admin/generic_support'

module RailsAdmin
  class AbstractModel

    attr_reader :model

    # Returns all models for a given Rails app
    def self.all
      @models ||= begin
        excluded_models = RailsAdmin::Config.excluded_models | [ History ]
        (DataMapper::Model.descendants.to_a - excluded_models).map do |model|
          new(model)
        end
      end
    end

    def self.lookup(model_name, raise_error = true)
      model = model_name.constantize
      model if model.is_a?(DataMapper::Model)
    rescue NameError
      #Rails.logger.info "#{model_name} wasn't a model"
      raise "RailsAdmin could not find model #{model_name}" if raise_error
      nil
    end

    def initialize(model)
      model = self.class.lookup(model.to_s.camelize) unless model.is_a?(Class)
      @model = model
      extend(GenericSupport)
      ### TODO more ORMs support
      require 'rails_admin/adapters/data_mapper'
      extend(RailsAdmin::Adapters::DataMapper)
    end
  end
end
