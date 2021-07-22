# frozen_string_literal: true

require 'dotenv/load'
require_relative '../lib/bunny-pub-sub/publisher.rb'

# Zip files are not committed to the repo.
# Please request them if needed.
msg = {
  message: "Hello there...",
  sender: "me"
}

config = {
  RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
  RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
  RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
  EXCHANGE_NAME: 'hello_exchange',  # Exchange to send to
  DURABLE_QUEUE_NAME: 'message_q',  # Which queue to store in
  # Publisher specific key
  ROUTING_KEY: 'message.receive'    # The route key (matched binding key of subscriber)
}

publisher = Publisher.new config

publisher.connect_publisher
publisher.publish_message msg

publisher.disconnect_publisher
