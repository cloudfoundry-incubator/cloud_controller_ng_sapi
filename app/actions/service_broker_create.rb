require 'jobs/v3/synchronize_broker_catalog_job'

module VCAP::CloudController
  module V3
    class ServiceBrokerCreate
      class InvalidServiceBroker < StandardError
      end

      class SpaceNotFound < StandardError
      end

      def initialize(service_event_repository, service_manager, stepper=nil)
        @service_event_repository = service_event_repository
        @service_manager = service_manager
        @stepper = stepper
      end

      def create(message)
        params = {
          name: message.name,
          broker_url: message.url,
          auth_username: message.credentials_data.username,
          auth_password: message.credentials_data.password,
          space_guid: message.relationships_message.space_guid
        }

        broker = nil
        ServiceBroker.db.transaction do
          broker = ServiceBroker.create(params)

          ServiceBrokerState.create(
            service_broker_id: broker.id,
            state: ServiceBrokerStateEnum::SYNCHRONIZING
          )
        end

        service_event_repository.record_broker_event(:create, broker, params)

        synchronization_job = SynchronizeBrokerCatalogJob.new(broker.guid)
        pollable_job = Jobs::Enqueuer.new(synchronization_job, queue: 'cc-generic').enqueue_pollable

        { pollable_job: pollable_job }
      rescue Sequel::ValidationFailed => e
        raise InvalidServiceBroker.new(e.errors.full_messages.join(','))
      end

      private

      attr_reader :service_event_repository, :service_manager, :stepper

      def route_services_enabled?
        VCAP::CloudController::Config.config.get(:route_services_enabled)
      end

      def volume_services_enabled?
        VCAP::CloudController::Config.config.get(:volume_services_enabled)
      end
    end
  end
end
