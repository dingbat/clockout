Gem::Specification.new do |s|
	s.name						= 'clockout'
	s.version					= '0.2'
	s.summary					= 'Clock your hours worked using Git'
	s.description				= 'An sort of extension to Git to support clocking hours worked on a project.'
	s.authors					= ['Dan Hassin']
	s.email						= ['danhassin@mac.com']
	s.homepage					= 'http://rubygems.org/gems/clockout'
			
	s.files						= ['lib/clockout.rb']
	s.executables				= ['clock']
	s.add_runtime_dependency	"grit", [">= 0"]
end