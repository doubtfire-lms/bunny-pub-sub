# frozen_string_literal: true

class ConfigError < StandardError; end

def valid_config?(config)
  raise ConfigError, 'CONFIG must not be nil' if config.nil?

  flag = true, error_msgs = []
  if config[:RABBITMQ_HOSTNAME].nil? ||
     config[:RABBITMQ_HOSTNAME]&.strip&.empty?
    error_msgs << 'Must define config variable RABBITMQ_HOSTNAME'
    flag = false
  end
  if config[:RABBITMQ_USERNAME].nil? ||
     config[:RABBITMQ_USERNAME]&.strip&.empty?
    error_msgs << 'Must define config variable RABBITMQ_USERNAME'
    flag = false
  end
  if config[:RABBITMQ_PASSWORD].nil? ||
     config[:RABBITMQ_PASSWORD]&.strip&.empty?
    error_msgs << 'Must define config variable RABBITMQ_PASSWORD'
    flag = false
  end
  if config[:EXCHANGE_NAME].nil? ||
     config[:EXCHANGE_NAME]&.strip&.empty?
    error_msgs << 'Must define config variable EXCHANGE_NAME'
    flag = false
  end
  if config[:DURABLE_QUEUE_NAME].nil? ||
     config[:DURABLE_QUEUE_NAME]&.strip&.empty?
    error_msgs << 'Must define config variable DURABLE_QUEUE_NAME'
    flag = false
  end
  raise ConfigError, error_msgs unless flag

  flag
end

# Subscriber only checks BEGIN =================================================
# ==============================================================================
def valid_binding_keys?(language_environments, type='topic')
  # TODO: Exchanges of type `topic` PROBABLY can't simply have multiple
  # words like `direct` exchanges.
  # Rather they must be a list of words, delimited by dots.
  # VERIFY and if true, ensure that all the strings in
  # language_environments adhere to this rule.
  # language_environments must be something like "#.csharp",
  # "#.splashkit.csharp", "#.python", etc.
  case type
  when 'topic'
    language_environments.each do |language_environment|
      if !language_environment.is_a?(String) ||
         language_environment.strip.empty?
        # TODO: Add regex check here.
        return false
      end
    end
  end
  true
end

def binding_keys_to_array(config)
  language_environments = []
  unless config[:DEFAULT_BINDING_KEY]&.strip&.empty?
    language_environments.push(config[:DEFAULT_BINDING_KEY])
  end

  if !config[:BINDING_KEYS].nil? && !config[:BINDING_KEYS].empty?
    # Pushing array to another array:
    # https://stackoverflow.com/questions/1801516/how-do-you-add-an-array-to-another-array-in-ruby-and-not-end-up-with-a-multi-dim
    language_environments = [language_environments | config[:BINDING_KEYS].split(',')].flatten
  end

  return nil if language_environments.empty?

  valid_binding_keys?(language_environments) ? language_environments : nil
end

def at_least_one_binding_key_exists?(config)
  if (config[:BINDING_KEYS].nil? &&
     config[:DEFAULT_BINDING_KEY].nil?) ||
     (config[:BINDING_KEYS]&.strip&.empty? &&
     config[:DEFAULT_BINDING_KEY]&.strip&.empty?)
    puts 'Either BINDING_KEYS or '\
         'DEFAULT_BINDING_KEY must be defined and must not be empty'
    false
  else
    true
  end
end

# Subscriber only checks END ===================================================
# ==============================================================================

# Publisher only checks BEGIN ==================================================
# ==============================================================================
def routing_key_exists?(config)
  if config[:ROUTING_KEY].nil? ||
     config[:ROUTING_KEY]&.strip&.empty?
    puts 'ROUTING_KEY must be defined and must not be empty'
    false
  else
    true
  end
end

# Publisher only checks END ====================================================
# ==============================================================================
