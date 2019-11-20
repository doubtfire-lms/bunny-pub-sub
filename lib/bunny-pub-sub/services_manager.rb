require_relative 'publisher.rb'
require_relative 'subscriber.rb'
require 'singleton'

class ServicesManager
  include Singleton
  attr_reader :clients

  def initialize
    @clients = {}
  end

  def register_client(name,
                      publisher_config = nil,
                      subscriber_config = nil,
                      action = nil,
                      results_publisher = nil)

    return puts "NAME must be a defined symbol and can't be empty" if name.nil?
    return must_be_symbol name unless name.is_a? Symbol
    unless @clients[name].nil?
      return puts "Service with the name: #{name} already registered"
    end

    @clients[name] = RabbitServiceClient.new name
    return @clients[name] if publisher_config.nil?

    @clients[name].create_publisher publisher_config
    return @clients[name] if subscriber_config.nil? || action.nil?

    @clients[name].create_and_start_subscriber(
      subscriber_config, action, results_publisher
    )

    @clients[name]
  end

  def create_client_publisher(name, config)
    return not_found name if @clients[name].nil?
    return must_be_symbol name unless name.is_a? Symbol

    @clients[name].create_publisher config
  end

  def remove_client_publisher(name)
    return not_found name if @clients[name].nil?
    return must_be_symbol name unless name.is_a? Symbol

    @clients[name].remove_publisher
  end

  def create_and_start_client_subscriber(
    name, subscriber_config, action, results_publisher
  )
    return not_found name if @clients[name].nil?
    return must_be_symbol name unless name.is_a? Symbol

    @clients[name].create_and_start_subscriber(
      subscriber_config, action, results_publisher
    )
  end

  def cancel_and_remove_client_subscriber(name)
    return not_found name if @clients[name].nil?
    return must_be_symbol name unless name.is_a? Symbol

    @clients[name].cancel_and_remove_subscriber
  end

  def deregister_client(name)
    return not_found name if @clients[name].nil?
    return must_be_symbol name unless name.is_a? Symbol

    @clients[name].remove_all
    @clients[name] = nil
    @clients.delete name
  end

  private
  def not_found(name)
    puts "Service with the name: #{name} not found"
  end

  def must_be_symbol(name)
    puts "NAME: #{name} must be a symbol"
  end

  class RabbitServiceClient
    attr_reader :subscriber
    attr_reader :publisher
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def create_publisher(publisher_config)
      @publisher = Publisher.new publisher_config
    end

    def remove_publisher
      return if @publisher.nil?

      @publisher = nil
    end

    def create_and_start_subscriber(subscriber_config,
                                    action,
                                    results_publisher)

      @subscriber = Subscriber.new subscriber_config, results_publisher
      @subscriber.start_subscriber(action)
    end

    def cancel_and_remove_subscriber
      return if @subscriber.nil?

      @subscriber.cancel_subscriber
      @subscriber = nil
    end

    def remove_all
      remove_publisher
      cancel_and_remove_subscriber
    end
  end
end
