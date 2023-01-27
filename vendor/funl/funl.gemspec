require_relative './lib/funl/version'

Gem::Specification.new do |s|
  s.name = "funl"
  s.version = Funl::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0")
  s.authors = ["Joel VanderWerf"]
  s.date = Time.now.strftime "%Y-%m-%d"
  s.description = "Sequences messages."
  s.email = "vjoel@users.sourceforge.net"
  s.extra_rdoc_files = ["README.md", "COPYING"]
  s.files = Dir[
    "README.md", "COPYING", "Rakefile",
    "lib/**/*.rb",
    "bench/**/*.rb",
    "examples/**/*.rb",
    "test/**/*.rb"
  ]
  s.test_files = Dir["test/*.rb"]
  s.homepage = "https://github.com/vjoel/funl"
  s.license = "BSD"
  s.rdoc_options = [
    "--quiet", "--line-numbers", "--inline-source",
    "--title", "funl", "--main", "README.md"]
  s.require_paths = ["lib"]
  s.summary = "Sequences messages"

  s.required_ruby_version = Gem::Requirement.new(">= 2.0")
  s.add_dependency 'object-stream', '~> 0'
  s.add_dependency 'nio4r', '~> 1.0'
  
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
end