module VCAP::Services::ServiceBrokers::V2
  class CatalogPlan
    include CatalogValidationHelper

    attr_reader :broker_provided_id, :name, :description, :metadata, :maximum_polling_duration, :maintenance_info
    attr_reader :catalog_service, :errors, :free, :bindable, :schemas, :plan_updateable

    def initialize(catalog_service, attrs)
      @catalog_service    = catalog_service
      @broker_provided_id = attrs['id']
      @metadata           = attrs['metadata']
      @name               = attrs['name']
      @description        = attrs['description']
      @errors             = VCAP::Services::ValidationErrors.new
      @free               = attrs['free'].nil? ? true : attrs['free']
      @bindable           = attrs['bindable']
      @plan_updateable    = attrs['plan_updateable']
      @maximum_polling_duration = attrs['maximum_polling_duration']
      @maintenance_info = attrs['maintenance_info']
      build_schemas(attrs['schemas'])
    end

    def build_schemas(schemas)
      return if schemas.nil?

      @schemas_data = schemas

      if @schemas_data.is_a? Hash
        @schemas = CatalogSchemas.new(schemas)
      end
    end

    def valid?
      return @valid if defined? @valid

      validate!
      validate_schemas!
      @valid = errors.empty?
    end

    delegate :cc_service, to: :catalog_service

    private

    def validate!
      validate_string!(:broker_provided_id, broker_provided_id, required: true)
      validate_string!(:name, name, required: true)
      validate_description!(:description, description, required: true)
      validate_hash!(:metadata, metadata) if metadata
      validate_bool!(:free, free) if free
      validate_bool!(:bindable, bindable) if bindable
      validate_bool!(:plan_updateable, plan_updateable) if plan_updateable
      validate_integer!(:maximum_polling_duration, maximum_polling_duration) if maximum_polling_duration
      # TODO: proper validation of maintenance_info
      # validate_hash!(:maintenance_info, @maintenance_info) if @maintenance_info
      validate_hash!(:schemas, @schemas_data) if @schemas_data

      validate_maintenance_info!
    end

    def validate_maintenance_info!
      return if @maintenance_info.nil?

      validate_hash!(:maintenance_info, @maintenance_info)
      # validate_string!(:maintenance_info_version, @maintenance_info['version'], required: true)
      validate_semver!(:maintenance_info_version, @maintenance_info['version'], required: true)
    end

    def validate_schemas!
      if schemas && !schemas.valid?
        errors.add_nested(schemas, schemas.errors)
      end
    end

    def human_readable_attr_name(name)
      {
        broker_provided_id:         'Plan id',
        name:                       'Plan name',
        description:                'Plan description',
        metadata:                   'Plan metadata',
        free:                       'Plan free',
        bindable:                   'Plan bindable',
        plan_updateable:            'Plan updateable',
        schemas:                    'Plan schemas',
        maintenance_info:           'Maintenance info',
        maintenance_info_version:   'Maintenance info version',
        maximum_polling_duration:   'Maximum polling duration',
      }.fetch(name) { raise NotImplementedError }
    end
  end
end
