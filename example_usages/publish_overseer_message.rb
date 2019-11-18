# frozen_string_literal: true

require 'dotenv/load'
require_relative '../lib/bunny-pub-sub/publisher.rb'

# Zip files are not committed to the repo.
# Please request them if needed.
msg = {
  submission: "dev_files/dvnguyen-Practical\ Task\ 1.2.zip",
  assessment: "dev_files/assessment\ 2.zip",
  # TODO: Probably don't need this.
  # :project_id => 1,

  # task_id can come directly from
  # POST '/projects/:id/task_def_id/:task_definition_id/submission' API.
  task_id: 1
}

config = {
  RABBITMQ_HOSTNAME: ENV['RABBITMQ_HOSTNAME'],
  RABBITMQ_USERNAME: ENV['RABBITMQ_USERNAME'],
  RABBITMQ_PASSWORD: ENV['RABBITMQ_PASSWORD'],
  EXCHANGE_NAME: ENV['EXCHANGE_NAME'],
  DURABLE_QUEUE_NAME: ENV['DURABLE_QUEUE_NAME'],
  BINDING_KEYS: ENV['BINDING_KEYS'],
  DEFAULT_BINDING_KEY: ENV['DEFAULT_BINDING_KEY'],
  # Publisher specific key
  ROUTING_KEY: 'csharp'
}

publisher = Publisher.new config

publisher.connect_publisher
publisher.publish_message msg

publisher.disconnect_publisher
