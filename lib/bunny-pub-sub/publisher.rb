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
    @connection.start
  end

  def create_channel
    @channel = @connection.create_channel
  end

  def set_topic_exchange
    @exchange = @channel.topic(@config[:EXCHANGE_NAME], durable: true)
  end

  def connect_publisher
    start_connection
    create_channel
    set_topic_exchange
  end

  def publish_message(msg)
    @exchange.publish(msg.to_json, routing_key: @config[:ROUTING_KEY], persistent: true)
    puts ' [x] Message sent!'
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
