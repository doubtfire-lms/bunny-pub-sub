# frozen_string_literal: true

require 'dotenv/load'
require_relative '../lib/bunny-pub-sub/publisher.rb'

# Zip files are not committed to the repo.
# Please request them if needed.
task_id = 1
timestamp = Time.now.utc.to_i
msg = {
  output_path: "overseer-pub-sub/results/#{task_id}/#{timestamp}",
  submission: "overseer-pub-sub/dev_files/dvnguyen-Practical\ Task\ 1.2.zip",
  assessment: "overseer-pub-sub/dev_files/assessment.zip",
  timestamp: timestamp,
  zip_file: 1,
  # skip_rm: 1,
  task_id: task_id
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
