# frozen_string_literal: true

require 'dotenv/load'
require_relative 'ontrack_receive_action.rb'
require_relative '../lib/bunny-pub-sub/subscriber.rb'
require_relative '../lib/bunny-pub-sub/publisher.rb'

subscriber_config = {
  RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
  RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
  RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
  EXCHANGE_NAME: ENV['EXCHANGE_NAME'],
  DURABLE_QUEUE_NAME: 'q_assessment_results',
  # No need to define BINDING_KEYS for now!
  # In future, OnTrack will listen to
  # topics related to PDF generation too.
  # That is when we should have BINDING_KEYS defined.
  # BINDING_KEYS: ENV['BINDING_KEYS'],

  # This is enough for now:
  DEFAULT_BINDING_KEY: '*.result'
}

# Note:
# OnTrack will have it's own publisher, which will use ROUTING_KEY.
# OnTrack will not publish the result from the subscriber action.

# Passing nil as the assessment_results_publisher
# since OnTrack will not publish the result back.
register_subscriber(subscriber_config,
                    method(:receive),
                    nil)
