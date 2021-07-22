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

    return unless valid_name? name, true
    unless @clients[name].nil?
      return puts "Service with the name: #{name} already registered"
    end

    @clients[name] = RabbitServiceClient.new name
    return @clients[name] if publisher_config.nil?

    # Note: results_publisher CAN be nil.
    @clients[name].create_publisher publisher_config
    return @clients[name] if subscriber_config.nil?

    if action.nil?
      @clients[name].create_subscriber_without_action(
        subscriber_config, results_publisher
      )
      return @clients[name]
    end

    @clients[name].create_and_start_subscriber(
      subscriber_config, action, results_publisher
    )

    @clients[name]
  end

  def create_client_publisher(name, config)
    return unless valid_name? name

    @clients[name].create_publisher config
  end

  def remove_client_publisher(name)
    return unless valid_name? name

    @clients[name].remove_publisher
  end

  def create_and_start_client_subscriber(
    name, subscriber_config, action, results_publisher
  )
    return unless valid_name? name

    @clients[name].create_and_start_subscriber(
      subscriber_config, action, results_publisher
    )
  end

  def cancel_and_remove_client_subscriber(name)
    return unless valid_name? name

    @clients[name].cancel_and_remove_subscriber
  end

  def deregister_client(name)
    return unless valid_name? name

    @clients[name].remove_all
    @clients[name] = nil
    @clients.delete name
  end

  def start_connection(connection, repeat)
    (1 + repeat).times do 
      begin
        connection.start
        return
      rescue
        puts 'Unable to start connection to rabbitmq -- delaying 10 seconds'
        sleep(10) unless repeat == 0
      end
    end
    raise "Unable to connect to rabbitmq"
  end

  private
  def service_exists?(name)
    return true unless @clients[name].nil?

    puts "Service with the name: #{name} not found"
    false
  end

  def name_is_symbol?(name)
    return true if name.is_a? Symbol

    puts "NAME: #{name} must be a symbol"
    false
  end

  def valid_name?(name, new_service=false)
    if name.nil?
      puts "NAME must be a defined symbol and can't be empty"
      return false
    end
    return false if !new_service && !service_exists?(name)
    return false unless name_is_symbol? name

    true
  end

  class RabbitServiceClient
    attr_reader :subscriber
    attr_reader :publisher
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def create_publisher(publisher_config)
      publisher_created?
      @publisher = Publisher.new publisher_config
    end

    def remove_publisher
      return if @publisher.nil?

      @publisher = nil
    end

    def action=(action)
      valid_action? action
      @action = action
    end

    def create_subscriber_without_action(subscriber_config,
                                         results_publisher)

      subscriber_created?

      @subscriber_config = subscriber_config
      @results_publisher = results_publisher
      @subscriber = Subscriber.new subscriber_config, results_publisher
    end

    def create_and_start_subscriber(subscriber_config,
                                    action,
                                    results_publisher)

      subscriber_created?

      @subscriber_config = subscriber_config
      @results_publisher = results_publisher

      valid_action? action
      @action = action

      @subscriber = Subscriber.new subscriber_config, results_publisher
      start_subscriber
    end

    def start_subscriber
      @subscriber.start_subscriber(@action)
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

    private
    def subscriber_created?
      return if @subscriber.nil?

      raise 'A subscriber for this service client'\
        ' has already been created and can\'t be'\
        ' created again. Please create a new RabbitServiceClient.'
    end

    def publisher_created?
      return if @publisher.nil?

      raise 'A publisher for this service client'\
        ' has already been created and can\'t be'\
        ' created again. Please create a new RabbitServiceClient.'
    end

    def valid_action?(action)
      unless @action.nil?
        raise 'An action has already been set'\
        ' for this subscriber. A service\'s'\
        ' action can only be set once.'
      end

      return unless action.nil?

      raise 'Subscriber action can\'t be set to nil.'\
      ' Halting the program.'

      # TODO: Check if action is of the right type.
    end
  end
end
