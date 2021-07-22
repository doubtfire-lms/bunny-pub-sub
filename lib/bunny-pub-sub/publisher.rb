# frozen_string_literal: true

require_relative 'helper/config_checks'
require 'bunny'
require 'json'

class Publisher
  attr_reader :connection
  attr_reader :exchange
  attr_reader :channel
  attr_reader :config

  def initialize(config)
    return unless valid_config? config
    return unless routing_key_exists? config

    @config = config

    @connection = Bunny.new(
      hostname: @config[:RABBITMQ_HOSTNAME],
      username: @config[:RABBITMQ_USERNAME],
      password: @config[:RABBITMQ_PASSWORD]
    )
  end

  def start_connection
    ServicesManager.instance.start_connection(@connection, 0)
  end

  def create_channel
    @channel = @connection.create_channel
    @channel.confirm_select if @publisher_confirms
  end

  def set_topic_exchange
    @exchange = @channel.topic(@config[:EXCHANGE_NAME], durable: true)
  end

  def connect_publisher(publisher_confirms = true)
    start_connection
    @publisher_confirms = publisher_confirms
    create_channel
    set_topic_exchange
  end

  def default_routing_key=(routing_key)
    if routing_key.nil? || routing_key&.strip&.empty?
      puts 'routing_key must be defined and must not be empty'
      return
    end

    @config[:ROUTING_KEY] = routing_key
  end

  def unset_default_routing_key
    @config[:ROUTING_KEY] = nil
  end

  def publish_message(msg, routing_key=nil)
    if (routing_key.nil? || routing_key&.strip&.empty?) &&
       (@config[:ROUTING_KEY].nil? || @config[:ROUTING_KEY]&.strip&.empty?)
      return 'No default routing key exists in config. You must specify one.'
    end

    @exchange.publish(msg.to_json, routing_key: routing_key || @config[:ROUTING_KEY], persistent: true)
    return puts ' [x] Message sent!' unless @publisher_confirms

    success = @channel.wait_for_confirms
    return puts ' [x] Message sent!' if success

    @channel.nacked_set.each do |n|
      # Do something with the nacked message ID
      # TODO: Add a yielding block to this
      puts " [x] Message #{n} failed."
    end
  end

  def close_channel
    @channel.close
  end

  def close_connection
    @connection.close
  end

  def disconnect_publisher
    close_channel
    close_connection
  end
end
