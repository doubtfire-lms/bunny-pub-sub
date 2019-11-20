# frozen_string_literal: true

require 'dotenv/load'
require_relative '../lib/bunny-pub-sub/services_manager.rb'
require_relative 'overseer_receive_action.rb'

sm_instance = ServicesManager.instance
# puts sm_instance.object_id

publisher_config = {
  RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
  # RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
  RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
  EXCHANGE_NAME: ENV['EXCHANGE_NAME'],
  DURABLE_QUEUE_NAME: ENV['DURABLE_QUEUE_NAME'],
  BINDING_KEYS: ENV['BINDING_KEYS'],
  DEFAULT_BINDING_KEY: ENV['DEFAULT_BINDING_KEY'],
  # Publisher specific key
  ROUTING_KEY: 'csharp'
}

msg = {
  submission: "dev_files/dvnguyen-Practical\ Task\ 1.2.zip",
  assessment: "dev_files/assessment\ 2.zip",
  task_id: 1
}

sm_instance.register_client(:overseer)
sm_instance.create_client_publisher(:overseer, publisher_config)
sm_instance.clients[:overseer].publisher.connect_publisher
sm_instance.clients[:overseer].publisher.publish_message(msg)
sm_instance.clients[:overseer].publisher.disconnect_publisher

# puts sm_instance.clients[:overseer].publisher.inspect

#################################################################
# Blocking subscriber code BEGINS
#################################################################

# subscriber_config = {
#   RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
#   RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
#   RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
#   EXCHANGE_NAME: ENV['EXCHANGE_NAME'],
#   DURABLE_QUEUE_NAME: ENV['DURABLE_QUEUE_NAME'],
#   BINDING_KEYS: ENV['BINDING_KEYS'],
#   DEFAULT_BINDING_KEY: ENV['DEFAULT_BINDING_KEY']
# }

# assessment_results_publisher_config = {
#   RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
#   RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
#   RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
#   EXCHANGE_NAME: ENV['EXCHANGE_NAME'],
#   DURABLE_QUEUE_NAME: 'assessment_results',
#   BINDING_KEYS: ENV['BINDING_KEYS'],
#   DEFAULT_BINDING_KEY: ENV['DEFAULT_BINDING_KEY'],
#   # Publisher specific key
#   # Note: `*.result` works too, but it makes no sense using that.
#   ROUTING_KEY: 'assessment.result'
# }

# assessment_results_client = sm_instance.register_client(
#   :assessment_results_publisher,
#   assessment_results_publisher_config
# )

# sm_instance.create_and_start_client_subscriber(
#   :overseer, subscriber_config,
#   method(:receive), assessment_results_client.publisher
# )

#################################################################
# Blocking subscriber code ENDS
#################################################################

sm_instance.deregister_client(:overseer)
# puts sm_instance.inspect
