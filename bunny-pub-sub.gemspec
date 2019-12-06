# frozen_string_literal: true

Gem::Specification.new do |s|
    s.name                  = 'bunny-pub-sub'
    s.version               = '0.0.9'
    s.date                  = '2019-11-18'
    s.summary               = 'bunny-pub-sub'
    s.description           = 'Bunny publisher/subscriber client gem'\
                              'for OnTrack and Overseer.'
    s.authors               = ['Akash Agarwal']
    s.email                 = 'agarwal.akash333@gmail.com'
    s.license               = 'MIT'
    s.required_ruby_version = '>= 2.3.1'
    s.files                 = ['lib/bunny-pub-sub/publisher.rb',
                               'lib/bunny-pub-sub/subscriber.rb',
                               'lib/bunny-pub-sub/services_manager.rb',
                               'lib/bunny-pub-sub/helper/config_checks.rb']
    s.add_runtime_dependency 'bunny', '~> 2.14'
end
