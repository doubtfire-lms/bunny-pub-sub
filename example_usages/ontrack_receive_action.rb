def receive(channel, results_publisher, delivery_info, _properties, params)
  # Do something meaningful here :)
  puts params
  channel.ack(delivery_info.delivery_tag)
end
