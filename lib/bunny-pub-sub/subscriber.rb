# frozen_string_literal: true

require 'bunny'
require 'json'
require_relative 'helper/config_checks'
require_relative 'publisher'

class ErrorReporter < RuntimeError
  attr_reader :status

  def self.publisher=(publisher)
    @@publisher = publisher
  end

  def self.publisher
    @@publisher
  end

  def initialize(message, status = 400)
    unless @@publisher.nil?
      @@publisher.connect_publisher
      @@publisher.publish_message message
      @@publisher.disconnect_publisher
    end
    @status = status
    super(message)
  end
end

class Subscriber
  attr_reader :cancel_ok
  class ClientException < ErrorReporter
    def initialize(message, status = 400)
      puts "Client error: #{message}, #{status}"
      super(message, status)
    end
  end

  class ServerException < ErrorReporter
    def initialize(message, status = 500)
      puts "Server error: #{message}, #{status}"
      super(message, status)
    end
  end

  def client_error!(message, status, _headers = {}, _backtrace = [])
    raise ClientException.new message, status
  end

  def server_error!(message, status, _headers = {}, _backtrace = [])
    raise ServerException.new message, status
  end

  def initialize(subscriber_config, results_publisher)
    return unless valid_config? subscriber_config
    return unless at_least_one_binding_key_exists? subscriber_config

    subscriber_config[:BINDING_KEYS] = binding_keys_to_array subscriber_config
    return if subscriber_config[:BINDING_KEYS].nil?

    ServerException.publisher = results_publisher
    ClientException.publisher = results_publisher

    @subscriber_config = subscriber_config
    @results_publisher = results_publisher
  end

  def start_subscriber(callback)
    @connection = Bunny.new(
      hostname: @subscriber_config[:RABBITMQ_HOSTNAME],
      username: @subscriber_config[:RABBITMQ_USERNAME],
      password: @subscriber_config[:RABBITMQ_PASSWORD]
    )
    ServicesManager.start_connection(@connection, 6)

    @channel = @connection.create_channel
    # With the created communication @channel, create/join an existing exchange
    # of the TYPE 'topic' and named as 'assessment'
    # Durable exchanges survive broker restart while transient exchanges do not.
    topic_exchange = @channel.topic(@subscriber_config[:EXCHANGE_NAME], durable: true)

    # Use this for making rabbitMQ not give a worker more than 1 jobs
    # if it is already working on one.
    # @channel.prefetch(1)

    queue = @channel.queue(@subscriber_config[:DURABLE_QUEUE_NAME], durable: true)

    @subscriber_config[:BINDING_KEYS].each do |language_environment|
      queue.bind(topic_exchange, routing_key: language_environment)
    end

    begin
      puts ' [*] Waiting for messages. To exit press CTRL+C'

      @consumer = queue.subscribe(manual_ack: true, block: true) do |delivery_info, properties, params|
        callback.call(self, @channel, @results_publisher, delivery_info, properties, params)
      end
    rescue Interrupt => _e
      @channel.close
      @connection.close

      exit(0)
    end
  end

  # TODO: Fix this. Probably doesn't work because
  # @consumer has no value assigned to it.
  def cancel_subscriber
    @cancel_ok = @consumer.cancel
    puts 'Consumer cancelled:'
    puts @cancel_ok.inspect
  rescue RuntimeError => e
    puts e
  ensure
    @channel.close
    @connection.close
  end

  # We can't privatize the exception classes because they are being
  # used in rescue blocks.
  # private_constant :ServerException
  # private_constant :ClientException
end

def register_subscriber(subscriber_config,
                        action,
                        results_publisher)

  subscriber_instance = Subscriber.new subscriber_config, results_publisher
  subscriber_instance.start_subscriber(action)
  subscriber_instance
rescue RuntimeError => e
  puts e
end
