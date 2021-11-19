# frozen_string_literal: true

Gem::Specification.new do |s|
    s.name                  = 'bunny-pub-sub'
    s.version               = '0.5.1'
    s.homepage              = 'https://github.com/doubtfire-lms/bunny-pub-sub'
    s.date                  = '2021-11-19'
    s.summary               = 'bunny-pub-sub'
    s.description           = 'Bunny publisher/subscriber client gem'\
                              'for OnTrack and Overseer.'
    s.authors               = ['Akash Agarwal', 'Andrew Cain']
    s.email                 = ['agarwal.akash333@gmail.com', 'macite@gmail.com']
    s.license               = 'MIT'
    s.required_ruby_version = '>= 2.3.1'
    s.files                 = ['lib/bunny-pub-sub/publisher.rb',
                               'lib/bunny-pub-sub/subscriber.rb',
                               'lib/bunny-pub-sub/services_manager.rb',
                               'lib/bunny-pub-sub/helper/config_checks.rb']
    s.add_runtime_dependency 'bunny', '~> 2.14'
end
