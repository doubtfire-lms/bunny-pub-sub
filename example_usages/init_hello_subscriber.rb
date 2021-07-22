# frozen_string_literal: true

require 'dotenv/load'
require_relative '../lib/bunny-pub-sub/subscriber.rb'
require_relative '../lib/bunny-pub-sub/publisher.rb'

def receive(_subscriber_instance, channel, _results_publisher, delivery_info, _properties, params)
  # Do something meaningful here :)
  puts "Hello World! #{params}"
  # Acknowledge the message
  channel.ack(delivery_info.delivery_tag)
end


subscriber_config = {
  RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
  RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
  RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
  EXCHANGE_NAME: 'hello_exchange', # Listen at the hello exchange
  BINDING_KEYS: 'message.receive' # for message.receive
  # DEFAULT_BINDING_KEY: 'message.*'
}

# Note:
# OnTrack will have it's own publisher, which will use ROUTING_KEY.
# OnTrack will not publish the result from the subscriber action.

# Passing nil as the assessment_results_publisher
# since OnTrack will not publish the result back.
register_subscriber(subscriber_config,
                    method(:receive),
                    nil)
