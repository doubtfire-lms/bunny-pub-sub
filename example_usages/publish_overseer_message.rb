# frozen_string_literal: true

require 'dotenv/load'
require_relative '../lib/bunny-pub-sub/publisher.rb'

# Zip files are not committed to the repo.
# Please request them if needed.
task_id = 1
timestamp = Time.now.utc.to_i
msg = {
  # output_path: "../overseer-pub-sub/results/#{task_id}/#{timestamp}",
  output_path: "/var/tmp/host-dir/results/#{task_id}/#{timestamp}",
  submission: "../overseer-pub-sub/dev_files/1.2student-task.zip",
  assessment: "../overseer-pub-sub/dev_files/A12-assessment.zip",

  # output_path: "/ontrack-files/results/#{task_id}/#{timestamp}",
  # submission: "/ontrack-files/student-work/submission_history/COS20007-2/cliff/done/1/1.2student-task.zip", # TODO: :((
  # assessment: "/ontrack-files/student_work/COS20007-2/TaskFiles/A12-assessment.zip",
  # # Users/akashagarwal/ruby/doubtfire-api/ -> volume as ontrack-files in docker container (for now)
  # # inside VM the former path will be different.
  # # Users/akashagarwal/ruby/doubtfire-api/ -> symlink as ontrack-files on local-machine (for now)
  timestamp: timestamp,
  zip_file: 1,
  skip_rm: 1,
  task_id: task_id,
  docker_image_name_tag: 'overseer/dotnet:2.2'
}

msg_for_dev_server = {
  output_path: "/var/tmp/ontrack-files/submission_history/some_unit/some_student_username/#{task_id}/#{timestamp}",
  submission: "/var/tmp/ontrack-files/1.2student-task.zip",
  assessment: "/var/tmp/ontrack-files/A12-assessment.zip",
  timestamp: timestamp,
  zip_file: 1,
  # skip_rm: 1,
  task_id: task_id,
  docker_image_name_tag: 'overseer/dotnet:2.2'
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
publisher.publish_message msg_for_dev_server

publisher.disconnect_publisher
