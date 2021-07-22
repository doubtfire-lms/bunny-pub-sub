# frozen_string_literal: true

require 'dotenv/load'
require_relative '../lib/bunny-pub-sub/services_manager.rb'
require_relative 'overseer_receive_action.rb'

sm_instance = ServicesManager.instance
# puts sm_instance.object_id

publisher_config = {
  RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
  RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
  RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
  EXCHANGE_NAME: 'hello_exchange',
  DURABLE_QUEUE_NAME: 'message_q',
  # BINDING_KEYS: 'message.receive', # Binding key for receiving
  # DEFAULT_BINDING_KEY: 'message.receive',
  # Publisher specific key
  ROUTING_KEY: 'message.receive' # for sending
}

msg = {
  text: "Hello World",
  other: 1
}

sm_instance.register_client(:overseer)
sm_instance.create_client_publisher(:overseer, publisher_config)
sm_instance.clients[:overseer].publisher.connect_publisher
sm_instance.clients[:overseer].publisher.publish_message(msg)
sm_instance.clients[:overseer].publisher.disconnect_publisher

#################################################################
# Blocking subscriber code ENDS
#################################################################

sm_instance.deregister_client(:overseer)
# puts sm_instance.inspect
