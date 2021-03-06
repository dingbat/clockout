Gem::Specification.new do |s|
    s.name                      = 'clockout'
    s.version                   = '0.6'
    s.summary                   = 'Clock your hours worked using Git'
    s.description               = 'Sort of an extension to Git to support clocking hours worked on a project.'
    s.authors                   = ['Dan Hassin']
    s.email                     = ['danhassin@mac.com']
    s.homepage                  = 'http://rubygems.org/gems/clockout'
    s.licenses                  = ['license.md']

    s.files                     = ['lib/record.rb', 'lib/clockout.rb', 'lib/printer.rb']
    s.executables               = ['clock']
    
    s.add_runtime_dependency        "rugged", [">= 0"]
    s.add_development_dependency    "rspec", [">= 0"]
end